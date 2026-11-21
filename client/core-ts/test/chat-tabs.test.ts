// A chat's side-panel tabs (src/chat-tabs.ts): which of those kept the chat shows and which is in front, and how
// opening, closing, bringing to the front and closing them all change what is kept (`chat.tabs.*`).
import assert from "node:assert/strict";
import { test } from "node:test";
import { changed, tabsOf, type Change } from "../src/chat-tabs.ts";
import { parseCall } from "../src/core/calls.ts";
import { apply, call, subscribe, v } from "./helpers.ts";
import { started } from "./station-fixture.ts";

// deno-lint-ignore no-explicit-any
type J = any;

const agent = (key: string, jobs: string[] = []): J => ({ session: { key }, jobs: jobs.map((id) => ({ id })) });
const AGENTS = [agent("a1", ["web"]), agent("a2")];
const FILE = `file:${JSON.stringify(["a1", "/out/chart.html", "chart.html"])}`;
const SCREEN = `screen:${JSON.stringify(["w1/s1", "simulator:8A17"])}`;
const TERMINAL = `terminal:${JSON.stringify(["w1/s1", "term-1"])}`;
const open = (tab: string): Change => ({ action: "open", tab, auto: true });
const close = (tab: string): Change => ({ action: "close", tab, auto: true });

test("a_chat_shows_the_tabs_kept_it_has_and_the_one_in_front", () => {
  const kept = { tabs: ["a1", "gone", "service:web", "service:old", "jobs", FILE, "file:[1]", "letters", "files", "subchats", SCREEN, "screen:[1]", TERMINAL, "terminal:[\"\"]"], active: "jobs" };
  assert.deepEqual(tabsOf(kept, AGENTS, false, "a1"), { open: ["a1", "service:web", "jobs", FILE, "letters", "files", "subchats", SCREEN, TERMINAL], shown: "jobs" });
  // The one kept in front gone: the first.
  assert.deepEqual(tabsOf({ tabs: ["a2", "a1"], active: "gone" }, AGENTS, false, null), { open: ["a2", "a1"], shown: "a2" });
  // Its agents not known yet: all kept, the panel holding its place.
  assert.deepEqual(tabsOf({ tabs: ["x", "y"] }, [], false, null), { open: ["x", "y"], shown: "x" });
  // None kept: none, but where its agent has no chat yet its history, opened by itself.
  assert.deepEqual(tabsOf(undefined, AGENTS, false, "a1"), { open: [] });
  assert.deepEqual(tabsOf(undefined, AGENTS, true, "a1"), { open: ["a1"], shown: "a1", auto: true });
  assert.deepEqual(tabsOf({ tabs: [] }, AGENTS, true, "a1"), { open: [] }, "kept empty: closed on purpose");
});

test("an_agents_history_opens_after_the_histories_open_and_anything_else_last", () => {
  const kept = { tabs: ["a1", "jobs", "letters"], active: "jobs" };
  assert.deepEqual(changed(kept, AGENTS, false, null, open("a2")), { tabs: ["a1", "a2", "jobs", "letters"], active: "a2" });
  assert.deepEqual(changed({ tabs: ["jobs"] }, AGENTS, false, null, open("a2")), { tabs: ["a2", "jobs"], active: "a2" });
  assert.deepEqual(changed(kept, AGENTS, false, null, open("files")), { tabs: ["a1", "jobs", "letters", "files"], active: "files" });
  assert.deepEqual(changed(kept, AGENTS, false, null, open("subchats")), { tabs: ["a1", "jobs", "letters", "subchats"], active: "subchats" });
  // One open already: brought to the front where it is.
  assert.deepEqual(changed(kept, AGENTS, false, null, open("letters")), { tabs: ["a1", "jobs", "letters"], active: "letters" });
  // Agents not known (a new chat's): last.
  assert.deepEqual(changed({ tabs: ["files"] }, [], false, null, open("a2")), { tabs: ["files", "a2"], active: "a2" });
  assert.deepEqual(changed(undefined, [], false, null, open("files")), { tabs: ["files"], active: "files" });
  // What it shows is what it goes from: a tab it does not have is not kept on.
  assert.deepEqual(changed({ tabs: ["gone", "a1"] }, AGENTS, false, null, open("jobs")), { tabs: ["a1", "jobs"], active: "jobs" });
});

