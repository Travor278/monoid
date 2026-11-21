// An agent reads or changes a session's runtime configuration (runtime, model, effort, speed, context, preset, repick)
// or ownership (`for`: "me" | "person"), here or on another station of its workspace. Uses the same lifecycle as the
// app's POST /sessions/:key (`configure`).
import { modelSpeed } from "../../../client/core-ts/src/model-speed.ts";
import { RUNTIME_KINDS, type RuntimeKind } from "../agents/runtime.ts";
import { Refused } from "../jobs/remote.ts";
import { tr, stationLang } from "../ops/i18n.ts";
import { log } from "../ops/log.ts";
import { STATION_AUTHOR, STILLFAIL_SURFACE, type SessionRow } from "../store/rows.ts";
import type { SessionChange } from "./accounts.ts";
import { type Args, jsString } from "./args.ts";
import { markNotice } from "./chat.ts";
import { runs } from "./config.ts";
import { contextAsked } from "./context-cap.ts";
import type { Hub } from "./hub.ts";
import { configure } from "./lifecycle.ts";
import { sender } from "./messages.ts";
import { elsewhere, fromBefore, linkedSession, named, peersOf, scopeOf, sessionThreadOf, threadIn } from "./others.ts";

type Json = any;

export const CONFIGURE = "session.configure";

const MODEL_CHANGE_KEYS = ["runtime", "model", "effort", "speed", "fast", "context", "preset", "repick"] as const;
const MAX_ANCESTOR_HOPS = 16;

type Ancestor = { station: string; session: string };
type LeadAction =
  | { mode: "person" }
  | { mode: "me"; parentStation: string; parent: string; parentTitle: string | null; parentAncestors?: Ancestor[] };

function trimmed(v: unknown): string | null {
  if (v === undefined || v === null) return null;
  const s = jsString(v).trim();
  return s === "" ? null : s;
}

function parseFor(args: Args): "me" | "person" | null {
  if (args.for === undefined) return null;
  if (args.for === "me" || args.for === "person") return args.for;
  throw new Error('for must be "me" or "person"');
}

function describeRow(hub: Hub, row: SessionRow) {
  const opener = hub.store.openerOf(row.key);
  const led = opener?.led === true;
  const leader = led ? (opener.parentStation !== "" ? `${opener.parentStation}/${opener.parent}` : opener.parent) : null;
  return {
    session: row.key,
    link: hub.link(row.key) ?? null,
    runtime: row.runtime,
    model: row.model,
    effort: row.effort,
    speed: row.speed ?? null,
    fast: row.fast,
    context: row.context,
    profile: row.profile,
    running: row.running,
    archived: row.archivedAt !== null,
    created_by: row.createdBy,
    led,
    leader,
  };
}

/// Walks up this station's `opened_chats` leadership chain from `start` (at most `MAX_ANCESTOR_HOPS`).
function localAncestors(hub: Hub, start: string): Ancestor[] {
  const out: Ancestor[] = [];
  const seen = new Set<string>([start]);
  let cur = start;
  for (let i = 0; i < MAX_ANCESTOR_HOPS; i++) {
    const op = hub.store.openerOf(cur);
    if (!op || op.led === false) break;
    out.push({ station: op.parentStation, session: op.parent });
    if (op.parentStation !== "") break;
    if (seen.has(op.parent)) break;
    seen.add(op.parent);
    cur = op.parent;
  }
  return out;
}

/// Posts a non-interrupting station notice in `targetKey`'s latest thread when ownership changes.
async function sayLeadNotice(hub: Hub, targetKey: string, i18nKey: "station.session.handedToPerson" | "station.session.adoptedByAgent", from: string): Promise<void> {
  const latest = hub.store.latestThread(targetKey);
  if (!latest) return;
  const text = tr(stationLang(), i18nKey, { from });
  try {
    const ts = await hub.chat(latest.connect).post({ channel: latest.thread.channel, threadTs: latest.thread.threadTs }, markNotice(text), []);
    hub.store.insertMessage({ thread: latest.thread.id, ts, authorKind: STATION_AUTHOR, author: STATION_AUTHOR, text, attachments: [] });
  } catch (error) {
    log.warn("hub", "a lead change was not said in the chat", { session: targetKey, error: (error as Error).message });
  }
}

