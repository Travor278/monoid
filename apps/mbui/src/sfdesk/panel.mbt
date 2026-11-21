// Beside a chat on the desktop (still.fail web/src/pages/ChatPage.tsx's side panel, ChatSide.tsx useSidePanel, SidePane,
// FilesTab; ChatPage.css.ts sidePanel, sideBar, sideTab): the side panel at the pane's right, a tab each for what is
// opened in it (an agent's execution history, the chat's services and jobs, the stations' files, what its agents and
// other chats' wrote each other), the one in front shown; its edge drags its width (pressed, the panel closes), its
// switch closes it. It slides in and out as its first tab opens and its last closes. Which tabs are open and in front
// is the core's (the chat view's `tabs`), as are the changes (`chat.tabs.*`). Each chat keeps its own tabs.

///|
/// A chat's tabs' key as the core keeps them (the prefs' `chatTabs`: `<station>:<session>`, as its page names it).
fn tabs_key(r : ChatRef) -> String {
  r.station + ":" + r.session
}

///|
/// Whether this panel shows `tab` beside a chat of `v`: one of its agents' histories (by its session's key), 任务, 文件,
/// agent 往来, a web service of its agents' (`service:<job>`), a visualization (`file:[…]`: service_tab.mbt), a file in
/// the viewer (`view:[…]`: sfbase's viewer_tab.mbt).
fn side_shows(v : ChatView, tab : String) -> Bool {
  tab == "jobs" ||
  @sfbase.view_tab_file(tab) is Some(_) ||
  tab == "files" ||
  tab == "letters" ||
  tab == "things" ||
  tab == "subchats" ||
  tab_service(tab) is Some(_) ||
  tab_file(tab) is Some(_) ||
  station_tab(tab) is Some(_) ||
  v.agents.iter().any(fn(a) { a.key == tab })
}

///|
/// The chat's side panel's tabs, in their order, and the one in front: the core's (the chat view's `tabs`: those kept
/// for it on this device that it has, ChatPage.tsx), of those this panel shows.
pub fn side_of(v : ChatView) -> (Array[String], String) {
  let tabs = v.tabs.open.filter(fn(t) { side_shows(v, t) })
  let front = match v.tabs.shown {
    Some(f) if tabs.contains(f) => f
    _ => tabs.get(0).unwrap_or("")
  }
  (tabs, front)
}

///|
/// Chat `r`'s tabs as its view has them now (its head alone: sfbase's chat_view_now, told as they change, not as a word
/// comes into a message).
pub fn side_now(src : Source, r : ChatRef) -> (Array[String], String) {
  match @sfbase.chat_view_now(src, r) {
    Some(v) => side_of(v)
    None => ([], "")
  }
}

///|
/// Chat `r`'s tabs changed by the core, which keeps them on this device: `tab` opened in front (an
/// agent's history after the histories open, any other last), closed (the last left in front, if it was), brought to
/// the front; all of them closed (`clear`). The panel is told first whether any will be open, to slide as they come.
pub fn side_change(src : Source, r : ChatRef, action : String, tab : String?) -> Unit {
  side_change_from(src, r, action, tab, side_now(src, r))
}

///|
/// File tab `tab` put beside chat `r` in the place of tab `was` (a picture's tab stepped to the one beside it: sfbase's
/// viewer_tab.mbt), in front; a tab of that file open there already (view_beside's same_file), that one brought to the
/// front, `was` closed; `was` over the whole window, the tab put there. The tab put in front.
pub fn view_step(src : Source, r : ChatRef, tab : String, was : String) -> String {
  let now = side_now(src, r)
  let open = match @sfbase.view_tab_file(tab) {
    Some(f) =>
      now.0
      .iter()
      .find_first(fn(t) {
        match @sfbase.view_tab_file(t) {
          Some(g) => f.same_file(g)
          None => false
        }
      })
    None => None
  }
  let put = open.unwrap_or(tab)
  let full = @signals.untracked(fn() { @sfbase.tab_full_is(r.station, r.session, was) })
  // (put there only to go over the whole window, as `was` was: lone, unless it was there already)
  let lone = full && open is None && @sfbase.tab_full_lone()
  side_changing(chat_key(r), now.0, now.1, true)
  tab_let_go(src, r, was)
  tab_kept(r, put)
  let params : Map[String, Json] = { "chat": Json::string(tabs_key(r)), "tab": Json::string(put), "was": Json::string(was) }
  (src.call)("chat.tabs.replace", Json::object(params), @sfbase.answer_unread)
  if full {
    @sfbase.tab_full_open(r, put, lone~)
  }
  put
}

