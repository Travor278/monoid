// Sessions, tools, cards, model configuration and job lifecycle parity on the real MoonBit station
// (`stillfail-reader run` with no Node on PATH + real `stillfail-runner` + fake `claude` + `STILLFAIL_LOCAL_ADMIN=1`):
// - MCP session management closed loop: chat_create (for: "me", for: "person", idempotent key), session_send to a cold
//   session, chat_list filters (query, model, created_by, archived), chat_read & chat_history pagination (before/limit),
//   chat_archive (stops running jobs, preserves ended jobs/logs, sets archived_at/manual).
// - chat_post heldPost interception & resend (`send: <held-id>`), options cards (reply + action: "close") & withdraw,
//   closing a card via Admin API without waking the agent + `<card-choice>` injection on next message, chat_state
//   (`all_done`, `need_human`, `waiting` with `watch: true`) and `goesOn` clearing `all_done` on a subsequent bare post.
// - Dynamic configuration via `chat_configure` & Admin API (`POST /admin-api/sessions/:key/settings`): model, effort
//   and speed/fast immediately reflected in the next turn's `claude` launch arguments and recorded `agent_identity`.
// - Archived session wakeup guard: messages and external triggers do not start a new turn on a manually archived chat.
import assert from "node:assert/strict";
import { type ChildProcess, spawn } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { type Server, createServer } from "node:net";
import { request } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { after, test } from "node:test";
import { mbReaderBinary } from "../src/read/mb-reader.ts";
import { Store } from "../src/store/store.ts";

const binary = mbReaderBinary();
const runner = process.env.STILLFAIL_RUNNER ?? "";
const skip = binary === null ? "the MoonBit program (stillfail-reader) is not built here"
  : process.platform === "win32" ? "the launcher's descriptors are Unix's"
  : runner === "" || !existsSync(runner) ? "no stillfail-runner (run under scripts/native.ts run runner)"
  : !existsSync("/usr/bin/curl") ? "no /usr/bin/curl for the fake runtime"
  : false;

const dirs: string[] = [];
const fresh = (what: string) => {
  const dir = mkdtempSync(join(process.platform === "darwin" ? "/tmp" : tmpdir(), `mbp-${what}-`));
  dirs.push(dir);
  return dir;
};