function validateLeadHere(hub: Hub, targetKey: string, lead: LeadAction): void {
  if (lead.mode !== "me") return;
  if (lead.parentStation === "" && targetKey === lead.parent) {
    throw new Error("cannot lead your own chat");
  }
  let thread;
  try {
    thread = sessionThreadOf(hub, targetKey).thread;
  } catch {
    throw new Error("only still.fail chats can be led as sub-chats");
  }
  if (thread.surface !== STILLFAIL_SURFACE) {
    throw new Error("only still.fail chats can be led as sub-chats");
  }
  if (lead.parentStation === "") {
    if (localAncestors(hub, lead.parent).some((a) => a.station === "" && a.session === targetKey)) {
      throw new Error("cannot lead a chat that already leads this one");
    }
    return;
  }
  const here = hub.station() ?? "";
  for (const a of lead.parentAncestors ?? []) {
    if (here !== "" && a.station === here) {
      if (a.session === targetKey) throw new Error("cannot lead a chat that already leads this one");
      if (localAncestors(hub, a.session).some((b) => b.station === "" && b.session === targetKey)) {
        throw new Error("cannot lead a chat that already leads this one");
      }
    }
  }
}

async function clearRemoteMirror(hub: Hub, callerKey: string, remoteStation: string, childKey: string): Promise<void> {
  const call = peersOf(hub, callerKey);
  if (!call) return;
  try {
    await call(remoteStation, { method: CONFIGURE, session: callerKey, leadMirror: { childStation: hub.station() ?? "", child: childKey, led: false } });
  } catch (error) {
    log.warn("hub", "could not clear remote opened_chats mirror", { station: remoteStation, child: childKey, error: (error as Error).message });
  }
}

function resolveHere(hub: Hub, chat: string, ws: string | null, caller: string | null): string {
  if (chat === "" || chat.toLowerCase() === "self") {
    if (caller === null) throw new Error("chat is required");
    return caller;
  }
  const reference = chat.includes("/o/") || chat.includes("/chats/") ? chat.split("?")[0]! : chat;
  const what = named(hub, reference, ws);
  if (what.type === "session") {
    if (ws !== null && !hub.inWorkspace(what.key, ws)) {
      throw new Error("that chat is in another workspace: only this workspace's chats can be configured");
    }
    return what.key;
  }
  if (!threadIn(hub, what.thread, ws)) {
    throw new Error("that chat is in another workspace: only this workspace's chats can be configured");
  }
  if (what.thread.home !== null) return what.thread.home;
  const agents = hub.store.threadSessions(what.thread.id).map((m) => m.session);
  if (agents.length === 0) throw new Error(`${reference} has no agent session to configure`);
  if (agents.length > 1) throw new Error(`${reference} has several agents; pass one session key as chat: ${agents.join(", ")}`);
  return agents[0]!;
}