test("closing_one_activates_right_neighbor_else_left_and_clearing_records_history", () => {
  const kept = { tabs: ["a1", "a2", "jobs"], active: "a2" };
  // Middle active closed -> right neighbor ("jobs")
  assert.deepEqual(changed(kept, AGENTS, false, null, close("a2")), { tabs: ["a1", "jobs"], active: "jobs", closed: [{ tabs: ["a2"], at: 1, active: "a2" }] });
  // Non-active closed -> active stays
  assert.deepEqual(changed(kept, AGENTS, false, null, close("a1")), { tabs: ["a2", "jobs"], active: "a2", closed: [{ tabs: ["a1"], at: 0 }] });
  // First active closed (implicit active = first) -> right neighbor ("a2"), not last ("jobs")
  assert.deepEqual(changed({ tabs: ["a1", "a2", "jobs"] }, AGENTS, false, null, close("a1")), { tabs: ["a2", "jobs"], active: "a2", closed: [{ tabs: ["a1"], at: 0, active: "a1" }] });
  // Last active closed -> left neighbor ("a2")
  assert.deepEqual(changed({ tabs: ["a1", "a2", "jobs"], active: "jobs" }, AGENTS, false, null, close("jobs")), { tabs: ["a1", "a2"], active: "a2", closed: [{ tabs: ["jobs"], at: 2, active: "jobs" }] });
  // Only tab closed -> empty, no active
  assert.deepEqual(changed({ tabs: ["jobs"], active: "jobs" }, AGENTS, false, null, close("jobs")), { tabs: [], closed: [{ tabs: ["jobs"], at: 0, active: "jobs" }] });
  assert.equal(changed(kept, AGENTS, false, null, close("letters")), null, "one not open: nothing");
  assert.deepEqual(changed(kept, AGENTS, false, null, { action: "front", tab: "jobs", auto: true }), { tabs: ["a1", "a2", "jobs"], active: "jobs" });
  assert.deepEqual(changed(kept, AGENTS, false, null, { action: "clear", tab: null, auto: true }), { tabs: [], active: "a2", closed: [{ tabs: ["a1", "a2", "jobs"], at: 0, active: "a2" }] });
});

