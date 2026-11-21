import assert from "node:assert/strict";
import { test } from "node:test";
import { CONFIGURE, configureForPeer } from "../src/sessions/chat-configure.ts";
import { hubConfig } from "../src/sessions/config.ts";
import { archiveBy, newSession } from "../src/sessions/lifecycle.ts";
import { settled } from "../src/sessions/opened.ts";
import { LIST, listForPeer } from "../src/sessions/others.ts";
import { MANUAL } from "../src/store/rows.ts";
import { Rig, settle } from "./hub-fakes.ts";

const withModels = (r: Rig) => {
  r.raw.profiles = [
    { id: "cc", runtime: "claude", home: "homes/cc", models: ["claude-opus-4-6", "claude-sonnet-4-6"] },
    { id: "cx", runtime: "codex", home: "homes/cx", models: ["gpt-5.4"] },
  ];
  r.config = hubConfig(r.raw, r.dir);
  return r;
};

const web = (over: { runtime?: "claude" | "codex"; model?: string; effort?: string; createdBy?: string; ws?: string; title?: string } = {}) => ({
  runtime: over.runtime ?? ("claude" as const),
  model: over.model ?? "claude-opus-4-6",
  effort: over.effort ?? "medium",
  createdBy: over.createdBy ?? "ada@example.com",
  ws: over.ws,
  title: over.title,
});

test("chat_configure inspects and updates a session's model, effort and runtime locally", async () => {
  const r = withModels(new Rig({ link: true }));
  try {
    const [caller] = await newSession(r.hub, web({ model: "claude-opus-4-6", effort: "high" }));
    const [other, thread] = await newSession(r.hub, web({ model: "claude-sonnet-4-6", effort: "low" }));
    await settle();

    // Inspect own session when chat is omitted or "self".
    const own = JSON.parse(await r.call(caller, "chat_configure", {}));
    assert.equal(own.session, caller);
    assert.equal(own.runtime, "claude");
    assert.equal(own.model, "claude-opus-4-6");
    assert.equal(own.effort, "high");
    assert.equal(own.created_by, "ada@example.com");
    assert.deepEqual(JSON.parse(await r.call(caller, "chat_configure", { chat: "self" })), own);

    // Update another chat by link.
    const link = r.hub.link(other)!;
    const changed = JSON.parse(await r.call(caller, "chat_configure", { chat: link, model: "claude-opus-4-6", effort: "high" }));
    assert.equal(changed.updated, true);
    assert.equal(changed.before.model, "claude-sonnet-4-6");
    assert.equal(changed.after.model, "claude-opus-4-6");
    assert.equal(changed.after.effort, "high");
    assert.equal(r.store.getSession(other)!.model, "claude-opus-4-6");
    assert.equal(r.store.getSession(other)!.effort, "high");

    // Update by thread address, switching runtime explicitly.
    const switched = JSON.parse(await r.call(caller, "chat_configure", { chat: `CHAT/${thread.threadTs}`, runtime: "codex", model: "gpt-5.4", effort: "high" }));
    assert.equal(switched.after.runtime, "codex");
    assert.equal(switched.after.model, "gpt-5.4");
    assert.equal(r.store.getSession(other)!.runtime, "codex");

    // A page showing another session's history configures the page's chat, not the history session.
    const [history] = await newSession(r.hub, web({ model: "claude-sonnet-4-6" }));
    const histLink = `${link}?history=${encodeURIComponent(history)}&entry=1`;
    await r.call(caller, "chat_configure", { chat: histLink, runtime: "claude", model: "claude-opus-4-6" });
    assert.equal(r.store.getSession(other)!.runtime, "claude");
    assert.equal(r.store.getSession(history)!.model, "claude-sonnet-4-6");
  } finally {
    await r.close();
  }
});

test("chat_configure infers runtime from model when unique across workspace profiles", async () => {
  const r = new Rig({ link: true });
  try {
    r.raw.profiles = [
      { id: "cc", runtime: "claude", home: "homes/cc", models: ["claude-opus-4-6", "claude-sonnet-4-6"] },
      { id: "cx", runtime: "codex", home: "homes/cx", models: ["gpt-5.4"] },
    ];
    r.config = hubConfig(r.raw, r.dir);
    const [caller] = await newSession(r.hub, web({ runtime: "claude", model: "claude-opus-4-6" }));
    const [other] = await newSession(r.hub, web({ runtime: "claude", model: "claude-sonnet-4-6" }));
    await settle();

    const moved = JSON.parse(await r.call(caller, "chat_configure", { chat: other, model: "gpt-5.4" }));
    assert.equal(moved.after.runtime, "codex");
    assert.equal(moved.after.model, "gpt-5.4");
    assert.equal(r.store.getSession(other)!.runtime, "codex");
  } finally {
    await r.close();
  }
});