async function parseChange(hub: Hub, ws: string | null, args: Args): Promise<SessionChange | null> {
  if (!MODEL_CHANGE_KEYS.some((k) => args[k] !== undefined)) return null;
  const presetName = trimmed(args.preset);
  if (presetName !== null) {
    for (const k of ["runtime", "model", "effort", "speed", "fast", "context"] as const) {
      if (args[k] !== undefined) {
        throw new Error("preset cannot be combined with runtime, model, effort, speed, fast or context");
      }
    }
    const all = await hub.presets.list(ws ?? hub.workspaces()[0] ?? null);
    const lower = presetName.toLowerCase();
    const preset = all.find((p) => p.id === presetName) ?? all.find((p) => p.name.toLowerCase() === lower);
    if (!preset) {
      if (all.length === 0) throw new Error(`no preset ${presetName}: this station has none`);
      throw new Error(`no preset ${presetName} on this station; its presets: ${all.map((p) => p.name).join(", ")}`);
    }
    if (!preset.model) throw new Error(`the preset ${preset.name} does not configure a model`);
    const pm = preset.model;
    const change: SessionChange = {
      ...(pm.runtime ? { runtime: pm.runtime } : {}),
      model: pm.model,
      effort: pm.effort ?? null,
      fast: pm.fast ?? null,
      speed: pm.speed ?? null,
      context: pm.context ?? null,
      ...(pm.profiles !== undefined ? { profiles: pm.profiles } : pm.profile !== undefined ? { profile: pm.profile } : { profile: null }),
    };
    if (args.repick !== undefined) {
      if (typeof args.repick !== "boolean") throw new Error("repick must be true or false");
      if (args.repick) change.repick = true;
    }
    return change;
  }
  const change: SessionChange = {};
  if (args.runtime !== undefined) {
    const runtime = trimmed(args.runtime);
    if (runtime === null || !RUNTIME_KINDS.includes(runtime as RuntimeKind)) {
      throw new Error(`runtime must be one of ${RUNTIME_KINDS.join(", ")}`);
    }
    change.runtime = runtime;
  }
  if (args.model !== undefined) {
    change.model = args.model === null ? null : trimmed(args.model);
  }
  if (args.effort !== undefined) {
    change.effort = args.effort === null ? null : trimmed(args.effort);
  }
  if (args.speed !== undefined) {
    if (args.speed === null || trimmed(args.speed) === null) change.speed = null;
    else {
      const speed = modelSpeed(args.speed);
      if (speed === null) throw new Error("speed must be standard, fast or ultrafast");
      change.speed = speed;
    }
  }
  if (args.fast !== undefined) {
    if (args.fast !== null && typeof args.fast !== "boolean") throw new Error("fast must be true, false or null");
    change.fast = args.fast;
  }
  if (args.context !== undefined) {
    change.context = args.context === null || args.context === 0 ? null : (contextAsked(args.context, "en") ?? null);
  }
  if (args.repick !== undefined) {
    if (typeof args.repick !== "boolean") throw new Error("repick must be true or false");
    if (args.repick) change.repick = true;
  }
  return change;
}

function parsePeerChange(raw: Json): SessionChange | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== "object" || Array.isArray(raw)) throw new Error("change must be an object");
  const change: SessionChange = {};
  if ("runtime" in raw) {
    if (typeof raw.runtime !== "string" || !RUNTIME_KINDS.includes(raw.runtime as RuntimeKind)) {
      throw new Error(`runtime must be one of ${RUNTIME_KINDS.join(", ")}`);
    }
    change.runtime = raw.runtime;
  }
  if ("model" in raw) change.model = raw.model === null ? null : trimmed(raw.model);
  if ("effort" in raw) change.effort = raw.effort === null ? null : trimmed(raw.effort);
  if ("speed" in raw) {
    if (raw.speed === null || trimmed(raw.speed) === null) change.speed = null;
    else {
      const speed = modelSpeed(raw.speed);
      if (speed === null) throw new Error("speed must be standard, fast or ultrafast");
      change.speed = speed;
    }
  }
  if ("fast" in raw) {
    if (raw.fast !== null && typeof raw.fast !== "boolean") throw new Error("fast must be true, false or null");
    change.fast = raw.fast;
  }
  if ("context" in raw) {
    change.context = raw.context === null || raw.context === 0 ? null : (contextAsked(raw.context, "en") ?? null);
  }
  if ("profile" in raw) {
    if (raw.profile !== null && typeof raw.profile !== "string") throw new Error("profile must be a string or null");
    change.profile = raw.profile;
  }
  if ("profiles" in raw) {
    if (raw.profiles !== null && (!Array.isArray(raw.profiles) || raw.profiles.some((x: unknown) => typeof x !== "string"))) {
      throw new Error("profiles must be a list of profile ids or null");
    }
    change.profiles = raw.profiles;
  }
  if (raw.repick === true) change.repick = true;
  return Object.keys(change).length === 0 ? null : change;
}

function ownTitle(row: SessionRow | null): string | null {
  return trimmed(row?.title ?? null);
}

function parsePeerLead(raw: Json, peer: string): LeadAction | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== "object" || Array.isArray(raw)) throw new Error("lead must be an object");
  if (raw.mode === "person") return { mode: "person" };
  if (raw.mode === "me") {
    const parent = typeof raw.parent === "string" ? raw.parent.trim() : "";
    if (parent === "") throw new Error("lead.parent is required");
    if (peer === "") throw new Error("caller station is required for cross-station lead");
    const parentTitle = typeof raw.parentTitle === "string" && raw.parentTitle.trim() !== "" ? raw.parentTitle.trim() : null;
    const parentAncestors: Ancestor[] = Array.isArray(raw.parentAncestors)
      ? raw.parentAncestors
          .filter((a: Json) => a && typeof a.station === "string" && typeof a.session === "string")
          .slice(0, MAX_ANCESTOR_HOPS)
          .map((a: Json) => ({ station: a.station as string, session: a.session as string }))
      : [];
    return { mode: "me", parentStation: peer, parent, parentTitle, parentAncestors };
  }
  throw new Error('for must be "me" or "person"');
}