test("close_others_close_right_move_and_reopen", () => {
  const kept = { tabs: ["a1", "a2", "jobs", "files"], active: "jobs" };
  // closeOthers
  const afterOthers = changed(kept, AGENTS, false, null, { action: "closeOthers", tab: "a2", auto: true });
  assert.deepEqual(afterOthers, { tabs: ["a2"], active: "a2", closed: [{ tabs: ["a1", "jobs", "files"], at: 0, active: "jobs" }] });
  assert.equal(changed({ tabs: ["a2"], active: "a2" }, AGENTS, false, null, { action: "closeOthers", tab: "a2", auto: true }), null);
  assert.equal(changed(kept, AGENTS, false, null, { action: "closeOthers", tab: "letters", auto: true }), null);

  // closeRight when active is among closed tabs -> activates target tab
  const afterRight = changed(kept, AGENTS, false, null, { action: "closeRight", tab: "a2", auto: true });
  assert.deepEqual(afterRight, { tabs: ["a1", "a2"], active: "a2", closed: [{ tabs: ["jobs", "files"], at: 2, active: "jobs" }] });
  // closeRight when active is left of target -> keeps active
  const afterRightKeep = changed({ tabs: ["a1", "a2", "jobs", "files"], active: "a1" }, AGENTS, false, null, { action: "closeRight", tab: "a2", auto: true });
  assert.deepEqual(afterRightKeep, { tabs: ["a1", "a2"], active: "a1", closed: [{ tabs: ["jobs", "files"], at: 2 }] });
  // closeRight on rightmost tab -> null
  assert.equal(changed(kept, AGENTS, false, null, { action: "closeRight", tab: "files", auto: true }), null);

  // move
  assert.deepEqual(changed(kept, AGENTS, false, null, { action: "move", tab: "a1", to: 2, auto: true }), { tabs: ["a2", "jobs", "a1", "files"], active: "jobs" });
  assert.deepEqual(changed(kept, AGENTS, false, null, { action: "move", tab: "files", to: 0, auto: true }), { tabs: ["files", "a1", "a2", "jobs"], active: "jobs" });
  assert.deepEqual(changed(kept, AGENTS, false, null, { action: "move", tab: "a1", to: 99, auto: true }), { tabs: ["a2", "jobs", "files", "a1"], active: "jobs" });
  assert.equal(changed(kept, AGENTS, false, null, { action: "move", tab: "a2", to: 1, auto: true }), null);
  assert.equal(changed(kept, AGENTS, false, null, { action: "move", tab: "letters", to: 0, auto: true }), null);

  // reopen single, batch, clear, and canReopen
  assert.equal(tabsOf(kept, AGENTS, false, null).canReopen, undefined);
  assert.equal(tabsOf(afterRight, AGENTS, false, null).canReopen, true);
  const reopenedRight = changed(afterRight, AGENTS, false, null, { action: "reopen", tab: null, auto: true });
  assert.deepEqual(reopenedRight, { tabs: ["a1", "a2", "jobs", "files"], active: "jobs" });
  assert.equal(tabsOf(reopenedRight, AGENTS, false, null).canReopen, undefined);

  // clear then reopen restores all tabs and previous active
  const cleared = changed(kept, AGENTS, false, null, { action: "clear", tab: null, auto: true });
  assert.equal(tabsOf(cleared, AGENTS, false, null).canReopen, true);
  assert.deepEqual(changed(cleared, AGENTS, false, null, { action: "reopen", tab: null, auto: true }), { tabs: ["a1", "a2", "jobs", "files"], active: "jobs" });

  // reopen skips batches whose tabs are no longer known or already open
  const withStale = {
    tabs: ["a1"],
    active: "a1",
    closed: [
      { tabs: ["jobs"], at: 1, active: "jobs" },
      { tabs: ["gone", "a1"], at: 1, active: "gone" },
    ],
  };
  assert.equal(tabsOf(withStale, AGENTS, false, null).canReopen, true);
  assert.deepEqual(changed(withStale, AGENTS, false, null, { action: "reopen", tab: null, auto: true }), { tabs: ["a1", "jobs"], active: "jobs" });
  assert.equal(tabsOf({ tabs: ["a1"], active: "a1", closed: [{ tabs: ["gone"], at: 0 }] }, AGENTS, false, null).canReopen, undefined);
  assert.equal(changed({ tabs: ["a1"], active: "a1", closed: [{ tabs: ["gone"], at: 0 }] }, AGENTS, false, null, { action: "reopen", tab: null, auto: true }), null);

  // closed history cap at 8
  let cur: J = { tabs: ["a1", "a2", "jobs", "files", "letters", "things", FILE, SCREEN, TERMINAL], active: "a1" };
  for (const t of ["a1", "a2", "jobs", "files", "letters", "things", FILE, SCREEN, TERMINAL]) {
    cur = changed(cur, AGENTS, false, null, close(t));
  }
  assert.equal(cur.closed.length, 8);
  assert.deepEqual(cur.closed[0].tabs, ["a2"]);
  assert.deepEqual(cur.closed[7].tabs, [TERMINAL]);
});

test("a_tab_replaced_takes_the_place_of_the_one_it_replaces_in_front", () => {
  const pic = (n: number) => `view:${JSON.stringify(["chat", "ws/st", "a1", `/out/${n}.png`, `${n}.png`, 100])}`;
  const [p1, p2, p9] = [pic(1), pic(2), pic(9)];
  const kept = { tabs: ["a1", p1, "jobs"], active: p1 };
  const replace = (was: string, tab: string): Change => ({ action: "replace", tab, was, auto: true });
  assert.deepEqual(changed(kept, AGENTS, false, null, replace(p1, p2)), { tabs: ["a1", p2, "jobs"], active: p2 });
  // The one it replaces not open: opened as any is.
  assert.deepEqual(changed(kept, AGENTS, false, null, replace(p9, p2)), { tabs: ["a1", p1, "jobs", p2], active: p2 });
  // Open already: the one it replaces closed, it brought to the front where it is.
  assert.deepEqual(changed({ tabs: [p1, "jobs", p2], active: p1 }, AGENTS, false, null, replace(p1, p2)), { tabs: ["jobs", p2], active: p2 });
  assert.deepEqual(parseCall("chat.tabs.replace", { chat: "ws/st:k1", tab: p2, was: p1 }), { kind: "chatTabs", chat: "ws/st:k1", action: "replace", tab: p2, was: p1, auto: true });
  assert.throws(() => parseCall("chat.tabs.replace", { chat: "ws/st:k1", tab: p2 }));
});