test("chat_configure applies a preset's model config and refuses conflicting overrides", async () => {
  const r = withModels(new Rig({ link: true }));
  try {
    await r.hub.presets.add(null, { name: "Fast Codex", dirs: [], instructions: "", model: { runtime: "codex", model: "gpt-5.4", effort: "high" } }, "local");
    await r.hub.presets.add(null, { name: "No Model", dirs: [], instructions: "" }, "local");
    const [caller] = await newSession(r.hub, web({ model: "claude-opus-4-6" }));
    const [other] = await newSession(r.hub, web({ model: "claude-sonnet-4-6" }));
    await settle();

    assert.match(await r.refused(caller, "chat_configure", { chat: other, preset: "Fast Codex", model: "claude-opus-4-6" }), /cannot be combined/);
    assert.match(await r.refused(caller, "chat_configure", { chat: other, preset: "No Model" }), /does not configure a model/);
    const applied = JSON.parse(await r.call(caller, "chat_configure", { chat: other, preset: "Fast Codex" }));
    assert.equal(applied.after.runtime, "codex");
    assert.equal(applied.after.model, "gpt-5.4");
    assert.equal(applied.after.effort, "high");
  } finally {
    await r.close();
  }
});

test("chat_configure inspects and updates a chat on another station and refuses cross-workspace shares", async () => {
  const near = withModels(new Rig({ link: true, place: { workspace: "w", station: "near" }, workspaces: ["w", "other"] }));
  const far = withModels(new Rig({ link: true, place: { workspace: "w", station: "far" }, workspaces: ["w"] }));
  try {
    const [caller] = await newSession(near.hub, web({ ws: "w" }));
    const [remote] = await newSession(far.hub, web({ ws: "w", model: "claude-sonnet-4-6" }));
    const link = far.hub.link(remote)!;
    near.hub.onPeer(async (station, request) => {
      assert.equal(station, "far");
      assert.equal(request.method, CONFIGURE);
      return configureForPeer(far.hub, request, "w");
    });

    const seen = JSON.parse(await near.call(caller, "chat_configure", { chat: link }));
    assert.equal(seen.session, remote);
    assert.equal(seen.model, "claude-sonnet-4-6");

    const updated = JSON.parse(await near.call(caller, "chat_configure", { chat: link, model: "claude-opus-4-6", effort: "high" }));
    assert.equal(updated.updated, true);
    assert.equal(far.store.getSession(remote)!.model, "claude-opus-4-6");

    // Cross-workspace writable shared chat cannot be configured locally or via peer.
    const [foreign] = await newSession(near.hub, web({ ws: "other", model: "claude-sonnet-4-6" }));
    near.store.setChatShare(foreign, [{ workspace: "w", name: "W" }], true, "ada@example.com");
    const foreignLink = near.hub.link(foreign)!;
    assert.match(await near.refused(caller, "chat_configure", { chat: foreignLink, model: "claude-opus-4-6" }), /another workspace/);
    await assert.rejects(configureForPeer(near.hub, { chat: foreignLink, change: { model: "claude-opus-4-6" } }, "w"), /another workspace/);
    assert.equal(near.store.getSession(foreign)!.model, "claude-sonnet-4-6");
  } finally {
    await near.close();
    await far.close();
  }
});