async function applyHere(
  hub: Hub,
  targetKey: string,
  change: SessionChange | null,
  lead: LeadAction | null,
  mirrorCaller: string,
  skipMirrorStation = "",
): Promise<{ text: string; target: string; title: string | null; link: string | null; leadChanged: boolean }> {
  const row = hub.store.getSession(targetKey);
  if (!row) throw new Error(`unknown session ${targetKey}`);
  if (change === null && lead === null) {
    return { text: JSON.stringify(describeRow(hub, row), null, 2), target: targetKey, title: row.title, link: hub.link(targetKey) ?? null, leadChanged: false };
  }
  if (lead !== null) validateLeadHere(hub, targetKey, lead);
  const before = describeRow(hub, row);
  if (change !== null) {
    let next = change;
    if (next.runtime === undefined && typeof next.model === "string" && next.model !== "") {
      const available = hub.profilesIn(row.ws ?? null);
      const fitsCurrent = available.some((p) => p.runtimes.includes(row.runtime as RuntimeKind) && runs(p, next.model!));
      if (!fitsCurrent) {
        const matching = [...new Set(available.filter((p) => runs(p, next.model!)).flatMap((p) => p.runtimes))];
        if (matching.length === 1) next = { ...next, runtime: matching[0]! };
        else if (matching.length > 1) throw new Error(`model ${next.model} runs on multiple runtimes (${matching.join(", ")}): pass runtime`);
      }
    }
    await configure(hub, targetKey, next, "en");
  }
  let leadChanged = false;
  const targetLink: string | null = hub.link(targetKey) ?? null;
  if (lead !== null) {
    if (lead.mode === "person") {
      const res = hub.store.setOpenedLed("", targetKey, false);
      leadChanged = res.changed;
      if (res.changed && res.prev) {
        let from = res.prev.openerTitle || res.prev.parent;
        if (res.prev.parentStation === "") {
          try {
            from = sender(hub, res.prev.parent)[0];
          } catch {}
        }
        await sayLeadNotice(hub, targetKey, "station.session.handedToPerson", from);
        if (res.prev.parentStation !== "" && res.prev.parentStation !== skipMirrorStation) {
          await clearRemoteMirror(hub, mirrorCaller, res.prev.parentStation, targetKey);
        }
      }
    } else {
      const res = hub.store.adoptOpened({
        childStation: "",
        child: targetKey,
        parentStation: lead.parentStation,
        parent: lead.parent,
        title: null,
        link: targetLink,
        openerTitle: lead.parentStation === "" ? null : lead.parentTitle,
      });
      leadChanged = res.changed;
      if (res.changed) {
        let from = lead.parentTitle || lead.parent;
        if (lead.parentStation === "") {
          try {
            from = sender(hub, lead.parent)[0];
          } catch {}
        }
        await sayLeadNotice(hub, targetKey, "station.session.adoptedByAgent", from);
        if (res.prev && res.prev.parentStation !== "" && res.prev.parentStation !== skipMirrorStation && (res.prev.parentStation !== lead.parentStation || res.prev.parent !== lead.parent)) {
          await clearRemoteMirror(hub, mirrorCaller, res.prev.parentStation, targetKey);
        }
      }
    }
  }
  const afterRow = hub.store.getSession(targetKey) ?? row;
  const after = describeRow(hub, afterRow);
  const updated = change !== null || leadChanged;
  return {
    text: JSON.stringify({ updated, before, after }, null, 2),
    target: targetKey,
    title: ownTitle(afterRow),
    link: targetLink,
    leadChanged,
  };
}