///|
/// What waits for a tab pressed to the front (side_front_pressed): one at a time, given up as another is pressed.
// kept across runs: put back by chat_page_reset
let side_front_wait : Ref[@sfbase.PressWait?] = Ref(None)

///|
/// A tab of chat `r`'s panel pressed to the front: in front once what it shows first is answered (sfbase's
/// show_answered_wait), the panel as it was meanwhile, never emptied to be filled as the core answers; at once where it is
/// answered already (kept, or held by the panel). Pressed again, or another, while it waits: that one instead.
pub fn side_front_pressed(src : Source, r : ChatRef, tab : String) -> Unit {
  match side_front_wait.val {
    Some(w) => w.give_up()
    None => ()
  }
  side_front_wait.val = None
  // (what it asked handed to the tab as it is first built, its reads then the tab's own: side_tab_shown_at)
  let at = side_tab_shown_at(r, tab)
  let front = fn() { side_change(src, r, "front", Some(tab)) }
  // (an agent's history its transcript's place only while 详情 is unfolded: when folded, opening does not wait on a
  // station RPC for a hidden line)
  let w = if side_history_tab(tab) && @signals.untracked(fn() { !history_own.shut.get() }) {
    // (a replay of a run from before asks nothing ahead: shown at once, as history_side_open)
    let path = if !src.read_only && (src.switches_ahead)() { Some(wh_transcript(src, r.station, tab)) } else { None }
    let placed = fn() {
      match path {
        Some(p) => p.get() is Some(_)
        None => true
      }
    }
    @sfbase.show_answered_with(src, side_tab_reads(r, tab), placed, at, front)
  } else {
    @sfbase.show_answered_wait(src, side_tab_reads(r, tab), at, front)
  }
  if w.waiting() {
    side_front_wait.val = Some(w)
  }
}

///|
/// What tab `tab` of chat `r`'s panel is shown for, to what its press asked (hand_over_shown): taken as the tab is first
/// built (sfbase's shown_read, jobs_tab_node's).
pub fn side_tab_shown_at(r : ChatRef, tab : String) -> String {
  "side\u{1}" + chat_key(r) + "\u{1}" + tab
}

///|
/// What tab `tab` of chat `r`'s panel reads as it is first drawn, that its press waits for (side_front_pressed): 任务
/// its chat's services and jobs (jobs_tab_node's `chatJobs`); an agent's history its model's pick (its head's
/// model_triple_node) and its steps, with 详情 what they read where they are unfolded (wh_details_asks).
fn side_tab_reads(r : ChatRef, tab : String) -> Array[(String, Map[String, Json])] {
  match tab {
    "jobs" => [("chatJobs", chat_params(r))]
    _ if side_history_tab(tab) =>
      [
        ("pick", { "station": Json::string(r.station), "of": Json::string("session:" + tab) }),
        ..if @signals.untracked(fn() { !history_own.shut.get() }) {
          wh_details_asks(r.station, tab)
        } else {
          [@sfpages.history_ask(r.station, tab)]
        },
      ]
    _ => []
  }
}