const children: ChildProcess[] = [];
after(async () => {
  const left = children.filter((c) => c.exitCode === null && c.signalCode === null);
  for (const c of left) c.kill("SIGKILL");
  await Promise.race([
    Promise.all(left.map((c) => (c.exitCode === null && c.signalCode === null ? new Promise<void>((r) => c.once("exit", () => r())) : undefined))),
    new Promise((r) => setTimeout(r, 5_000).unref()),
  ]);
  for (const d of dirs) {
    const runners = join(d, "run", "runners");
    if (!existsSync(runners)) continue;
    for (const info of runnerInfos(runners)) {
      try { process.kill(-(info as any).pgid, "SIGKILL"); } catch {}
      try { process.kill(info.runner, "SIGKILL"); } catch {}
    }
  }
  if (process.env.MB_PARITY_KEEP !== "1") for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function runnerInfos(dir: string): { runner: number; pgid?: number }[] {
  return readdirSync(dir).filter((f) => f.endsWith(".json")).flatMap((f) => {
    try { return [JSON.parse(readFileSync(join(dir, f), "utf8"))]; } catch { return []; }
  });
}

const TOOLS = ["sh", "ps", "mv", "cat", "curl", "sleep", "echo", "printf", "env", "ls", "rm", "mkdir", "cp", "sed", "tr", "head", "wc", "uname", "awk"];
function binOf(name: string): string {
  const search = [...(process.env.PATH ?? "").split(":").filter((d) => d !== ""), "/usr/bin", "/bin", "/usr/sbin", "/sbin", "/usr/local/bin", "/opt/homebrew/bin"];
  for (const d of search) {
    const at = join(d, name);
    if (existsSync(at)) return at;
  }
  return "";
}

function makeNoNodeBin(dir: string): void {
  for (const t of TOOLS) {
    const found = binOf(t);
    if (found !== "" && !found.includes("node") && !existsSync(join(dir, t))) {
      symlinkSync(found, join(dir, t));
    }
  }
  assert.equal(existsSync(join(dir, "node")), false, "no node on fake bin PATH");
}

/// Installs a scripted fake `claude` (pure /bin/sh + curl, no Node) in `dir`.
/// Logs every launch (argv, model, effort, settings) and every received prompt line, handles `control_request`
/// (`set_model`), and executes scenario hooks triggered by prompt markers.
function installFakeClaude(dir: string): void {
  makeNoNodeBin(dir);
  const claude = String.raw`#!/bin/sh
case " $* " in *" -p "*) ;; *) printf 'claude 2.0.0\n'; exit 0 ;; esac
sid=""; cfg=""; model=""; effort=""; settings=""
argv_file="$FAKE_OUT/argv-$$.txt"
: > "$argv_file"
for a in "$@"; do printf '%s\n' "$a" >> "$argv_file"; done
while [ $# -gt 0 ]; do
  case "$1" in
    --session-id|--resume) sid="$2"; shift ;;
    --mcp-config) cfg="$2"; shift ;;
    --model) model="$2"; shift ;;
    --effort) effort="$2"; shift ;;
    --settings) settings="$2"; shift ;;
  esac
  shift
done
url=$(printf '%s' "$cfg" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p')
settings_json="$settings"
if [ -z "$settings_json" ]; then settings_json="null"; fi
printf '{"pid":%s,"sid":"%s","model":"%s","effort":"%s","settings":%s}\n' \
  "$$" "$sid" "$model" "$effort" "$settings_json" >> "$FAKE_OUT/launches.jsonl"
say() { printf '%s\n' "$1"; }
mcp_call() {
  curl -s -X POST "$url" -H 'content-type: application/json' -H "authorization: Bearer $STILLFAIL_MCP_TOKEN" -d "$1"
}
n=0
while IFS= read -r line; do
  case "$line" in
    *'"type":"control_request"'*)
      printf '%s\n' "$line" >> "$FAKE_OUT/controls-$sid.jsonl"
      req_id=$(printf '%s' "$line" | sed -n 's/.*"request_id":"\([^"]*\)".*/\1/p')
      new_m=$(printf '%s' "$line" | sed -n 's/.*"model":"\([^"]*\)".*/\1/p')
      if [ -n "$new_m" ]; then model="$new_m"; fi
      say '{"type":"control_response","response":{"subtype":"success","request_id":"'"$req_id"'"}}'
      continue ;;
    *'"type":"user"'*) ;;
    *) continue ;;
  esac
  n=$((n+1))
  printf '%s\n' "$line" >> "$FAKE_OUT/prompts-$sid.jsonl"
  printf '%s\n' "$line" >> "$FAKE_OUT/all-prompts.jsonl"
  init_model="$model"
  if [ -z "$init_model" ]; then init_model="default"; fi
  say '{"type":"system","subtype":"init","session_id":"'"$sid"'","model":"'"$init_model"'","tools":[],"mcp_servers":[]}'
  say '{"type":"system","subtype":"status","status":"requesting","session_id":"'"$sid"'"}'
  to=$(printf '%s' "$line" | sed -n 's/.*thread=\\"\([^\\]*\)\\".*/\1/p')
  if [ -n "$to" ]; then printf '%s' "$to" > "$FAKE_OUT/to-$sid"; else to=$(cat "$FAKE_OUT/to-$sid" 2>/dev/null); fi

  case "$line" in
    *SCENARIO-HOLD*)
      : > "$FAKE_OUT/hold-ready"
      while [ ! -f "$FAKE_OUT/hold-go" ]; do sleep 0.05; done
      first=$(mcp_call '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"chat_post","arguments":{"to":"'"$to"'","text":"held body original","kind":"all_done","done":"sent held post"}}}')
      printf '%s' "$first" > "$FAKE_OUT/hold-first.json"
      hid=$(printf '%s' "$first" | sed -n 's/.*Held as \(held-[0-9]*\).*/\1/p')
      printf '%s' "$hid" > "$FAKE_OUT/hold-id"
      # Wait for the steered unread message on stdin, mark it read via requesting status, then resend held post.
      while IFS= read -r steer_line; do
        case "$steer_line" in
          *'"type":"user"'*)
            printf '%s\n' "$steer_line" >> "$FAKE_OUT/prompts-$sid.jsonl"
            say '{"type":"system","subtype":"status","status":"requesting","session_id":"'"$sid"'"}'
            # (a step after it on the same stdout: once the live stream shows it, the station read the requesting)
            say '{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"hold-ack","name":"HOLD-READ-ACK"}},"session_id":"'"$sid"'"}'
            while [ ! -f "$FAKE_OUT/hold-read-done" ]; do sleep 0.05; done
            break ;;
        esac
      done
      second=$(mcp_call '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"chat_post","arguments":{"to":"'"$to"'","send":"'"$hid"'","kind":"all_done","done":"sent held post"}}}')
      printf '%s' "$second" > "$FAKE_OUT/hold-second.json"
      say '{"type":"result","subtype":"success","is_error":false,"duration_ms":1,"num_turns":1,"session_id":"'"$sid"'","result":"held-done"}'
      continue ;;

    *SCENARIO-CARD-CLOSE*)
      res=$(mcp_call '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"chat_post","arguments":{"to":"'"$to"'","text":"要部署吗？","card":{"type":"options","assignee":"ada@x.com","options":[{"label":"部署","action":"reply"},{"label":"不需要部署","action":"close"}]}}}}')
      printf '%s' "$res" > "$FAKE_OUT/card-close-post.json"
      st=$(mcp_call '{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"chat_state","arguments":{"kind":"need_human","need":"选是否部署"}}}')
      printf '%s' "$st" > "$FAKE_OUT/card-close-state.json"
      say '{"type":"result","subtype":"success","is_error":false,"duration_ms":1,"num_turns":1,"session_id":"'"$sid"'","result":"asked-close"}'
      continue ;;

    *SCENARIO-GOES-ON*)
      : > "$FAKE_OUT/goes-on-active"
      mcp_call '{"jsonrpc":"2.0","id":30,"method":"tools/call","params":{"name":"chat_post","arguments":{"to":"'"$to"'","text":"first all_done","kind":"all_done","done":"initial done claim"}}}' > "$FAKE_OUT/goes-on-1.json"
      mcp_call '{"jsonrpc":"2.0","id":31,"method":"tools/call","params":{"name":"chat_post","arguments":{"to":"'"$to"'","text":"actually continuing work"}}}' > "$FAKE_OUT/goes-on-2.json"
      say '{"type":"result","subtype":"success","is_error":false,"duration_ms":1,"num_turns":1,"session_id":"'"$sid"'","result":"went-on"}'
      continue ;;

    *SCENARIO-WATCH-WAIT*)
      res=$(mcp_call '{"jsonrpc":"2.0","id":40,"method":"tools/call","params":{"name":"chat_state","arguments":{"kind":"waiting","seconds":300,"for":"盯 CI","watch":true}}}')
      printf '%s' "$res" > "$FAKE_OUT/watch-state.json"
      say '{"type":"result","subtype":"success","is_error":false,"duration_ms":1,"num_turns":1,"session_id":"'"$sid"'","result":"watching"}'
      continue ;;
  esac

  if [ -f "$FAKE_OUT/goes-on-active" ]; then
    rm -f "$FAKE_OUT/goes-on-active"
    printf '%s\n' "$line" > "$FAKE_OUT/goes-on-nudged.txt"
    mcp_call '{"jsonrpc":"2.0","id":32,"method":"tools/call","params":{"name":"chat_state","arguments":{"kind":"all_done","done":"finished after goesOn re-prompt"}}}' > "$FAKE_OUT/goes-on-3.json"
    say '{"type":"result","subtype":"success","is_error":false,"duration_ms":1,"num_turns":1,"session_id":"'"$sid"'","result":"nudged-done"}'
    continue
  fi

  if [ -n "$to" ]; then
    mcp_call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"chat_post","arguments":{"to":"'"$to"'","text":"reply-'"$n"'-'"$model"'-'"$effort"'","kind":"all_done","done":"answered turn '"$n"' on '"$init_model"'"}}}' > "$FAKE_OUT/post-$sid-$n.json"
  else
    mcp_call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"chat_state","arguments":{"kind":"all_done","done":"handled station notice turn '"$n"'"}}}' > "$FAKE_OUT/post-$sid-$n.json"
  fi
  say '{"type":"result","subtype":"success","is_error":false,"duration_ms":1,"num_turns":1,"session_id":"'"$sid"'","result":"ok"}'
done
`;
  writeFileSync(join(dir, "claude"), claude);
  chmodSync(join(dir, "claude"), 0o755);
}

type Launched = {
  child: ChildProcess;
  said: any[];
  next: (what: string, ok: (m: any) => boolean) => Promise<any>;
  tell: (m: unknown) => void;
  ended: Promise<number | null>;
  err: () => string;
};

const listener = (port = 0) => new Promise<Server>((resolve, reject) => {
  const s = createServer();
  s.once("error", reject);
  s.listen(port, "127.0.0.1", () => resolve(s));
});

async function launch(data: string, app: string, bin: string, out: string, extraEnv: Record<string, string> = {}, sockets?: [Server, Server]): Promise<Launched> {
  const [mcpSock, loopSock] = sockets ?? [await listener(), await listener()];
  const fd = (s: Server) => (s as any)._handle.fd as number;
  const child = spawn(binary!, ["run", "--app", app, "--data", data, "--launcher-fds", "3,4,5", "--launcher-carries", "--launcher-heartbeat"], {
    stdio: ["ignore", "pipe", "pipe", fd(mcpSock), fd(loopSock), "pipe"],
    env: {
      PATH: bin,
      HOME: data,
      TMPDIR: tmpdir(),
      STILLFAIL_RUNNER: runner,
      STILLFAIL_HELD_EVERY_MS: "300",
      STILLFAIL_AGENT_NICE: "0",
      STILLFAIL_LOCAL_ADMIN: "1",
      FAKE_OUT: out,
      STILLFAIL_P52_TRACE: process.env.STILLFAIL_P52_TRACE ?? "1",
      ...extraEnv,
    },
  });
  children.push(child);
  mcpSock.close();
  loopSock.close();
  const said: any[] = [];
  const waiters: (() => void)[] = [];
  createInterface({ input: (child.stdio as readonly unknown[])[5] as import("node:net").Socket }).on("line", (line) => {
    said.push(JSON.parse(line));
    for (const w of waiters.splice(0)) w();
  });
  let err = "";
  child.stderr!.on("data", (d) => (err += d));
  const next = (what: string, ok: (m: any) => boolean) =>
    new Promise<any>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`never said: ${what}; said ${JSON.stringify(said)}; stderr ${err}`)), 30_000);
      const look = () => {
        const found = said.find(ok);
        if (found !== undefined) {
          clearTimeout(timer);
          resolve(found);
        } else waiters.push(look);
      };
      look();
    });
  const ended = new Promise<number | null>((resolve) => child.on("exit", (code) => resolve(code)));
  return {
    child,
    said,
    next,
    tell: (m) => ((child.stdio as readonly unknown[])[5] as import("node:net").Socket).write(`${JSON.stringify(m)}\n`),
    ended,
    err: () => err,
  };
}