test("the_history_a_chat_opens_by_itself_is_gone_from_where_a_client_shows_none", () => {
  // Shown (a wide page): what is opened joins it.
  assert.deepEqual(changed(undefined, AGENTS, true, "a1", open("jobs")), { tabs: ["a1", "jobs"], active: "jobs" });
  assert.deepEqual(changed(undefined, AGENTS, true, "a1", close("a1")), { tabs: [], closed: [{ tabs: ["a1"], at: 0, active: "a1" }] });
  // Not shown (the panel would lie over the chat): from none.
  assert.deepEqual(changed(undefined, AGENTS, true, "a1", { action: "open", tab: "jobs", auto: false }), { tabs: ["jobs"], active: "jobs" });
  assert.equal(changed(undefined, AGENTS, true, "a1", { action: "close", tab: "a1", auto: false }), null);
});

test("the_calls_read_the_chat_and_the_tab", () => {
  assert.deepEqual(parseCall("chat.tabs.open", { chat: "ws/st:k1", tab: "jobs" }), { kind: "chatTabs", chat: "ws/st:k1", action: "open", tab: "jobs", auto: true });
  assert.deepEqual(parseCall("chat.tabs.close", { chat: "ws/st:k1", tab: "jobs", auto: false }), { kind: "chatTabs", chat: "ws/st:k1", action: "close", tab: "jobs", auto: false });
  assert.deepEqual(parseCall("chat.tabs.closeOthers", { chat: "ws/st:k1", tab: "jobs" }), { kind: "chatTabs", chat: "ws/st:k1", action: "closeOthers", tab: "jobs", auto: true });
  assert.deepEqual(parseCall("chat.tabs.closeRight", { chat: "ws/st:k1", tab: "jobs" }), { kind: "chatTabs", chat: "ws/st:k1", action: "closeRight", tab: "jobs", auto: true });
  assert.deepEqual(parseCall("chat.tabs.move", { chat: "ws/st:k1", tab: "jobs", to: 2 }), { kind: "chatTabs", chat: "ws/st:k1", action: "move", tab: "jobs", auto: true, to: 2 });
  assert.deepEqual(parseCall("chat.tabs.reopen", { chat: "ws/st:k1" }), { kind: "chatTabs", chat: "ws/st:k1", action: "reopen", tab: null, auto: true });
  assert.deepEqual(parseCall("chat.tabs.clear", { chat: "new:ws" }), { kind: "chatTabs", chat: "new:ws", action: "clear", tab: null, auto: true });
  assert.throws(() => parseCall("chat.tabs.front", { chat: "ws/st:k1" }));
  assert.throws(() => parseCall("chat.tabs.move", { chat: "ws/st:k1", tab: "jobs" }));
  assert.throws(() => parseCall("chat.tabs.open", { chat: "", tab: "jobs" }));
});