///|
/// side_change, chat `r`'s tabs as they are now (side_now's) given, read by the caller where it holds them: what
/// changes them as a page comes on top (beside_follow) reads them in its reaction's read, held as long as that reads
/// them, not by the wide frame's node for as long as it lives (Source::owned_by's raw read: the chat held after it left).
fn side_change_from(src : Source, r : ChatRef, action : String, tab : String?, now : (Array[String], String)) -> Unit {
  let (tabs, front) = now
  let any = match action {
    "open" | "front" | "closeOthers" | "closeRight" | "reopen" => true
    "close" => tabs.iter().any(fn(t) { Some(t) != tab })
    _ => false
  }
  side_changing(chat_key(r), tabs, front, any)
  // a tab opened, brought to the front, or reopened beside the chat shown while its panel was open already: on the tape,
  // the panel brought over (none open yet: tape_settle's, once the core says it)
  if tabs.length() > 0 && (action == "open" || action == "front" || action == "reopen") {
    tape_bring_side(r)
  }
  // a web service's, visualization's, screen's or terminal's tab closed lets its session go
  match (action, tab) {
    ("close", Some(t)) => tab_let_go(src, r, t)
    ("closeOthers", Some(keep_t)) =>
      for t in tabs {
        if t != keep_t {
          tab_let_go(src, r, t)
        }
      }
    ("closeRight", Some(keep_t)) =>
      match tabs.search(keep_t) {
        Some(idx) =>
          for i = idx + 1; i < tabs.length(); i = i + 1 {
            tab_let_go(src, r, tabs[i])
          }
        None => ()
      }
    ("clear", _) => for t in tabs { tab_let_go(src, r, t) }
    ("open", Some(t)) => tab_kept(r, t)
    _ => ()
  }
  side_ask(src, r, action, tab)
}

///|
/// Reorder tab `tab` of chat `r`'s side panel to index `to`.
pub fn side_move(src : Source, r : ChatRef, tab : String, to : Int) -> Unit {
  let params : Map[String, Json] = {
    "chat": Json::string(tabs_key(r)),
    "tab": Json::string(tab),
    "to": Json::number(to.to_double()),
  }
  (src.call)("chat.tabs.move", Json::object(params), @sfbase.answer_unread)
}

///|
/// Reopen the most recently closed batch of tabs for chat `r`.
pub fn side_reopen(src : Source, r : ChatRef) -> Unit {
  side_change(src, r, "reopen", None)
}

///|
/// Step the active side-panel tab of chat `r` by `delta` (-1 previous, +1 next), wrapping around.
fn side_step(src : Source, r : ChatRef, delta : Int) -> Bool {
  let (tabs, front) = side_now(src, r)
  guard tabs.length() > 1 else { return false }
  let idx = tabs.search(front).unwrap_or(0)
  let next = tabs[(idx + delta + tabs.length()) % tabs.length()]
  side_change(src, r, "front", Some(next))
  true
}

///|
/// Close the currently active side-panel tab of chat `r` (`panel.tab.close`).
fn side_close_front(src : Source, r : ChatRef) -> Bool {
  let (tabs, front) = side_now(src, r)
  guard tabs.length() > 0 && front != "" else { return false }
  side_change(src, r, "close", Some(front))
  true
}

///|
/// Reopen the most recently closed tab batch of chat `r` if available (`panel.tab.reopen`).
fn side_reopen_key(src : Source, r : ChatRef) -> Bool {
  guard @sfbase.chat_view_now(src, r) is Some(cv) && cv.tabs.can_reopen else { return false }
  side_reopen(src, r)
  true
}

///|
/// The change asked of the core alone (changeTabs, `chat.tabs.*`), the panel told nothing: as a chat made from the new
/// chat's page starts with what it had beside it.
pub fn side_ask(src : Source, r : ChatRef, action : String, tab : String?) -> Unit {
  let params : Map[String, Json] = { "chat": Json::string(tabs_key(r)) }
  match tab {
    Some(t) => params["tab"] = Json::string(t)
    None => ()
  }
  (src.call)("chat.tabs." + action, Json::object(params), @sfbase.answer_unread)
}