function httpJson(port: number, path: string, method = "GET", body?: unknown, headers: Record<string, string> = {}): Promise<{ status: number; json: any; raw: string }> {
  return new Promise((resolve, reject) => {
    const req = request({
      host: "127.0.0.1",
      port,
      path,
      method,
      headers: { "content-type": "application/json", ...headers },
    }, (res) => {
      let raw = "";
      res.on("data", (d) => (raw += d));
      res.on("end", () => {
        let json: any = raw;
        try { json = raw === "" ? null : JSON.parse(raw); } catch {}
        resolve({ status: res.statusCode!, json, raw });
      });
    });
    req.on("error", reject);
    req.end(body === undefined ? undefined : JSON.stringify(body));
  });
}

async function tool(port: number, token: string, name: string, args: unknown = {}): Promise<{ text: string; error: boolean }> {
  const res = await httpJson(port, "/mcp", "POST", { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name, arguments: args } }, { authorization: `Bearer ${token}` });
  assert.equal(res.status, 200, `${name} status ${res.status}: ${res.raw}`);
  assert.equal(res.json.error, undefined, `${name} rpc error: ${res.raw}`);
  return { text: res.json.result.content[0].text, error: res.json.result.isError === true };
}

/// An event stream of the admin API: what it said so far, and its closing.
function events(port: number, path: string) {
  const heard: string[] = [];
  let close = () => {};
  const opened = new Promise<number>((resolve, reject) => {
    const req = request({ host: "127.0.0.1", port, path }, (res) => {
      res.setEncoding("utf8");
      res.on("data", (d: string) => heard.push(d));
      resolve(res.statusCode!);
    });
    req.on("error", reject);
    close = () => req.destroy();
    req.end();
  });
  return { opened, close: () => close(), text: () => heard.join("") };
}

async function until<T>(what: string, look: () => T | null | undefined | false | Promise<T | null | undefined | false>, detail: () => string = () => "", timeoutMs = 45_000): Promise<T> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const v = await look();
    if (v) return v;
    if (Date.now() > end) throw new Error(`never: ${what}; ${detail()}`);
    await new Promise((r) => setTimeout(r, 50));
  }
}

const alive = (pid: number, group = false) => {
  try {
    process.kill(group ? -pid : pid, 0);
    return true;
  } catch {
    return false;
  }
};

function seedSession(
  store: Store,
  data: string,
  opts: {
    key: string;
    token: string;
    ts: string;
    title?: string;
    model?: string;
    effort?: string;
    createdBy?: string;
    ws?: string;
  },
) {
  const workspace = join(data, "sessions", "chat", opts.key.slice(5), "workspace");
  mkdirSync(workspace, { recursive: true });
  const now = Date.now();
  store.insertSession({
    key: opts.key,
    connect: "ember",
    runtime: "claude",
    profile: "cc",
    model: opts.model ?? "claude-sonnet-4-6",
    effort: opts.effort ?? null,
    createdBy: opts.createdBy ?? "ada@x.com",
    workspace,
    token: opts.token,
    createdAt: now,
    lastActiveAt: now,
    title: opts.title ?? `chat ${opts.key}`,
    ...(opts.ws ? { ws: opts.ws } : {}),
  } as never);
  const thread = store.openThreadOf("ember", "CHAT", opts.ts, opts.title ?? `chat ${opts.key}`, opts.createdBy ?? "ada@x.com", opts.key);
  store.joinThread(thread.id, opts.key, "ember");
  return { thread, workspace };
}

async function startStation(tag: string) {
  const data = fresh(`${tag}d`);
  const app = fresh(`${tag}a`);
  const bin = fresh(`${tag}b`);
  const out = fresh(`${tag}o`);
  writeFileSync(join(app, "BUILD"), "10400\n");
  installFakeClaude(bin);
  mkdirSync(join(data, "homes", "cc"), { recursive: true });
  writeFileSync(join(data, "homes", "cc", ".credentials.json"), "{}");
  writeFileSync(join(data, "config.json"), JSON.stringify({
    profiles: [
      { id: "cc", runtime: "claude", home: "homes/cc", access: { kind: "anthropic-api", key: "sk-test" }, models: ["claude-sonnet-4-6", "claude-opus-4-6"] },
    ],
    maxNudges: 1,
  }));
  mkdirSync(join(data, "mesh"), { recursive: true });
  writeFileSync(join(data, "mesh", "cloud.json"), JSON.stringify({
    origin: "https://app.example",
    workspace: "w1",
    workspace_name: "W",
    station: "st1",
    name: "here",
  }));
  const proc = await launch(data, app, bin, out);
  await proc.next("ready", (m) => m.ready === true);
  const door = (await proc.next("mcp door", (m) => m.serving === "mcp")).port as number;
  const store = Store.open(join(data, "stillfail.db"), join(data, "archive"), { currentTimeMillisUnsafe: () => Date.now() } as never);
  const stop = async () => {
    store.close();
    proc.tell({ op: "stop" });
    assert.equal(await proc.ended, 0, proc.err());
  };
  return { data, app, bin, out, proc, door, store, stop };
}