test("a_chats_view_says_its_tabs_as_the_calls_change_them", async () => {
  const { host, core } = await started();
  const ui = core.connect();
  subscribe(core, ui, 1, { topic: "chat", station: "ws/st", thread: 7 });
  subscribe(core, ui, 2, { topic: "prefs" });
  await host.settle();
  await host.settle();
  const values = new Map();
  apply(host, values);
  assert.deepEqual(v(values, 1).agents.map((a: J) => a.session.key), ["k1"]);
  assert.deepEqual(v(values, 1).tabs, { open: [] });
  call(core, ui, 3, "chat.tabs.open", { chat: "ws/st:7", tab: "jobs" });
  await host.settle();
  call(core, ui, 4, "chat.tabs.open", { chat: "ws/st:7", tab: "k1" });
  await host.settle();
  apply(host, values);
  assert.deepEqual(v(values, 1).tabs, { open: ["k1", "jobs"], shown: "k1" });
  assert.deepEqual([v(values, 2).chatTabs["ws/st:7"].tabs, v(values, 2).chatTabs["ws/st:7"].active], [["k1", "jobs"], "k1"]);
  call(core, ui, 5, "chat.tabs.close", { chat: "ws/st:7", tab: "k1" });
  await host.settle();
  apply(host, values);
  assert.deepEqual(v(values, 1).tabs, { open: ["jobs"], shown: "jobs", canReopen: true });
  // A workspace's new chat's (no chat to go by): kept all the same.
  call(core, ui, 6, "chat.tabs.open", { chat: "new:ws", tab: "files" });
  await host.settle();
  call(core, ui, 7, "chat.tabs.close", { chat: "new:ws", tab: "files" });
  await host.settle();
  apply(host, values);
  assert.deepEqual(v(values, 2).chatTabs["new:ws"].tabs, []);
  core.close();
});

test("a_file_in_the_viewer_is_kept_while_the_agents_are_known_opened_last_and_closed", () => {
  const md = `view:${JSON.stringify(["chat", "ws/st", "a1", "uploads/a/说明.md", "说明.md", 500])}`;
  const named = `view:${JSON.stringify(["named", "ws/st", "a1", "src/a.ts", "a.ts", 0])}`;
  const drive = `view:${JSON.stringify(["drive", "ws/st", "/home/me", "docs/x.png", "x.png", 1200, 1731000000000])}`;
  const bad = [
    'view:["chat","ws/st","a1","p.md","p.md"]',
    'view:["drive","ws/st","/r","p.png","p.png",1]',
    'view:["other","ws/st","a1","p.md","p.md",1]',
    'view:["chat","","a1","p.md","p.md",1]',
    'view:["chat","ws/st","a1","","p.md",1]',
    'view:["chat","ws/st","a1","p.md","p.md","1"]',
    "view:[",
  ];
  // Kept while the agents are known; a key that does not read is not.
  const kept = { tabs: ["a1", md, named, drive, ...bad], active: named };
  assert.deepEqual(tabsOf(kept, AGENTS, false, null), { open: ["a1", md, named, drive], shown: named });
  // Opened: last, in front; again: brought to the front where it is, never twice.
  assert.deepEqual(changed({ tabs: ["a1", "jobs"], active: "a1" }, AGENTS, false, null, open(md)), { tabs: ["a1", "jobs", md], active: md });
  assert.deepEqual(changed({ tabs: ["a1", md, "jobs"], active: "jobs" }, AGENTS, false, null, open(md)), { tabs: ["a1", md, "jobs"], active: md });
  // Closed in front: the right neighbor comes to the front.
  assert.deepEqual(changed({ tabs: ["a1", md, "jobs"], active: md }, AGENTS, false, null, close(md)), { tabs: ["a1", "jobs"], active: "jobs", closed: [{ tabs: [md], at: 1, active: md }] });
});

test("station_destinations_survive_reload_and_reopening_focuses_the_existing_tab", () => {
  const drive = 'drive:["ws/st1"]';
  const other = 'drive:["ws/st2"]';
  const station = 'station:["ws/st1"]';
  const screen = 'screen:["ws/st1","desktop"]';
  const adb = 'adb:["ws/st1"]';
  const kept = { tabs: [drive, other, station, screen, adb], active: screen };
  assert.deepEqual(tabsOf(kept, AGENTS, false, null), { open: kept.tabs, shown: screen });
  assert.deepEqual(changed(kept, AGENTS, false, null, open(drive)), { tabs: kept.tabs, active: drive });
  assert.deepEqual(tabsOf({ tabs: ['drive:[]', 'station:[""]', 'adb:[]', 'drive:["ws/st1", "extra"]'] }, AGENTS, false, null), { open: [] });
});