///|
/// File tab `tab` opened beside chat `r` (the shell's `beside`: sfapp's beside_where), in front; a tab of that file open
/// there already (the same file, what it said of itself then aside: view_tab_file's same_file), that one brought to the
/// front, never a second: the tab put in front, and whether it is new there. `full`: to go over the whole window at
/// once, a new one put there under it with no slide of the panel (side_under).
pub fn view_beside(src : Source, r : ChatRef, tab : String, full? : Bool = false) -> (String, Bool) {
  // (that file in a window of its own: the window to the front, the panel left as it is: sfbase's tab_window_front)
  match @sfbase.tab_window_front(r, tab) {
    Some(there) => return (there, false)
    None => ()
  }
  let open = match @sfbase.view_tab_file(tab) {
    Some(f) =>
      side_now(src, r).0
      .iter()
      .find_first(fn(t) {
        match @sfbase.view_tab_file(t) {
          Some(g) => f.same_file(g)
          None => false
        }
      })
    None => None
  }
  let put = open.unwrap_or(tab)
  if full && open is None {
    side_under(src, r, "open", put)
  } else {
    side_change(src, r, "open", Some(put))
  }
  (put, open is None)
}

///|
/// Tab `tab` of chat `r` opened in its panel (`action` open) or closed there (close) while over the whole window, put
/// there only to go there (sfbase's tab_full.mbt, `lone`): the panel told nothing, so it is open or closed under it at
/// once, sliding neither way as the whole window's layer comes or goes.
pub fn side_under(src : Source, r : ChatRef, action : String, tab : String) -> Unit {
  match action {
    "open" => {
      side_under_chat.val = chat_key(r)
      // (nothing in the panel before: it stays closed under the whole window, the chat's column as wide as it was, till
      // the tab is put beside to stay or closed with the layer: side_unseen)
      if side_now(src, r).0.is_empty() {
        side_unseen.set(chat_key(r))
      }
      tab_kept(r, tab)
    }
    _ => {
      side_under_chat.val = ""
      tab_let_go(src, r, tab)
    }
  }
  side_ask(src, r, action, Some(tab))
}

///|
/// The chat whose panel holds a tab put there only to go over the whole window (side_under), till it is closed or put
/// beside to stay (side_put_beside): on the tape its panel not brought over as it opens (tape_settle), so nothing of
/// the tape moves under the whole window nor slides back as it closes.
// kept across runs: put back by chat_page_reset
let side_under_chat : Ref[String] = Ref("")

///|
/// The chat whose panel was opened, from none, only for a tab over the whole window (side_under): drawn closed, its
/// column none wide and the chat's as wide as with no panel, so nothing under the whole window moves as its layer comes
/// or goes; let go of once the panel has no tabs (closed with the layer: panel_node's side_panel_node) or the tab is put
/// beside to stay (side_put_beside: the panel slides in then).
// kept across runs: put back by chat_page_reset
let side_unseen : @signals.Signal[String] = @signals.signal("")

///|
/// Whether chat `key`'s panel is open as it is drawn: some tabs in it, not opened only for one over the whole window
/// (side_unseen).
fn side_drawn_open(src : Source, r : ChatRef, key : String) -> Bool {
  side_now(src, r).0.length() > 0 && side_unseen.get() != key
}

///|
/// The tab over the whole window put in its chat's panel to stay (its 移到侧边: sfbase's tab_full_beside), the panel
/// brought over on the tape.
fn side_put_beside(r : ChatRef) -> Unit {
  @sfbase.tab_full_beside()
  if side_under_chat.val == chat_key(r) {
    side_under_chat.val = ""
  }
  // (opened only for it: slid in now, as a change asked here)
  if side_unseen.untracked() == chat_key(r) {
    panel_own.asked.set(chat_key(r))
    side_unseen.set("")
  }
  tape_bring_side(r)
}

///|
/// An agent's history pressed (its mark in the bar or its activity row), or the chat's files (its info's 文件):
/// when already in front and visible, closed; on the tape with the panel off screen, brought into view; else opened
/// in front, whole (side_tab_open).
pub fn side_toggle(src : Source, r : ChatRef, tab : String) -> Unit {
  let (tabs, front) = side_now(src, r)
  if tabs.contains(tab) && front == tab {
    if !tape_bring_side_if_hidden(r) {
      side_change(src, r, "close", Some(tab))
    }
  } else {
    side_tab_open(src, r, tab)
  }
}