test("1. MCP session lifecycle: chat_create (me/person/idempotent), cold session_send, chat_list filters, chat_read/chat_history pagination, chat_archive with jobs", { skip, timeout: 120_000 }, async () => {
  const s = await startStation("s1");
  try {
    const { thread: tLead } = seedSession(s.store, s.data, { key: "chat:c-lead", token: "t-lead", ts: "1791000001.000001", title: "Lead Chat", model: "claude-opus-4-6", createdBy: "ada@x.com" });
    const { thread: tCold } = seedSession(s.store, s.data, { key: "chat:c-cold", token: "t-cold", ts: "1791000002.000001", title: "Cold Target", model: "claude-sonnet-4-6", createdBy: "ada@x.com" });
    const { thread: tBob } = seedSession(s.store, s.data, { key: "chat:c-bob", token: "t-bob", ts: "1791000003.000001", title: "Bob Sonnet Chat", model: "claude-sonnet-4-6", createdBy: "bob@x.com" });
    const { thread: tArch } = seedSession(s.store, s.data, { key: "chat:c-arch", token: "t-arch", ts: "1791000004.000001", title: "Ada Archived Sonnet", model: "claude-sonnet-4-6", createdBy: "ada@x.com" });
    s.store.setArchived("chat:c-arch", true, "manual");
    void tLead;
    void tBob;
    void tArch;

    // ── session_send to a cold session (never had an in-memory actor) ──
    const sent = await tool(s.door, "t-lead", "session_send", { to: "chat:c-cold", text: "wake up cold B" });
    assert.equal(sent.error, false, `${sent.text}\n${s.proc.err()}`);
    await until("cold B finished its turn", () => s.store.listTurns("chat:c-cold").some((t) => t.summary.ending === "all_done" && t.summary.endedAt != null), () => s.proc.err());
    const coldAgentMsgs = s.store.messagesBefore(tCold.id, null, 20).filter((m) => m.authorKind === "agent");
    assert.ok(coldAgentMsgs.some((m) => m.text.startsWith("reply-1-")), JSON.stringify(coldAgentMsgs));
    const allPrompts = readFileSync(join(s.out, "all-prompts.jsonl"), "utf8");
    assert.ok(allPrompts.includes("wake up cold B"), "cold B received the message body");
    assert.ok(allPrompts.includes("https://app.example/o/w1/st1/chat%3Ac-lead") || allPrompts.includes("chat:c-lead"), `cold B prompt should include sender link: ${allPrompts}`);

    // ── chat_create: for: "me" (led) + idempotent key + for: "person" (independent) ──
    assert.equal(s.store.listTurns("chat:c-lead").length, 0, "leader has no turns before led child ends");
    const ledRes = await tool(s.door, "t-lead", "chat_create", { for: "me", key: "led-k1", text: "run led task", title: "Led Task", runtime: "claude" });
    assert.equal(ledRes.error, false, `${ledRes.text}\n${s.proc.err()}`);
    const opened = s.store.openedBy("chat:c-lead");
    assert.equal(opened.length, 1);
    const ledChild = opened[0]!.child;
    assert.equal(s.store.openerOf(ledChild)?.led, true);
    // Wait for led child to complete AND wake up parent
    await until("led child ended", () => s.store.listTurns(ledChild).some((t) => t.summary.ending === "all_done" && t.summary.endedAt != null), () => s.proc.err());
    await until("leader woken by led child", () => s.store.listTurns("chat:c-lead").some((t) => t.summary.ending === "all_done" && t.summary.endedAt != null), () => s.proc.err());
    const leadTurnsAfterLed = s.store.listTurns("chat:c-lead").length;
    assert.equal(leadTurnsAfterLed, 1, "leader finished its wakeup turn cleanly without a nudge");

    // Idempotent key: reuses the exact same session, does not duplicate first message
    const ledThread = s.store.homeChat(ledChild)!;
    const ledMsgsBefore = s.store.messagesBefore(ledThread.id, null, 50).length;
    const again = await tool(s.door, "t-lead", "chat_create", { for: "me", key: "led-k1", text: "run led task", runtime: "claude" });
    assert.equal(again.error, false, again.text);
    assert.match(again.text, /already opened/, again.text);
    assert.equal(s.store.openedBy("chat:c-lead").length, 1);
    assert.equal(s.store.messagesBefore(ledThread.id, null, 50).length, ledMsgsBefore);

    // for: "person": child runs and completes, does NOT wake parent
    const personRes = await tool(s.door, "t-lead", "chat_create", { for: "person", key: "person-k1", text: "run person task", title: "Person Task", runtime: "claude" });
    assert.equal(personRes.error, false, `${personRes.text}\n${s.proc.err()}`);
    const personChild = s.store.openedBy("chat:c-lead").find((o) => o.key === "person-k1")!.child;
    assert.equal(s.store.openerOf(personChild)?.led, false);
    await until("person child ended", () => s.store.listTurns(personChild).some((t) => t.summary.ending === "all_done" && t.summary.endedAt != null), () => s.proc.err());
    await new Promise((r) => setTimeout(r, 400));
    assert.equal(s.store.listTurns("chat:c-lead").length, leadTurnsAfterLed, "for: person child must not notify/wake parent");

    // ── chat_list: query, model, created_by, archived (true/false/omit) ──
    const listMineActive = await tool(s.door, "t-lead", "chat_list", { model: "sonnet", created_by: "me", archived: false });
    assert.equal(listMineActive.error, false, listMineActive.text);
    assert.ok(listMineActive.text.includes("Cold Target"), listMineActive.text);
    assert.ok(!listMineActive.text.includes("Ada Archived Sonnet"), listMineActive.text);
    assert.ok(!listMineActive.text.includes("Bob Sonnet Chat"), listMineActive.text);
    assert.ok(!listMineActive.text.includes("Lead Chat"), listMineActive.text);

    const listMineArchived = await tool(s.door, "t-lead", "chat_list", { model: "sonnet", created_by: "me", archived: true });
    assert.equal(listMineArchived.error, false, listMineArchived.text);
    assert.ok(listMineArchived.text.includes("Ada Archived Sonnet"), listMineArchived.text);
    assert.ok(!listMineArchived.text.includes("Cold Target"), listMineArchived.text);

    const listMineBoth = await tool(s.door, "t-lead", "chat_list", { model: "sonnet", created_by: "ada@x.com" });
    assert.equal(listMineBoth.error, false, listMineBoth.text);
    assert.ok(listMineBoth.text.includes("Cold Target") && listMineBoth.text.includes("Ada Archived Sonnet"), listMineBoth.text);

    const listBob = await tool(s.door, "t-lead", "chat_list", { created_by: "bob@x.com" });
    assert.equal(listBob.error, false, listBob.text);
    assert.ok(listBob.text.includes("Bob Sonnet Chat") && !listBob.text.includes("Cold Target"), listBob.text);

    const listQuery = await tool(s.door, "t-lead", "chat_list", { query: "Cold Target" });
    assert.equal(listQuery.error, false, listQuery.text);
    assert.ok(listQuery.text.includes("Cold Target") && !listQuery.text.includes("Bob Sonnet Chat"), listQuery.text);

    // ── chat_history & chat_read with limit & before pagination ──
    const { thread: tPage } = seedSession(s.store, s.data, { key: "chat:c-page", token: "t-page", ts: "1791000005.000001", title: "Page Chat" });
    const msgTs = ["1791000005.000100", "1791000005.000200", "1791000005.000300", "1791000005.000400", "1791000005.000500"];
    for (let i = 0; i < msgTs.length; i++) {
      s.store.insertMessage({ thread: tPage.id, ts: msgTs[i]!, authorKind: "person", author: "ada@x.com", text: `page-msg-${i + 1}` });
    }
    const pageAddr = `CHAT/${tPage.threadTs}`;
    const hist1 = await tool(s.door, "t-page", "chat_history", { to: pageAddr, limit: 2 });
    assert.equal(hist1.error, false, hist1.text);
    assert.ok(hist1.text.includes("page-msg-4") && hist1.text.includes("page-msg-5") && !hist1.text.includes("page-msg-3"), hist1.text);

    const hist2 = await tool(s.door, "t-page", "chat_history", { to: pageAddr, limit: 2, before: msgTs[3] });
    assert.equal(hist2.error, false, hist2.text);
    assert.ok(hist2.text.includes("page-msg-2") && hist2.text.includes("page-msg-3") && !hist2.text.includes("page-msg-4"), hist2.text);

    const read1 = await tool(s.door, "t-lead", "chat_read", { chat: "chat:c-page", limit: 2 });
    assert.equal(read1.error, false, read1.text);
    assert.ok(read1.text.includes("page-msg-4") && read1.text.includes("page-msg-5") && !read1.text.includes("page-msg-3"), read1.text);

    const read2 = await tool(s.door, "t-lead", "chat_read", { chat: pageAddr, limit: 2, before: msgTs[3] });
    assert.equal(read2.error, false, read2.text);
    assert.ok(read2.text.includes("page-msg-2") && read2.text.includes("page-msg-3") && !read2.text.includes("page-msg-4"), read2.text);

    // ── chat_archive: stops running job, preserves ended job & logs, marks archived_at ──
    const doneJob = JSON.parse((await tool(s.door, "t-cold", "job_start", { name: "finished-job", command: "echo preserved-log" })).text);
    await until("finished-job exited", () => s.store.getJob(doneJob.id)?.state === "exited", () => s.proc.err());
    const liveJob = JSON.parse((await tool(s.door, "t-cold", "job_start", { name: "running-job", command: "sleep 600" })).text);
    const livePgid = await until("running-job pgid recorded", () => s.store.getJob(liveJob.id)?.pgid ?? null, () => s.proc.err());
    assert.ok(alive(livePgid, true), "running job group alive before archive");

    // Self-archive refused
    const selfArch = await tool(s.door, "t-cold", "chat_archive", { chat: "chat:c-cold" });
    assert.equal(selfArch.error, true);
    assert.match(selfArch.text, /not your own/, selfArch.text);

    // Archive another chat
    const archived = await tool(s.door, "t-lead", "chat_archive", { chat: "chat:c-cold" });
    assert.equal(archived.error, false, archived.text);
    assert.match(archived.text, /^Archived /, archived.text);
    const coldRow = s.store.getSession("chat:c-cold")!;
    assert.ok(coldRow.archivedAt != null && coldRow.archivedAt > 0, "archived_at set");
    assert.equal(coldRow.archivedBy, "manual");
    await until("running job stopped on archive", () => s.store.getJob(liveJob.id)?.state === "stopped" && !alive(livePgid, true), () => s.proc.err());
    const doneRowAfter = s.store.getJob(doneJob.id)!;
    assert.equal(doneRowAfter.state, "exited", "ended job preserved");
    assert.ok(existsSync(doneRowAfter.log) && readFileSync(doneRowAfter.log, "utf8").includes("preserved-log"), "ended job log preserved");

    // Repeated archive is idempotent
    const archivedAgain = await tool(s.door, "t-lead", "chat_archive", { chat: "chat:c-cold" });
    assert.equal(archivedAgain.error, false, archivedAgain.text);
    assert.match(archivedAgain.text, /^Already archived/, archivedAgain.text);
    assert.equal(s.store.getSession("chat:c-cold")!.archivedAt, coldRow.archivedAt);
  } finally {
    await s.stop();
  }
});