export async function chatConfigure(hub: Hub, key: string, args: Args): Promise<string> {
  const ws = scopeOf(hub, key);
  const chat = typeof args.chat === "string" ? args.chat.trim() : "";
  const forMode = parseFor(args);
  const change = await parseChange(hub, ws, args);
  const self = chat === "" || chat.toLowerCase() === "self";
  let station = self ? null : elsewhere(hub, key, chat);
  let targetChat = chat;
  if (!self && station === null) {
    const ref = linkedSession(chat)?.[0] ?? chat;
    const moved = hub.store.handedTo(ref);
    if (moved !== null) {
      station = moved.station;
      targetChat = ref;
    }
  }
  if (station === null) {
    const targetKey = resolveHere(hub, targetChat, ws, key);
    let lead: LeadAction | null = null;
    if (forMode === "person") {
      lead = { mode: "person" };
    } else if (forMode === "me") {
      lead = { mode: "me", parentStation: "", parent: key, parentTitle: null };
    }
    return (await applyHere(hub, targetKey, change, lead, key)).text;
  }
  const call = peersOf(hub, key);
  if (!call) throw new Error("other stations cannot be reached from this one yet");
  let leadPayload: Json = undefined;
  if (forMode === "person") {
    leadPayload = { mode: "person" };
  } else if (forMode === "me") {
    const fromTitle = ownTitle(hub.store.getSession(key));
    const ancestors = localAncestors(hub, key);
    const targetRef = linkedSession(targetChat)?.[0] ?? targetChat;
    if (ancestors.some((a) => a.station === station && a.session === targetRef)) {
      throw new Error("cannot lead a chat that already leads this one");
    }
    leadPayload = { mode: "me", parent: key, parentTitle: fromTitle, parentAncestors: ancestors };
  }
  let answer: Json;
  try {
    answer = await call(station, {
      method: CONFIGURE,
      session: key,
      chat: targetChat,
      ...(change !== null ? { change } : {}),
      ...(leadPayload !== undefined ? { lead: leadPayload } : {}),
    });
  } catch (error) {
    const why = (error as Error).message;
    if (error instanceof Refused && fromBefore(why)) {
      throw new Error(`station ${station} is not updated yet: its chats cannot be configured from here`);
    }
    throw new Error(`configure request to station ${station} failed: ${why}`);
  }
  if (typeof answer?.text !== "string") throw new Error(`station ${station} answered without a configure result`);
  if (forMode !== null) {
    const target = typeof answer.target === "string" ? answer.target.trim() : "";
    if (target === "") {
      throw new Error(`station ${station} is not updated yet: ownership cannot be changed there`);
    }
    if (forMode === "person") {
      hub.store.setOpenedLed(station, target, false);
    } else {
      hub.store.adoptOpened({
        childStation: station,
        child: target,
        parentStation: "",
        parent: key,
        title: trimmed(answer.title),
        link: trimmed(answer.link),
        openerTitle: null,
      });
    }
  }
  return answer.text;
}

/// A station of the workspace asks to read or configure one of its chats here; cross-workspace shares do not grant this.
export async function configureForPeer(hub: Hub, request: Json, ws: string | null = null, peer = ""): Promise<Json> {
  if (request?.leadMirror && typeof request.leadMirror === "object") {
    if (ws !== null && peer === "") {
      throw new Error("caller station is required for cross-station lead");
    }
    const child = typeof request.leadMirror.child === "string" ? request.leadMirror.child.trim() : "";
    const childStation = peer !== "" ? peer : (ws === null && typeof request.leadMirror.childStation === "string" ? request.leadMirror.childStation.trim() : "");
    if (child !== "" && childStation !== "") {
      const record = hub.store.openedRecord(childStation, child);
      if (record !== null) {
        if (ws !== null && (record.parentStation !== "" || !hub.inWorkspace(record.parent, ws))) {
          throw new Error("that chat is in another workspace: only this workspace's chats can be configured");
        }
        hub.store.setOpenedLed(childStation, child, false);
      }
    }
    return { text: JSON.stringify({ updated: true }) };
  }
  const chat = typeof request?.chat === "string" ? request.chat.trim() : "";
  if (chat === "") throw new Error("chat is required");
  const targetKey = resolveHere(hub, chat, ws, null);
  const change = parsePeerChange(request?.change);
  const lead = parsePeerLead(request?.lead, peer);
  return applyHere(hub, targetKey, change, lead, targetKey, peer);
}