///|
/// Tab `tab` beside chat `r` opened in front by a press (its mark in the bar, the chat's info, its jobs' mark): once
/// what it first shows is answered, the panel as it was meanwhile, so it slides in whole: an agent's history its
/// transcript's place (history_side_open); where what opens waits for what it shows (gates_opens, MBUI_OPEN_WHOLE) the
/// others what they read as they are first drawn (side_tab_asks), through press_wait (sfbase's open_answered:
/// open_hold_ms at most, given up as the chat is left); one there already, brought to the front at once.
pub fn side_tab_open(src : Source, r : ChatRef, tab : String) -> Unit {
  // (in a window of its own: that window to the front instead, sfbase's tab_window_front)
  if @sfbase.tab_window_front(r, tab) is Some(_) {
    return
  }
  let open = fn() { side_change(src, r, "open", Some(tab)) }
  if side_history_tab(tab) {
    history_side_open(src, r, tab, open)
    return
  }
  let asks = if (src.gates_opens)() && !side_now(src, r).0.contains(tab) { side_tab_asks(src, r, tab) } else { [] }
  @sfbase.open_answered(src, asks, open, most=@sf.open_hold_ms) |> ignore
}

///|
/// What tab `tab` beside chat `r` reads of the core as it is first drawn, every one of it read whatever is answered:
/// 任务 its jobs whole (jobs_tab_node); Agent 往来 the chat's letters by its thread, as its view says it
/// (letters_tab_node); a web service its job (its tab's name, side_tab_names, and service_pane). 图片、文件和链接 read the
/// chat's page holds already; 文件's folder is its station's listing (drive_folder: held by the drive's own scope, asked
/// of the station, so a wait never holds for it).
fn side_tab_asks(src : Source, r : ChatRef, tab : String) -> Array[(String, Map[String, Json])] {
  match tab {
    "jobs" => [("chatJobs", @sfbase.chat_params(r))]
    "letters" =>
      match @signals.untracked(fn() { view_of_chat(src, r).0.bind(fn(v) { v.thread }) }) {
        Some(thread) => [("chatLetters", { "station": Json::string(r.station), "thread": Json::number(thread) })]
        None => []
      }
    _ =>
      match tab_service(tab) {
        Some(job) => [("job", { "station": Json::string(r.station), "id": Json::string(job) })]
        None => []
      }
  }
}

///|
/// How narrow and how wide the panel is dragged (PANEL_MAX).
let panel_min : Double = 320.0

///|
let panel_max : Double = 960.0

///|
/// How wide the panel is (else 38% of the page and at least 360), the
/// chat keeping 360 at least.
pub fn side_width(pane : Double) -> Double {
  let wanted = match panel_own.width.get() {
    Some(w) => w
    None => dmax(360.0, (pane * 0.38).floor())
  }
  dmax(0.0, dmin(wanted, pane - 360.0))
}

///|
/// The least the chat and the panel are side by side (ChatSide.tsx panelWidth: the chat 360, the panel 360 at least, the
/// rule between): on a page narrower, the panel over the page.
let side_both_least : Double = 721.0

///|
/// How wide the panel is over the page (ChatPage.css.ts sidePanel on a narrow page: min(460px, 100vw)).
let side_over_w : Double = 460.0

///|
/// The panel (sidePanel): its ground the canvas, beside the page with no line between: its edge's own line shows as
/// the pointer comes onto it (@sf.resize_handle; 2026-10-26 用户 of a hairline always there: 「搞坏了宽度调整的样式」).
// kept across runs: a value (no field of it changes)
pub let side_panel_style : @ui.Style = @ui.css("w=Full h=Full bg=Bg")

///|
/// Its bar (sideBar): 45 high, the tabs from 8 in, the panel's switch at its right 12 in (at the window's top right
/// corner, following it where the bar's buttons do: @sf.window_end_in).
pub fn side_bar() -> @ui.Style {
  side_bar_look.then(@ui.style(pr=@sf.room_of(@sf.window_end_in(side_bar_end))))
}