test("2. chat_post heldPost, options cards + withdraw + Admin API close-card (<card-choice>), chat_state (watch/waiting) & goesOn", { skip, timeout: 120_000 }, async () => {
  const s = await startStation("s2");
  try {
    const { thread: tHold } = seedSession(s.store, s.data, { key: "chat:c-hold", token: "t-hold", ts: "1792000001.000001", title: "Hold Chat" });
    const { thread: tCard } = seedSession(s.store, s.data, { key: "chat:c-card", token: "t-card", ts: "1792000002.000001", title: "Card Chat" });
    const { thread: tState } = seedSession(s.store, s.data, { key: "chat:c-state", token: "t-state", ts: "1792000003.000001", title: "State Chat" });

    // ── heldPost: unread message holds chat_post; resend with send=<held-id> posts original text & ends all_done ──
    // (the live stream says when the station read the agent's requesting after the steer: what clears its unread)
    const live = events(s.door, "/admin-api/events?live=chat%3Ac-hold&from=0");
    try {
      assert.equal(await live.opened, 200);
      const holdStart = await httpJson(s.door, `/admin-api/threads/${tHold.id}/messages`, "POST", { text: "SCENARIO-HOLD" });
      assert.equal(holdStart.status, 200, holdStart.raw);
      await until("fake claude ready for unread message", () => existsSync(join(s.out, "hold-ready")), () => s.proc.err());
      const unreadMsg = await httpJson(s.door, `/admin-api/threads/${tHold.id}/messages`, "POST", { text: "UNREAD-TRIGGER" });
      assert.equal(unreadMsg.status, 200, unreadMsg.raw);
      writeFileSync(join(s.out, "hold-go"), "1");
      await until("the station read the requesting after the steer", () => live.text().includes("HOLD-READ-ACK"), () => `${s.proc.err()}\nlive=${live.text().slice(-400)}`);
      writeFileSync(join(s.out, "hold-read-done"), "1");
      await until("heldPost turn completed", () => existsSync(join(s.out, "hold-second.json")) && s.store.lastTurn("chat:c-hold")?.endedAt != null, () => s.proc.err());
      const holdFirst = JSON.parse(readFileSync(join(s.out, "hold-first.json"), "utf8"));
      assert.match(holdFirst.result.content[0].text, /^Not posted:.*Held as held-\d+/, JSON.stringify(holdFirst));
      const holdSecond = JSON.parse(readFileSync(join(s.out, "hold-second.json"), "utf8"));
      assert.notEqual(holdSecond.result.isError, true, JSON.stringify(holdSecond));
      assert.match(holdSecond.result.content[0].text, /Posted to CHAT\/1792000001\.000001, and recorded state all_done\./);
      assert.ok(s.store.messagesBefore(tHold.id, null, 20).some((m) => m.authorKind === "agent" && m.text === "held body original"));
      assert.equal(s.store.lastTurn("chat:c-hold")!.ending, "all_done");
    } finally {
      live.close();
    }

    // ── options card + withdraw ──
    const cardAddr = `CHAT/${tCard.threadTs}`;
    const cardPost = await tool(s.door, "t-card", "chat_post", {
      to: cardAddr,
      text: "临时问题？",
      card: { type: "options", assignee: "ada@x.com", options: [{ label: "是", action: "reply" }, { label: "否", action: "close" }] },
    });
    assert.equal(cardPost.error, false, cardPost.text);
    const pending1 = s.store.pendingCard(tCard.id);
    assert.ok(pending1 !== null, "card is pending");
    const msgCountBeforeWithdraw = s.store.messagesBefore(tCard.id, null, 50).length;
    const withdrawn = await tool(s.door, "t-card", "chat_post", { to: cardAddr, withdraw: pending1[0].ts });
    assert.equal(withdrawn.error, false, withdrawn.text);
    assert.equal(s.store.pendingCard(tCard.id), null, "card withdrawn");
    assert.equal(s.store.messagesBefore(tCard.id, null, 50).length, msgCountBeforeWithdraw, "withdraw adds no message");

    // ── Human chooses action: "close" via Admin API: no wakeup; next message injects <card-choice> ──
    const askClose = await httpJson(s.door, `/admin-api/threads/${tCard.id}/messages`, "POST", { text: "SCENARIO-CARD-CLOSE" });
    assert.equal(askClose.status, 200, askClose.raw);
    await until("card-close turn ended need_help", () => existsSync(join(s.out, "card-close-state.json")) && s.store.lastTurn("chat:c-card")?.endedAt != null && s.store.pendingCard(tCard.id) !== null, () => s.proc.err());
    assert.notEqual(JSON.parse(readFileSync(join(s.out, "card-close-state.json"), "utf8")).result.isError, true);
    assert.equal(s.store.lastTurn("chat:c-card")!.ending, "need_help");
    const closeCardEntry = s.store.pendingCard(tCard.id)![0];
    const turnsBeforeClose = s.store.listTurns("chat:c-card").length;

    const closed = await httpJson(s.door, `/admin-api/threads/${tCard.id}/closed-card`, "PUT", { n: closeCardEntry.n, option: "不需要部署" });
    assert.equal(closed.status, 200, closed.raw);
    assert.deepEqual(closed.json, { closedCard: { thread: tCard.id, n: closeCardEntry.n } });
    assert.equal(s.store.pendingCard(tCard.id), null, "card closed");
    await new Promise((r) => setTimeout(r, 350));
    assert.equal(s.store.listTurns("chat:c-card").length, turnsBeforeClose, "closing a card must not wake the agent");
    assert.equal(s.store.getSession("chat:c-card")!.running, false);
    assert.equal(s.store.untoldCardChoices("chat:c-card").length, 1);

    // Next human message injects <card-choice> before the new message
    const nextMsg = await httpJson(s.door, `/admin-api/threads/${tCard.id}/messages`, "POST", { text: "另外看下日志" });
    assert.equal(nextMsg.status, 200, nextMsg.raw);
    await until("card chat answered next message", () => s.store.listTurns("chat:c-card").length > turnsBeforeClose && s.store.lastTurn("chat:c-card")?.endedAt != null, () => s.proc.err());
    const allPrompts = readFileSync(join(s.out, "all-prompts.jsonl"), "utf8");
    const lastPromptLine = allPrompts.trim().split("\n").filter((l) => l.includes("另外看下日志")).at(-1)!;
    assert.ok(lastPromptLine.includes("<card-choice"), `expected <card-choice> in prompt: ${lastPromptLine}`);
    assert.ok(lastPromptLine.includes("不需要部署"), `expected chosen option in prompt: ${lastPromptLine}`);
    assert.ok(lastPromptLine.indexOf("<card-choice") < lastPromptLine.indexOf("另外看下日志"), "card-choice precedes new message");
    assert.equal(s.store.untoldCardChoices("chat:c-card").length, 0, "untold choice cleared once delivered");

    // ── chat_state: waiting with watch: true ──
    const watchJob = JSON.parse((await tool(s.door, "t-state", "job_start", { name: "ci-watch", command: "sleep 600", watch: true })).text);
    const watchReq = await httpJson(s.door, `/admin-api/threads/${tState.id}/messages`, "POST", { text: "SCENARIO-WATCH-WAIT" });
    assert.equal(watchReq.status, 200, watchReq.raw);
    await until("watch waiting turn ended", () => existsSync(join(s.out, "watch-state.json")) && s.store.lastTurn("chat:c-state")?.endedAt != null, () => s.proc.err());
    const watchStateRes = JSON.parse(readFileSync(join(s.out, "watch-state.json"), "utf8"));
    assert.notEqual(watchStateRes.result.isError, true, JSON.stringify(watchStateRes));
    assert.equal(s.store.lastTurn("chat:c-state")!.ending, "waiting");
    await tool(s.door, "t-state", "job_stop", { id: watchJob.id });

    // ── goesOn: bare chat_post after all_done in same turn clears all_done and triggers re-prompt ──
    const turnsBeforeGoesOn = s.store.listTurns("chat:c-state").length;
    const goesOnReq = await httpJson(s.door, `/admin-api/threads/${tState.id}/messages`, "POST", { text: "SCENARIO-GOES-ON" });
    assert.equal(goesOnReq.status, 200, goesOnReq.raw);
    await until("goesOn triggered re-prompt and finished", () => existsSync(join(s.out, "goes-on-nudged.txt")) && s.store.listTurns("chat:c-state").length > turnsBeforeGoesOn && s.store.lastTurn("chat:c-state")?.endedAt != null, () => s.proc.err());
    const nudgedTurn = s.store.lastTurn("chat:c-state")!;
    assert.equal(nudgedTurn.ending, "all_done");
    assert.equal(nudgedTurn.need, "finished after goesOn re-prompt");
  } finally {
    await s.stop();
  }
});