test("chat_list shows model and creator, filters by model/created_by/archived, and queries other stations", async () => {
  const near = withModels(new Rig({ link: true, place: { workspace: "w", station: "near" }, workspaces: ["w"] }));
  const far = withModels(new Rig({ link: true, place: { workspace: "w", station: "far" }, workspaces: ["w"] }));
  try {
    const [caller] = await newSession(near.hub, web({ ws: "w", model: "claude-opus-4-6", createdBy: "ada@example.com", title: "Caller" }));
    const [c1] = await newSession(near.hub, web({ ws: "w", model: "claude-sonnet-4-6", createdBy: "ada@example.com", title: "Ada Active" }));
    const [c2] = await newSession(near.hub, web({ ws: "w", model: "claude-sonnet-4-6", createdBy: "ada@example.com", title: "Ada Archived" }));
    const [c3] = await newSession(near.hub, web({ ws: "w", model: "claude-sonnet-4-6", createdBy: "bob@example.com", title: "Bob Active" }));
    archiveBy(near.hub, c2, true, MANUAL);
    const [farChat] = await newSession(far.hub, web({ ws: "w", model: "claude-sonnet-4-6", createdBy: "ada@example.com", title: "Far Active" }));
    await settle();

    // Local filter: model + created_by: "me" + archived: false.
    const mine = await near.call(caller, "chat_list", { model: "sonnet", created_by: "me", archived: false });
    assert.ok(mine.includes("Ada Active"), mine);
    assert.ok(mine.includes("model: claude/claude-sonnet-4-6"), mine);
    assert.ok(mine.includes("by: ada@example.com"), mine);
    assert.ok(!mine.includes("Ada Archived"), mine);
    assert.ok(!mine.includes("Bob Active"), mine);
    assert.ok(!mine.includes("Caller"), mine);
    assert.ok(mine.includes(near.hub.link(c1)!), mine);

    // Archived only.
    const arch = await near.call(caller, "chat_list", { model: "sonnet", created_by: "me", archived: true });
    assert.ok(arch.includes("Ada Archived"), arch);
    assert.ok(!arch.includes("Ada Active"), arch);

    // Cross-station: station: "all" and station: "far".
    near.hub.onPeer(async (station, request) => {
      if (request.method === "peers") return { stations: [{ id: "near", name: "Near" }, { id: "far", name: "Far" }] };
      assert.equal(station, "far");
      assert.equal(request.method, LIST);
      assert.equal(request.args.created_by, "ada@example.com");
      return listForPeer(far.hub, request, "w");
    });

    const all = await near.call(caller, "chat_list", { model: "sonnet", created_by: "me", archived: false, station: "all" });
    assert.ok(all.includes("## Near (this station)"), all);
    assert.ok(all.includes("Ada Active"), all);
    assert.ok(all.includes("## Far"), all);
    assert.ok(all.includes("Far Active"), all);
    assert.ok(all.includes(far.hub.link(farChat)!), all);

    const onlyFar = await near.call(caller, "chat_list", { model: "sonnet", created_by: "me", archived: false, station: "Far" });
    assert.ok(onlyFar.includes("Far Active"), onlyFar);
    assert.ok(!onlyFar.includes("Ada Active"), onlyFar);
    assert.ok(!onlyFar.includes(c3), onlyFar);
  } finally {
    await near.close();
    await far.close();
  }
});