///|
// kept across runs: a value (no field of it changes)
let side_bar_look : @ui.Style = @ui.css("row w=Full h=S11 pl=S2 gap=S2 align=ACenter")

///|
/// Its bar as a panel of its own on the tape (laid out Medium, its corners @sf.pane_round): on the tape's one line, as
/// every bar of the tape is (@sf.tape_line: what it holds in its middle as far under the panel's top as a bar's round
/// buttons' middles, the page's beside it on the same), the first tab in its top left corner and the switch in its top
/// right each as far in as makes them concentric with the corner they are in (@sf.line_end_in); in one too square for
/// that (it follows a round window), clear of it, as in the wide frame at least (side_bar's 8 and 12); its foot as
/// before.
pub fn side_bar_tape() -> @ui.Style {
  match @sf.pane_round.val {
    Some(k) => side_bar_tape_in(k, @ui.corner_roots())
    None => side_bar()
  }
}

///|
/// side_bar_tape's, its panel's corners `corners` (worked out from `roots`; the tree's bar, side_bar_node, has the
/// window's corner and Windows' own window keys).
fn side_bar_tape_in(corners : FixedArray[@ui.CornerOf], roots : @ui.CornerRoots) -> @ui.Style {
  let left = corners[0].radius(roots)
  // (the switch the tallest in it, the row's top its, the tab's middle on its)
  let side = bar_button_side()
  @ui.style(
    row=true,
    w=Full,
    pt=@sf.room_of(@ui.capsule_in(@sf.tape_corner, side)),
    pb=S1_5,
    pl=@sf.room_of(@sf.line_end_in(left, side_bar_start, side=@sf.side_tab_side)),
    pr=@sf.room_of(@sf.tape_bar_end_of(corners, roots, side_bar_end, side~)),
    gap=S2,
    align=ACenter,
  )
}

///|
/// The tabs' room at the bar's start in the wide frame (side_bar: pl=S2).
let side_bar_start : Double = 8.0

///|
/// The switch's room at the bar's end in the wide frame (side_bar: pr=S3).
let side_bar_end : Double = 12.0

///|
/// Its tabs (sideTabList), 2 apart.
// kept across runs: a value (no field of it changes)
pub let side_tab_list : @ui.Style = @ui.style(row=true, w=@sf.grow, gap=S0_5, align=ACenter, clip=true)

///|
/// A tab (sideTabWrap, sideTab): 30 high, its mark (in a 14 room) and label 6 apart, its close 5 from its end, each in
/// the middle of its end, concentric with it (a service's dot too); a capsule (so in a panel's corner it stands where
/// its shape is concentric with it).
// kept across runs: a value (no field of it changes)
let side_tab_shape : @ui.Style = @ui.style(
  row=true,
  h=@sf.side_tab_h,
  pl=@sf.capsule_end_room(@sf.side_tab_side, side_tab_mark_side),
  pr=S1_25,
  gap=S1_5,
  align=ACenter,
  radius=Full,
)

///|
/// The one in front: the selected ground under it; pressed, it does nothing, so pointed at it stays as it is (its ×
/// lights over it).
// kept across runs: a value (no field of it changes)
pub let side_tab_in_front : @ui.Style = side_tab_shape.then(@ui.css("bg=Selected"))

///|
/// Its mark's room: an icon's, a maker's mark's, a service's dot in its middle.
let side_tab_mark_side : Double = 14.0

///|
// kept across runs: a value (no field of it changes)
let side_tab_mark : @ui.Style = @ui.css("w=S3_5 h=S3_5 align=ACenter justify=JCenter")

///|
/// Its label: muted, 13; the one in front in the words' colour and 500. Cut short where the tabs have not the room
/// (sideTab's min-width 0): a tab gives way, never runs past the bar.
// kept across runs: a value (no field of it changes)
pub let side_tab_words : @ui.TextStyle = @ui.text_style(size=Meta, color=Muted, wrap=false, w=Cut)