test("3. chat_configure & Admin API settings dynamically update model/effort/speed on next turn and agent_identity", { skip, timeout: 120_000 }, async () => {
  const s = await startStation("s3");
  try {
    seedSession(s.store, s.data, { key: "chat:c-ctrl", token: "t-ctrl", ts: "1793000001.000001", title: "Control", model: "claude-opus-4-6", effort: "high" });
    const { thread: tCfg } = seedSession(s.store, s.data, { key: "chat:c-cfg", token: "t-cfg", ts: "1793000002.000001", title: "Config Target", model: "claude-sonnet-4-6", effort: "low" });

    // Turn 1: initial model claude-sonnet-4-6, effort low
    const m1 = await httpJson(s.door, `/admin-api/threads/${tCfg.id}/messages`, "POST", { text: "turn one" });
    assert.equal(m1.status, 200, m1.raw);
    await until("turn 1 ended", () => s.store.listTurns("chat:c-cfg").length === 1 && s.store.lastTurn("chat:c-cfg")?.endedAt != null, () => s.proc.err());
    const launches = () => readFileSync(join(s.out, "launches.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l));
    assert.equal(launches().at(-1).model, "claude-sonnet-4-6");
    assert.equal(launches().at(-1).effort, "low");
    const msg1 = s.store.messagesBefore(tCfg.id, null, 20).filter((m) => m.authorKind === "agent").at(-1)!;
    assert.equal((msg1.agentIdentity as any)?.model, "claude-sonnet-4-6");

    // Reconfigure via MCP chat_configure: model -> claude-opus-4-6, effort -> high, speed -> fast
    const cfgRes = await tool(s.door, "t-ctrl", "chat_configure", { chat: "chat:c-cfg", model: "claude-opus-4-6", effort: "high", speed: "fast" });
    assert.equal(cfgRes.error, false, cfgRes.text);
    const parsedCfg = JSON.parse(cfgRes.text);
    assert.equal(parsedCfg.updated, true);
    assert.equal(parsedCfg.after.model, "claude-opus-4-6");
    assert.equal(parsedCfg.after.effort, "high");
    assert.equal(parsedCfg.after.led, false);
    assert.equal(parsedCfg.after.leader, null);

    // Ownership via chat_configure { for: "me" | "person" } on MoonBit station:
    const adoptRes = await tool(s.door, "t-ctrl", "chat_configure", { chat: "chat:c-cfg", for: "me" });
    assert.equal(adoptRes.error, false, adoptRes.text);
    const adopted = JSON.parse(adoptRes.text);
    assert.equal(adopted.updated, true);
    assert.equal(adopted.after.led, true);
    assert.equal(adopted.after.leader, "chat:c-ctrl");
    assert.equal(s.store.openerOf("chat:c-cfg")?.led, true);
    assert.equal(s.store.openerOf("chat:c-cfg")?.parent, "chat:c-ctrl");
    assert.equal(s.store.openerOf("chat:c-cfg")?.title, null);
    assert.equal(s.store.openerOf("chat:c-cfg")?.openerTitle, null);

    // Protections: self-lead and cycle refused.
    const selfErr = await tool(s.door, "t-ctrl", "chat_configure", { for: "me" });
    assert.equal(selfErr.error, true);
    assert.match(selfErr.text, /cannot lead your own chat/);
    const cycleErr = await tool(s.door, "t-cfg", "chat_configure", { chat: "chat:c-ctrl", for: "me" });
    assert.equal(cycleErr.error, true);
    assert.match(cycleErr.text, /already leads this one/);

    // Release back to person and verify idempotency.
    const relRes = await tool(s.door, "t-ctrl", "chat_configure", { chat: "chat:c-cfg", for: "person" });
    assert.equal(relRes.error, false, relRes.text);
    const released = JSON.parse(relRes.text);
    assert.equal(released.updated, true);
    assert.equal(released.after.led, false);
    assert.equal(released.after.leader, null);
    assert.equal(s.store.openerOf("chat:c-cfg")?.led, false);
    const relAgain = await tool(s.door, "t-ctrl", "chat_configure", { chat: "chat:c-cfg", for: "person" });
    assert.equal(relAgain.error, false, relAgain.text);
    assert.equal(JSON.parse(relAgain.text).updated, false);

    // Turn 2: must immediately use new model/effort/fastMode in claude argv and agent_identity
    const m2 = await httpJson(s.door, `/admin-api/threads/${tCfg.id}/messages`, "POST", { text: "turn two" });
    assert.equal(m2.status, 200, m2.raw);
    await until("turn 2 ended", () => s.store.listTurns("chat:c-cfg").length === 2 && s.store.lastTurn("chat:c-cfg")?.endedAt != null, () => s.proc.err());
    const launch2 = launches().at(-1);
    assert.equal(launch2.model, "claude-opus-4-6", `expected new model in launch argv: ${JSON.stringify(launch2)}`);
    assert.equal(launch2.effort, "high", `expected new effort in launch argv: ${JSON.stringify(launch2)}`);
    assert.equal(launch2.settings?.fastMode, true, `expected fastMode=true in settings: ${JSON.stringify(launch2)}`);
    const msg2 = s.store.messagesBefore(tCfg.id, null, 20).filter((m) => m.authorKind === "agent").at(-1)!;
    assert.equal((msg2.agentIdentity as any)?.model, "claude-opus-4-6", `stale agentIdentity: ${JSON.stringify(msg2.agentIdentity)}`);
    assert.equal((msg2.agentIdentity as any)?.effort, "high", `stale effort in agentIdentity: ${JSON.stringify(msg2.agentIdentity)}`);
    assert.ok(!msg2.text.includes("claude-sonnet-4-6"), `stale model leaked to reply: ${msg2.text}`);

    // Reconfigure via Admin API POST /admin-api/sessions/:key/settings back to claude-sonnet-4-6, medium, fast: false
    const setRes = await httpJson(s.door, `/admin-api/sessions/${encodeURIComponent("chat:c-cfg")}/settings`, "POST", { model: "claude-sonnet-4-6", effort: "medium", fast: false });
    assert.equal(setRes.status, 200, setRes.raw);

    // Turn 3: reflects Admin API change immediately
    const m3 = await httpJson(s.door, `/admin-api/threads/${tCfg.id}/messages`, "POST", { text: "turn three" });
    assert.equal(m3.status, 200, m3.raw);
    await until("turn 3 ended", () => s.store.listTurns("chat:c-cfg").length === 3 && s.store.lastTurn("chat:c-cfg")?.endedAt != null, () => s.proc.err());
    const launch3 = launches().at(-1);
    assert.equal(launch3.model, "claude-sonnet-4-6", `expected updated model: ${JSON.stringify(launch3)}`);
    assert.equal(launch3.effort, "medium", `expected updated effort: ${JSON.stringify(launch3)}`);
    assert.notEqual(launch3.settings?.fastMode, true, `expected fastMode disabled: ${JSON.stringify(launch3)}`);
    const msg3 = s.store.messagesBefore(tCfg.id, null, 20).filter((m) => m.authorKind === "agent").at(-1)!;
    assert.equal((msg3.agentIdentity as any)?.model, "claude-sonnet-4-6");
    assert.equal((msg3.agentIdentity as any)?.effort, "medium");
  } finally {
    await s.stop();
  }
});

test("4. manually archived session refuses messages and does not wake up", { skip, timeout: 120_000 }, async () => {
  const s = await startStation("s4");
  try {
    seedSession(s.store, s.data, { key: "chat:c-sender", token: "t-sender", ts: "1794000001.000001", title: "Sender" });
    const { thread: tArch } = seedSession(s.store, s.data, { key: "chat:c-archived", token: "t-archived", ts: "1794000002.000001", title: "Archived Chat" });

    // Archive via Admin API
    const archRes = await httpJson(s.door, `/admin-api/sessions/${encodeURIComponent("chat:c-archived")}/archive`, "POST", {});
    assert.equal(archRes.status, 200, archRes.raw);
    assert.ok(s.store.getSession("chat:c-archived")!.archivedAt != null);

    // Attempt to post a human message via Admin API -> refused (409/400)
    const msgRes = await httpJson(s.door, `/admin-api/threads/${tArch.id}/messages`, "POST", { text: "should not wake" });
    assert.ok(msgRes.status >= 400, `expected archived chat message to be refused, got ${msgRes.status}: ${msgRes.raw}`);

    // Attempt session_send to archived chat -> refused or does not wake
    const sendRes = await tool(s.door, "t-sender", "session_send", { to: "chat:c-archived", text: "external trigger" });
    // Even if session_send errors or records, no turn may start on the archived session
    await new Promise((r) => setTimeout(r, 400));
    assert.equal(s.store.listTurns("chat:c-archived").length, 0, `archived session must not start a turn; sendRes=${JSON.stringify(sendRes)}`);
    assert.equal(s.store.getSession("chat:c-archived")!.running, false);
    assert.equal(existsSync(join(s.out, "launches.jsonl")), false, "fake claude must never be spawned for archived session");
  } finally {
    await s.stop();
  }
});

test("5. handover cold wakeup: all_done session with watch job wakes up in new station process on stillfail-job notify", { skip, timeout: 120_000 }, async () => {
  const s = await startStation("s5");
  let b: Launched | null = null;
  let jobPgid = 0;
  try {
    const { thread: tWatch, workspace } = seedSession(s.store, s.data, {
      key: "chat:c-watch",
      token: "t-watch",
      ts: "1795000001.000001",
      title: "Watch Handover Chat",
    });

    // Turn 1: complete a normal all_done turn, then evict so the session is completely cold.
    const m1 = await httpJson(s.door, `/admin-api/threads/${tWatch.id}/messages`, "POST", { text: "initial work" });
    assert.equal(m1.status, 200, m1.raw);
    await until("turn 1 ended all_done", () => s.store.listTurns("chat:c-watch").length === 1 && s.store.lastTurn("chat:c-watch")?.ending === "all_done" && s.store.lastTurn("chat:c-watch")?.endedAt != null, () => s.proc.err());
    const evicted = await httpJson(s.door, `/admin-api/sessions/${encodeURIComponent("chat:c-watch")}/evict`, "POST", {});
    assert.equal(evicted.status, 200, evicted.raw);

    // Start a watch: true background job that waits for `trigger`, then notifies the station.
    const watchJob = JSON.parse((await tool(s.door, "t-watch", "job_start", {
      name: "release-watch",
      watch: true,
      command: "while [ ! -f trigger ]; do sleep 0.05; done; stillfail-job notify HANDOVER-COLD-WAKE; sleep 600",
    })).text);
    jobPgid = await until("watch job pgid recorded", () => s.store.getJob(watchJob.id)?.pgid ?? null, () => s.proc.err());
    assert.ok(alive(jobPgid, true), "watch job group alive before handover");

    // Hand over station `a` to a brand-new `stillfail-reader run` process `b` on the same MCP door port.
    s.proc.tell({ op: "handover" });
    const carry = await s.proc.next("carry", (m) => m.carry !== undefined);
    assert.equal(await s.proc.ended, 0, s.proc.err());
    assert.ok(alive(jobPgid, true), "watch job survives handover");

    b = await launch(s.data, s.app, s.bin, s.out, {}, [await listener(s.door), await listener()]);
    await b.next("b ready", (m) => m.ready === true);
    b.tell({ op: "carried", carried: carry.carry });
    const bDoor = (await b.next("b door", (m) => m.serving === "mcp")).port as number;
    assert.equal(bDoor, s.door, "new station keeps the agents' door port");
    await until("new station adopted prior jobs", () => b!.err().includes("jobs: the jobs of before taken up"), () => b!.err());

    // Trigger `stillfail-job notify HANDOVER-COLD-WAKE` inside the new station process.
    writeFileSync(join(workspace, "trigger"), "go\n");
    await until("notify recorded in store", () => s.store.jobNotices(watchJob.id, 5).some((n) => n.text.includes("HANDOVER-COLD-WAKE")), () => b!.err());
    await until(
      "cold all_done session woken and finished turn 2 in new process",
      () => s.store.listTurns("chat:c-watch").length >= 2 && s.store.lastTurn("chat:c-watch")?.endedAt != null,
      () => b!.err(),
    );
    assert.equal(s.store.lastTurn("chat:c-watch")!.ending, "all_done");
    const allPrompts = readFileSync(join(s.out, "all-prompts.jsonl"), "utf8");
    assert.ok(allPrompts.includes("HANDOVER-COLD-WAKE"), `expected HANDOVER-COLD-WAKE in woken prompt: ${allPrompts}`);

    // Clean up watch job cleanly through the new station.
    const stopped = await tool(bDoor, "t-watch", "job_stop", { id: watchJob.id });
    assert.equal(stopped.error, false, stopped.text);
    await until("watch job group ended", () => !alive(jobPgid, true), () => b!.err());
    jobPgid = 0;

    b.tell({ op: "stop" });
    assert.equal(await b.ended, 0, b.err());
    b = null;
  } finally {
    if (jobPgid > 0 && alive(jobPgid, true)) {
      try { process.kill(-jobPgid, "SIGKILL"); } catch {}
    }
    if (b !== null && b.child.exitCode === null) {
      b.tell({ op: "stop" });
      await Promise.race([b.ended, new Promise((r) => setTimeout(r, 5_000).unref())]);
    }
    s.store.close();
  }
});