test("chat_configure reports led/leader, adopts user chats, transfers ownership, releases to person, and syncs settled()", async () => {
  const r = withModels(new Rig({ link: true }));
  try {
    const [leadA] = await newSession(r.hub, web({ title: "Lead A" }));
    const [leadB] = await newSession(r.hub, web({ title: "Lead B" }));
    const [child, childThread] = await newSession(r.hub, web({ title: "Worker" }));
    await settle();

    // Initially not led.
    const initial = JSON.parse(await r.call(leadA, "chat_configure", { chat: child }));
    assert.equal(initial.led, false);
    assert.equal(initial.leader, null);

    // Track store change events to verify real-time chatMark + session pushes.
    const events: any[] = [];
    const unsub = r.store.subscribe((c) => events.push(c));

    // Adopt a user-created chat (no prior opened_chats row).
    const adopted = JSON.parse(await r.call(leadA, "chat_configure", { chat: child, for: "me" }));
    assert.equal(adopted.updated, true);
    assert.equal(adopted.before.led, false);
    assert.equal(adopted.before.leader, null);
    assert.equal(adopted.after.led, true);
    assert.equal(adopted.after.leader, leadA);

    const op1 = r.store.openerOf(child);
    assert.ok(op1);
    assert.equal(op1.parent, leadA);
    assert.equal(op1.led, true);
    assert.equal(op1.key, `adopt:${child}`);
    assert.ok(events.some((e) => e.type === "chatMark" && e.session === child));
    assert.ok(events.some((e) => e.type === "session" && e.key === child));
    assert.ok(events.some((e) => e.type === "chatMark" && e.session === leadA));
    assert.ok(events.some((e) => e.type === "session" && e.key === leadA));

    // Station notice posted in target chat.
    const msgsAfterAdopt = r.store.messagesBefore(childThread.id, null, 20);
    assert.ok(msgsAfterAdopt.some((m) => m.authorKind === "station" && m.text.includes("Lead A")));

    // Idempotent adopt by the same leader: no-op, no extra notice.
    const countBeforeRepeat = msgsAfterAdopt.length;
    const repeatAdopt = JSON.parse(await r.call(leadA, "chat_configure", { chat: child, for: "me" }));
    assert.equal(repeatAdopt.updated, false);
    assert.equal(r.store.messagesBefore(childThread.id, null, 20).length, countBeforeRepeat);

    // settled() notifies the new leader.
    const notified: [string, string][] = [];
    const origNotify = r.hub.notify.bind(r.hub);
    r.hub.notify = (k: string, msg: string) => { notified.push([k, msg]); origNotify(k, msg); };
    settled(r.hub, child, "all_done", "finished work");
    assert.equal(notified.length, 1);
    assert.equal(notified[0]![0], leadA);
    assert.ok(notified[0]![1].includes("finished work"));

    // Transfer leadership from leadA to leadB (preserves original key, notifies leadA, leadB, child).
    events.length = 0;
    const taken = JSON.parse(await r.call(leadB, "chat_configure", { chat: child, for: "me" }));
    assert.equal(taken.updated, true);
    assert.equal(taken.before.leader, leadA);
    assert.equal(taken.after.led, true);
    assert.equal(taken.after.leader, leadB);
    assert.equal(r.store.openerOf(child)!.key, `adopt:${child}`);
    assert.ok(events.some((e) => e.type === "chatMark" && e.session === leadA));
    assert.ok(events.some((e) => e.type === "chatMark" && e.session === leadB));
    assert.ok(events.some((e) => e.type === "chatMark" && e.session === child));

    notified.length = 0;
    settled(r.hub, child, "all_done", "for B");
    assert.equal(notified.length, 1);
    assert.equal(notified[0]![0], leadB);

    // Release back to person: led -> false, notice posted, settled() stops notifying leader.
    events.length = 0;
    const released = JSON.parse(await r.call(leadB, "chat_configure", { chat: child, for: "person" }));
    assert.equal(released.updated, true);
    assert.equal(released.before.led, true);
    assert.equal(released.after.led, false);
    assert.equal(released.after.leader, null);
    assert.equal(r.store.openerOf(child)!.led, false);
    assert.ok(events.some((e) => e.type === "chatMark" && e.session === child));
    assert.ok(events.some((e) => e.type === "chatMark" && e.session === leadB));

    const msgsAfterRelease = r.store.messagesBefore(childThread.id, null, 20);
    assert.ok(msgsAfterRelease.some((m) => m.authorKind === "station" && m.text.includes("Lead B") && (m.text.includes("Handed over") || m.text.includes("放权"))));

    // Idempotent repeat release: no-op, no extra notice.
    const repeatRelease = JSON.parse(await r.call(leadB, "chat_configure", { chat: child, for: "person" }));
    assert.equal(repeatRelease.updated, false);
    assert.equal(r.store.messagesBefore(childThread.id, null, 20).length, msgsAfterRelease.length);

    // settled() no longer notifies old leader after release.
    notified.length = 0;
    settled(r.hub, child, "all_done", "after release");
    assert.equal(notified.length, 0);

    // Re-adopt a previously released chat (combined with model change).
    const readopted = JSON.parse(await r.call(leadA, "chat_configure", { chat: child, for: "me", model: "claude-sonnet-4-6" }));
    assert.equal(readopted.updated, true);
    assert.equal(readopted.after.led, true);
    assert.equal(readopted.after.leader, leadA);
    assert.equal(readopted.after.model, "claude-sonnet-4-6");
    assert.equal(r.store.openerOf(child)!.key, `adopt:${child}`);

    unsub();
  } finally {
    await r.close();
  }
});