///|
/// One behind, pointed at: its words in the words' colour.
// kept across runs: a value (no field of it changes)
let side_tab_words_lit : @ui.TextStyle = side_tab_words.then(@ui.text_style(color=Fg))

///|
// kept across runs: a value (no field of it changes)
pub let side_tab_front : @ui.TextStyle = @ui.text_style(size=Meta, weight=Medium, color=Fg, wrap=false, w=Cut)

///|
/// Its close (sideTabClose): 20 round, concentric in the tab's end; pointed at, the pointer's ground over the tab's.
// kept across runs: a value (no field of it changes)
pub let side_tab_close : @ui.Style = @ui.css("w=S5 h=S5 radius=Full align=ACenter justify=JCenter hovered{bg=Hover}")

///|
/// What the tab in front shows, under the bar.
// kept across runs: a value (no field of it changes)
pub let side_pane : @ui.Style = @ui.css("w=Full h=Full clip")

///|
/// What the panel keeps of its own (its tabs are the core's): the width it was dragged to (None: its own), and its
/// slide (useSidePanel), for the page it is beside (a chat's, a workspace's new chat's): what it was last built as
/// (open or not), whether a change asked of the core here opens or closes it (`asked`: it slides then), and while it
/// slides out, what it showed (its tabs and the one in front); a chat's panel's column's way, by its page's key, set off
/// at the change that opens or closes it and read where it is drawn (side_panel_node).
priv struct PanelOwn {
  width : @signals.Signal[Double?]
  was : @sf.LiveMap[String, Bool]
  asked : @signals.Signal[String]
  leaving : @signals.Signal[(String, Array[String], String)?]
  goes : Map[String, @motion.Way]
}

///|
let panel_own : PanelOwn = {
  width: @signals.signal(None, same=fn(a, b) { a == b }),
  was: @sf.LiveMap::new(),
  asked: @signals.signal("", same=fn(a, b) { a == b }),
  leaving: @signals.signal(None, same=fn(a, b) { a == b }),
  goes: {},
}

///|
pub fn side_slide_reset() -> Unit {
  panel_own.width.set(None)
  panel_own.was.clear()
  panel_own.asked.set("")
  panel_own.leaving.set(None)
  panel_own.goes.clear()
  side_tab_menu_reset()
}

///|
/// A change of page `key`'s tabs asked of the core, from `tabs` (`front` in front), leaving `any` open (useSidePanel
/// changing): from none to some, the panel slides in once they come; from some to none, out, showing them as it goes.
pub fn side_changing(key : String, tabs : Array[String], front : String, any : Bool) -> Unit {
  let open = tabs.length() > 0
  if any {
    panel_own.leaving.set(None)
  }
  if open != any {
    panel_own.asked.set(key)
    if !any {
      panel_own.leaving.set(Some((key, tabs, front)))
    }
  } else {
    panel_own.asked.set("")
  }
}

///|
/// What page `key`'s panel shows while it slides out, its last tab closed: the tabs it had, the one in front.
fn side_leaving(key : String) -> (Array[String], String)? {
  match panel_own.leaving.get() {
    Some((k, tabs, front)) if k == key => Some((tabs, front))
    _ => None
  }
}

///|
/// Page `key`'s panel gone, as it was sliding out (its tabs shown no more).
fn side_left(key : String) -> Unit {
  if side_leaving(key) is Some(_) {
    panel_own.leaving.set(None)
  }
}

///|
/// Whose side panel is open (what the frame puts beside the page on the tape): a chat's, or workspace `ws`'s new
/// chat's (its Station 文件, kept by the same `chatTabs`, by `new:<ws>`).
#derive(Eq)
pub(all) enum SideOf {
  ChatSide(ChatRef)
  NewSide(String)
}

///|
/// The key its panel is kept by (chatTabs).
pub fn SideOf::key(self : SideOf) -> String {
  match self {
    ChatSide(r) => chat_key(r)
    NewSide(ws) => "new:" + ws
  }
}