test("chat_configure enforces lead protections: self, cycles, non-stillfail threads, invalid for", async () => {
  const r = withModels(new Rig({ link: true }));
  try {
    const [a] = await newSession(r.hub, web({ title: "A" }));
    const [b] = await newSession(r.hub, web({ title: "B" }));
    const [c] = await newSession(r.hub, web({ title: "C" }));
    await settle();

    // Invalid for value.
    assert.match(await r.refused(a, "chat_configure", { chat: b, for: "other" }), /for must be "me" or "person"/);

    // Cannot lead own chat.
    assert.match(await r.refused(a, "chat_configure", { for: "me" }), /cannot lead your own chat/);
    assert.match(await r.refused(a, "chat_configure", { chat: a, for: "me" }), /cannot lead your own chat/);

    // Cycle detection: A -> B -> C, so B cannot lead A and C cannot lead A.
    await r.call(a, "chat_configure", { chat: b, for: "me" });
    await r.call(b, "chat_configure", { chat: c, for: "me" });
    assert.match(await r.refused(b, "chat_configure", { chat: a, for: "me" }), /already leads this one/);
    assert.match(await r.refused(c, "chat_configure", { chat: a, for: "me" }), /already leads this one/);

    // Non-still.fail (Slack) thread refused.
    const slackThread = r.store.openThreadOf("slack:T1", "C1", "9.1", null, null, null);
    const slackKey = "slack:C1:9.1";
    r.store.insertSession({ key: slackKey, connect: "slack:T1", runtime: "claude", profile: "cc", model: "claude-opus-4-6", workspace: r.dir, cwd: r.dir, token: "t-slack", createdAt: 1, lastActiveAt: 1, createdBy: "ada@example.com" });
    r.store.joinThread(slackThread.id, slackKey, "slack:T1");
    assert.match(await r.refused(a, "chat_configure", { chat: "C1/9.1", for: "me" }), /only still\.fail chats/);
    assert.match(await r.refused(a, "chat_configure", { chat: slackKey, for: "me" }), /only still\.fail chats/);
  } finally {
    await r.close();
  }
});

test("chat_configure adopts and releases chats across stations, syncing mirror rows and blocking cross-station cycles", async () => {
  const near = withModels(new Rig({ link: true, place: { workspace: "w", station: "near" }, workspaces: ["w"] }));
  const far = withModels(new Rig({ link: true, place: { workspace: "w", station: "far" }, workspaces: ["w"] }));
  try {
    const [caller] = await newSession(near.hub, web({ ws: "w", title: "Near Leader" }));
    const [remote] = await newSession(far.hub, web({ ws: "w", title: "Far Worker" }));
    const farLink = far.hub.link(remote)!;
    const nearLink = near.hub.link(caller)!;

    near.hub.onPeer(async (station, request) => {
      assert.equal(station, "far");
      assert.equal(request.method, CONFIGURE);
      return configureForPeer(far.hub, request, "w", "near");
    });
    far.hub.onPeer(async (station, request) => {
      assert.equal(station, "near");
      assert.equal(request.method, CONFIGURE);
      return configureForPeer(near.hub, request, "w", "far");
    });

    // Near adopts Far chat.
    const adopted = JSON.parse(await near.call(caller, "chat_configure", { chat: farLink, for: "me" }));
    assert.equal(adopted.updated, true);
    assert.equal(adopted.after.led, true);
    assert.equal(adopted.after.leader, `near/${caller}`);

    // Both stations have synced opened_chats rows.
    const farOp = far.store.openerOf(remote);
    assert.ok(farOp);
    assert.equal(farOp.parentStation, "near");
    assert.equal(farOp.parent, caller);
    assert.equal(farOp.led, true);

    const nearMirrors = near.store.openedBy(caller);
    assert.equal(nearMirrors.length, 1);
    assert.equal(nearMirrors[0]!.childStation, "far");
    assert.equal(nearMirrors[0]!.child, remote);
    assert.equal(nearMirrors[0]!.led, true);

    // Cross-station cycle blocked: Far cannot adopt Near while Near leads Far.
    assert.match(await far.refused(remote, "chat_configure", { chat: nearLink, for: "me" }), /already leads this one/);

    // Near releases Far chat: both sides updated to led = false.
    const released = JSON.parse(await near.call(caller, "chat_configure", { chat: farLink, for: "person" }));
    assert.equal(released.updated, true);
    assert.equal(released.after.led, false);
    assert.equal(released.after.leader, null);
    assert.equal(far.store.openerOf(remote)!.led, false);
    assert.equal(near.store.openedBy(caller)[0]!.led, false);
  } finally {
    await near.close();
    await far.close();
  }
});

test("chat_configure keeps local titles dynamic (null in opened_chats), refreshes remote mirror title, guards leadMirror workspace, and rejects old peers", async () => {
  const near = withModels(new Rig({ link: true, place: { workspace: "w1", station: "near" }, workspaces: ["w1", "w2"] }));
  const far = withModels(new Rig({ link: true, place: { workspace: "w1", station: "far" }, workspaces: ["w1"] }));
  try {
    // 1. Local untitled chats: opened_chats.title and opener_title stay null (never raw session key).
    const [untitledParent] = await newSession(near.hub, web({ ws: "w1" }));
    const [untitledChild] = await newSession(near.hub, web({ ws: "w1" }));
    await near.call(untitledParent, "chat_configure", { chat: untitledChild, for: "me" });
    const localOp = near.store.openerOf(untitledChild)!;
    assert.equal(localOp.title, null);
    assert.equal(localOp.openerTitle, null);

    // 2. Cross-station untitled chat adopted, then titled later and re-adopted -> mirror title refreshes.
    const [remoteUntitled] = await newSession(far.hub, web({ ws: "w1" }));
    const remoteLink = far.hub.link(remoteUntitled)!;
    near.hub.onPeer(async (station, request) => {
      assert.equal(station, "far");
      return configureForPeer(far.hub, request, "w1", "near");
    });

    await near.call(untitledParent, "chat_configure", { chat: remoteLink, for: "me" });
    assert.equal(far.store.openerOf(remoteUntitled)!.title, null);
    assert.equal(far.store.openerOf(remoteUntitled)!.openerTitle, null);
    assert.equal(near.store.openedRecord("far", remoteUntitled)!.title, null);

    // Release, give remote chat a title, then re-adopt: near mirror's title must refresh.
    await near.call(untitledParent, "chat_configure", { chat: remoteLink, for: "person" });
    far.store.setTitle(remoteUntitled, "Renamed Remote");
    await near.call(untitledParent, "chat_configure", { chat: remoteLink, for: "me" });
    assert.equal(near.store.openedRecord("far", remoteUntitled)!.title, "Renamed Remote");

    // 3. Cross-workspace leadMirror isolation: w2 parent mirror cannot be cleared by a w1 peer, and empty peer rejected when ws != null.
    const [w2Parent] = await newSession(near.hub, web({ ws: "w2", title: "W2 Lead" }));
    near.store.adoptOpened({ childStation: "far", child: "chat:c-w2-child", parentStation: "", parent: w2Parent, title: "W2 Child", link: null, openerTitle: null });
    assert.equal(near.store.openedRecord("far", "chat:c-w2-child")!.led, true);
    await assert.rejects(
      configureForPeer(near.hub, { leadMirror: { childStation: "far", child: "chat:c-w2-child", led: false } }, "w1", "far"),
      /another workspace/,
    );
    await assert.rejects(
      configureForPeer(near.hub, { leadMirror: { childStation: "far", child: "chat:c-w2-child", led: false } }, "w2", ""),
      /caller station is required/,
    );
    assert.equal(near.store.openedRecord("far", "chat:c-w2-child")!.led, true);
    // Same workspace with authenticated peer succeeds.
    await configureForPeer(near.hub, { leadMirror: { childStation: "far", child: "chat:c-w2-child", led: false } }, "w2", "far");
    assert.equal(near.store.openedRecord("far", "chat:c-w2-child")!.led, false);

    // 4. Old peer station that ignores `lead` and returns only `{ text }` without `target` fails explicitly.
    near.hub.onPeer(async () => ({ text: JSON.stringify({ session: remoteUntitled }) }));
    assert.match(
      await near.refused(untitledParent, "chat_configure", { chat: remoteLink, for: "me" }),
      /not updated yet: ownership cannot be changed there/,
    );
    assert.match(
      await near.refused(untitledParent, "chat_configure", { chat: remoteLink, for: "person" }),
      /not updated yet: ownership cannot be changed there/,
    );
  } finally {
    await near.close();
    await far.close();
  }
});