///|
/// Whose side panel is open on page `p` in workspace `w`: a chat's (or an agent's history asked as a page: its
/// chat's), as its view has it; the new chat's, its 文件 open where the stations lend their files; None with none open.
pub fn side_open_for(src : Source, w : Workspace, p : Page) -> SideOf? {
  match p {
    Chat(r) | History(r, _, _) => if side_now(src, r).0.length() > 0 { Some(ChatSide(r)) } else { None }
    NewChat => if new_files_open(src, w.id) && new_drive_station(src, w) is Some(_) { Some(NewSide(w.id)) } else { None }
    _ => None
  }
}

///|
/// What a tab is called and how its close is said: an agent's by its label, a web service's by its name, a
/// visualization's by its file's name, 任务's, 文件's, agent 往来's by theirs.
fn side_tab_names(
  src : Source,
  r : ChatRef,
  v : ChatView?,
  tab : String,
  job_of? : (String) -> Json?,
) -> (String, String) {
  match station_tab_name(src, tab) {
    Some(label) => return (label, @sf.t("web-pages.chat.close", args=[("name", label)]))
    None => ()
  }
  // a file in the viewer: a `.mbui` / `.wasm` mini-program by its resolved app title, else by its file's name
  match @sfbase.view_tab_file(tab) {
    Some(f) => {
      let label = if @sfbase.is_mbui_viz(f.file.name) {
        @sfbase.tab_mbui_meta(src, tabs_key(r), tab, f, r.station).0
      } else {
        f.file.name
      }
      return (label, @sf.t("web-pages.chat.close", args=[("name", label)]))
    }
    None => ()
  }
  let agent = v.bind(fn(v) { v.agents.iter().find_first(fn(a) { a.key == tab }) })
  let service = match tab_service(tab) {
    Some(job) =>
      match job_of {
        Some(f) =>
          match f(job) {
            None | Some(Null) => Some(jobs_handed.get(service_key(r.station, job)))
            j => Some(j)
          }
        None => Some(job_now(src, r.station, job).0)
      }
    None => None
  }
  let file = tab_file(tab)
  let label = match (agent, service, file) {
    (Some(a), _, _) => a.who
    (_, Some(j), _) => if text(j, "name") == "" { svc("android-chat.preview.service") } else { text(j, "name") }
    (_, _, Some((_, _, name))) => name
    _ =>
      if tab == "jobs" {
        @sf.t("web-pages.chat.jobs")
      } else if tab == "files" {
        @sf.t("web-pages.chat.files")
      } else if tab == "things" {
        @sf.t("web-main.things.title")
      } else if tab == "subchats" {
        @sf.t("web-pages.chat.subchats")
      } else {
        @sf.t("web-main.letters.title")
      }
  }
  let closing = match (agent, service, file) {
    (Some(_), _, _) | (_, Some(_), _) | (_, _, Some(_)) => @sf.t("web-pages.chat.close", args=[("name", label)])
    _ =>
      if tab == "jobs" {
        @sf.t("web-pages.chat.closeJobs")
      } else if tab == "files" {
        @sf.t("web-pages.chat.closeFiles")
      } else if tab == "things" {
        @sf.t("web-main.things.close")
      } else if tab == "subchats" {
        @sf.t("web-pages.chat.close", args=[("name", label)])
      } else {
        @sf.t("web-main.letters.close")
      }
  }
  (label, closing)
}

///|
/// The title's row: grown into the bar, its mark over what the tab shows under it (16 more in), its name 8 after it.
// kept across runs: a value (no field of it changes)
let side_title_row : @ui.Style = @ui.style(w=@sf.grow).then(@ui.css("row pl=S4 gap=S2 align=ACenter"))

///|
/// The title's words: as the page's bar's title (chat_title_words).
// kept across runs: a value (no field of it changes)
let side_title_words : @ui.TextStyle = @ui.text_style(size=Body, weight=Semibold, color=Fg, leading=L6, wrap=false, w=Cut)

///|
/// A bar's icon button's side (@sf.icon_button, round: 32 on either hand, @sf.bar_key_side): a circle, so in a panel's
/// corner it stands where it is concentric.
fn bar_button_side() -> Double {
  @sf.bar_key_side
}
