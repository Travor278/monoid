// A chat on the desktop (still.fail web/src/pages/ChatPage.tsx, ChatPage.css.ts; styles/sidebar.css.ts pageBar,
// conversation.css.ts pageBarTitle): its side panel beside it (panel.mbt), its bar over its messages: its title (while a
// new one goes, that one with a turning ring), its station's update, the station while no agent is in it, its people,
// its agents (each its history beside the chat, its card on hover); at its end 归档 while nothing is left in it, its
// services and jobs (a popover: jobs.mbt), 对话信息 (a popover), the panel's switch while the panel is closed; ⌘F's bar
// in place of those while it is open (find.mbt). Its messages are chat_list.mbt's, its composer composer.mbt's.

///|
/// What the chat's page keeps of its own (the rest is the core's): its info's popover open, its services' popover
/// open, archiving it asked to confirm (its key, "" none: one keeping watch; asked from its bar's node). All signals: opened or
/// closed from another island than the page's (an item of the system's bars chosen as the frame under the tape is
/// built, after the page was: rail_native.mbt), the page's is told and built again, not kept as it was till the hand
/// comes to it (an iPhone Duo's ⓘ, 2026-11-01: the popover only once a finger moved).
priv struct ChatOwn {
  info_open : @signals.Signal[Bool]
  jobs_open : @signals.Signal[Bool]
  subchats_open : @signals.Signal[Bool]
}

///|
// kept across runs: put back by chat_page_reset
let chat_own : ChatOwn = {
  info_open: @signals.signal(false, same=fn(a, b) { a == b }),
  jobs_open: @signals.signal(false, same=fn(a, b) { a == b }),
  subchats_open: @signals.signal(false, same=fn(a, b) { a == b }),
}

///|
fn chat_page_reset() -> Unit {
  chat_own.info_open.set(false)
  chat_own.jobs_open.set(false)
  chat_own.subchats_open.set(false)
  chat_pops.info = 0
  chat_pops.jobs = 0
  chat_pops.subchats = 0
  chat_jobs_wait.val = None
  side_front_wait.val = None
  side_under_chat.val = ""
  side_unseen.set("")
}

///|
/// A press waiting to open the chat's services' popover (jobs_pressed), while it waits.
// kept across runs: put back by chat_page_reset
let chat_jobs_wait : Ref[@sfbase.PressWait?] = Ref(None)

///|
/// The bar's summary of chat `r`'s services and jobs (whether it has any, none of them listed), which the bar holds,
/// where the page reads it so (MBUI_SWR_VIEWS); None else.
fn jobs_summary(src : Source, r : ChatRef) -> Json? {
  if (src.swr_views)() {
    src.topic("chatJobs", chat_jobs_summary_params(r)).get().value
  } else {
    None
  }
}

///|
/// The chat's services' popover opened or closed by a press (its button, its keys). Opened, where the page asks so
/// (MBUI_SWR_VIEWS), once what it lists is answered (sfbase's open_answered), the screen as it was meanwhile: never an
/// empty list said to be none nor one growing as it comes; at once where the bar's summary says it has none, saying
/// so; opened again, what was kept of it shows at once (@core.Client::show_kept). Pressed again while it waits, nothing
/// opens.
pub fn jobs_pressed(src : Source, r : ChatRef) -> Unit {
  match chat_jobs_wait.val {
    Some(w) if w.waiting() => {
      chat_jobs_wait.val = None
      w.give_up()
      return
    }
    _ => chat_jobs_wait.val = None
  }
  if !(src.swr_views)() || src.read_only || chat_own.jobs_open.untracked() {
    toggle_jobs_pop()
    return
  }
  // (none said in so many words: a summary saying nothing of it is no word that it has none)
  let none = match @signals.untracked(fn() { jobs_summary(src, r) }) {
    Some(Object(m)) => m.get("hasJobs") is Some(False)
    _ => false
  }
  let asks = if none { [] } else { [("chatJobs", chat_params(r))] }
  let w = @sfbase.open_answered(src, asks, fn() { chat_own.jobs_open.set(true) })
  if w.waiting() {
    chat_jobs_wait.val = Some(w)
  }
}

///|
/// The chat's services' popover opened or closed (its keys, ⌘K's 服务和后台任务).
pub fn toggle_jobs_pop() -> Unit {
  chat_own.jobs_open.set(!chat_own.jobs_open.untracked())
}

///|
pub fn open_jobs_pop() -> Unit {
  chat_own.jobs_open.set(true)
}

///|
/// Its info's popover open (a screen's fixture).
pub fn open_info_pop() -> Unit {
  chat_own.info_open.set(true)
}

///|
pub fn open_subchats_pop() -> Unit {
  chat_own.subchats_open.set(true)
}

///|
pub fn toggle_subchats_pop() -> Unit {
  chat_own.subchats_open.set(!chat_own.subchats_open.untracked())
}

///|
pub fn subchats_pop_open() -> Bool {
  chat_own.subchats_open.get()
}

///|
/// Whether its info's popover is open, and its services' (tests).
pub fn chat_pops_open() -> (Bool, Bool) {
  (chat_own.info_open.get(), chat_own.jobs_open.get())
}

///|
/// ⌘F's bar opened in chat `r`: what opens under the bar closed.
pub fn chat_find_open(r : ChatRef) -> Unit {
  chat_own.info_open.set(false)
  chat_own.jobs_open.set(false)
  chat_own.subchats_open.set(false)
  find_open(chat_key(r))
}

///|
/// ⌘⇧H: an agent's history in front, the panel closed; else the first agent's open, or the first agent's opened.
fn history_toggle(src : Source, r : ChatRef, v : ChatView) -> Unit {
  let (tabs, front) = side_of(v)
  let agent = fn(t : String) { v.agents.iter().any(fn(a) { a.key == t }) }
  if agent(front) {
    side_change(src, r, "clear", None)
  } else {
    side_change(src, r, "open", Some(tabs.iter().find_first(agent).unwrap_or(v.agents[0].key)))
  }
}

///|
/// Whether one of the chat's agents is at work (or waiting to be): what ⌘. stops.
fn agents_working(v : ChatView) -> Bool {
  v.agents.iter().any(fn(a) { a.status == "running" || a.status == "queued" })
}

///|
/// ⌘.: the chat's agents at work stopped.
fn stop_agents(src : Source, r : ChatRef, v : ChatView) -> Unit {
  for a in v.agents {
    if a.status == "running" || a.status == "queued" {
      act(
        src,
        @sf.t("web-pages.chat.stop"),
        "",
        "session.stop",
        { "station": Json::string(r.station), "key": Json::string(a.key) },
        done=@sf.t("web-pages.chat.stopAsked"),
      )
    }
  }
}

///|
/// Into the archive, asked first where the chat keeps watch (in the core's words).
fn archive_asked(src : Source, w : Workspace, r : ChatRef, v : ChatView, chat : Json?) -> Unit {
  if field(chat, "watch") is Some(Object(_)) {
    @sf.confirm(
      @sf.t("web-pages.chat.archiveConfirm", args=[("title", v.title)]),
      text(field(chat, "watch"), "ask"),
      @sf.t("web-pages.chat.archive"),
      fn() { archive(src, w, r, v) },
      danger=true,
    )
  } else {
    archive(src, w, r, v)
  }
}

///|
/// The chat into the archive: on to the chat below it in the list (or above, at the end), so
/// the keys go on working, the list if none; said at once, or why not.
fn archive(src : Source, w : Workspace, r : ChatRef, v : ChatView) -> Unit {
  let here = fn() {
    match app.nav.top() {
      Chat(t) => t.station == r.station && t.session == r.session
      _ => false
    }
  }
  neighbour(src, w, 1)
  if here() {
    neighbour(src, w, -1)
  }
  if here() {
    @sfbase.close_page(Chat(r)) |> ignore
    wide.landed.set("")
  }
  let p : Map[String, Json] = {
    "station": Json::string(r.station),
    "session": Json::string(r.session),
    "archived": Json::boolean(true),
  }
  match v.thread {
    Some(th) => p["thread"] = Json::number(th)
    None => ()
  }
  // said at once, by its title (the core's list has it gone); why not, when not
  toast_later(
    @sf.t("web-main.chat.archivedNamed", args=[("title", v.title)]),
    action=@sf.t("android-chat.archived.undo"),
    run=@sfbase.archive_undo(src, p),
  )
  (src.call)("chat.archive", Json::object(p), fn(res) {
    match res {
      Ok(_) => ()
      Err(e) => toast_later(@sf.t("web-pages.chat.archiveFailed", args=[("error", error_words(e))]))
    }
  })
}

///|
/// What chat_bar_hand hands where the chat's page is made as nodes (its messages'
/// chat_body_nodes), said at node `v`: as the page comes on top, and again as what the actions show changes while it
/// is (its view, its row, its services, ⌘F's bar in it, the column's room), not each frame; the actions handed for
/// another page let go first, as a frame lets them go as the page on top changes (nav_page_for). What opens from them
/// beside the item chosen (bar_menu_from_node).
fn chat_bar_handed_node(v : @view.View, src : Source, r : ChatRef) -> Unit {
  let page : Page = Chat(r)
  v.reacts(fn() { chat_bar_said(src, r, app.nav.top() == page) }, fn(said) {
    guard said.0 else { return }
    @signals.untracked(fn() {
      guard @sfbase.workspace_in_view(src).0 is Some(w) else { return }
      nav_page_for(page)
      chat_bar_hand(src, w, r, @sfbase.chat_view_now(src, r), @sfbase.chat_head_json(src, r), fn(_) {
        bar_menu_from_node(v)
      })
    })
  })
}

///|
/// What chat_bar_hand reads of chat `r` (`top` its page on top), as a value: changed, what it hands changes. Its head
/// alone (sfbase's chat_view_now, chat_head_json): a word streamed into a message reads none of it again.
fn chat_bar_said(
  src : Source,
  r : ChatRef,
  top : Bool,
) -> (Bool, (Bool, Bool, Bool), (String, Double?, Bool, Bool, Bool, String, String, Int, String)?, (Json?, Json?, Json?)) {
  let whole = @sfbase.chat_whole_held(src, r)
  let view = @sfbase.chat_view_now(src, r)
  let chat = @sfbase.chat_head_json(src, r)
  let jobs = src.topic("chatJobs", chat_jobs_summary_params(r)).get().value
  (
    top,
    (@sf.native_on(), column_short.get(), find_chat() == chat_key(r)),
    view.map(fn(v) {
      (
        v.title,
        v.thread,
        v.archivable,
        v.archived,
        v.offline,
        v.agents.map(fn(a) { a.key }).join(" "),
        v.screens.map(fn(s) { s.id + (if s.agent { "*" } else { "" }) }).join(" "),
        @sfpages.led_subchats(v.opened).length(),
        @sfpages.opened_summary_tone(v.opened),
      )
    }),
    (chat, whole.value, jobs),
  )
}

///|
/// chat_bar_handed's, what opens from its "…" and its screens beside where `beside` says (given the page's own id's key
/// for it).
fn chat_bar_hand(
  src : Source,
  w : Workspace,
  r : ChatRef,
  v : ChatView?,
  chat : Json?,
  beside : (String) -> (@sf.Beside, @ui.Along),
) -> Unit {
  // (its "…" is its chat's whole row's: held while its page is open, asked as it opens, @sfpages.chat_menu_of)
  @sfbase.chat_whole_held(src, r) |> ignore
  match v {
    // (a chat's ⌘F bar in place of the buttons: nothing of them handed)
    Some(view) if find_chat() == chat_key(r) && view.thread is Some(_) => ()
    Some(view) => {
      let archivable = view.archivable && !view.archived
      let archive = fn() { archive_asked(src, w, r, view, chat) }
      let info = fn() { chat_own.info_open.set(!chat_own.info_open.untracked()) }
      let extra = @sfpages.chat_extra_items(src, r, chat)
      let more = fn() {
        let (from, along) = beside("chat-more")
        @sfpages.open_chat_menu(src, w.id, r, extra, from~, along~)
      }
      let rows = if @sf.native_on() {
        @sfpages.chat_menu_of(src, w.id, r, extra, share_from=fn() { beside("chat-more").0 })
      } else {
        []
      }
      let screens = view.screens
      let screen = if chat_has_remote(view) {
        Some(
          (
            fn() {
              let (from, along) = beside("chat-screen")
              chat_remote_open(src, r, view, from~, along~)
            },
            chat_screens_driven(screens),
          ),
        )
      } else {
        None
      }
      let jobs_view = src.topic("chatJobs", chat_jobs_summary_params(r)).get().value
      let jobs = if flag(jobs_view, "hasJobs") || items(jobs_view, "jobs").length() > 0 {
        Some((jobs_toggle, text(jobs_view, "alarm") != ""))
      } else {
        None
      }
      let subchats = if @sfpages.led_subchats(view.opened).length() > 0 {
        Some((toggle_subchats_pop, @sfpages.opened_summary_tone(view.opened) != ""))
      } else {
        None
      }
      // (the short column, no room in it for their own buttons: the first rows of its "…", a line under them; the
      // user, 2026-11-07: 右上角那两个按钮应该收到右侧边栏)
      let rows = if @sf.native_on() && column_short.get() {
        let firsts : Array[@sf.MenuItem?] = []
        match subchats {
          Some((act, _)) => firsts.push(Some(@sf.menu_item_of(@sf.t("web-pages.chat.subchats"), icon="spawned", act)))
          None => ()
        }
        match screen {
          Some((act, _)) => firsts.push(Some(@sf.menu_item_of(@sf.t("web-pages.chat.screen"), icon="monitor", act)))
          None => ()
        }
        match jobs {
          Some((act, _)) => firsts.push(Some(@sf.menu_item_of(@sf.t("web-pages.chat.services"), icon="web", act)))
          None => ()
        }
        if firsts.length() > 0 {
          firsts.push(None)
        }
        firsts + rows
      } else {
        rows
      }
      bar_chat(src, r, view.agents, info, rows, more, jobs, screen, subchats, if archivable { Some(archive) } else { None })
      |> ignore
    }
    // (not read yet: the actions of the chat before it kept in the system's bars till its own come)
    None => bar_chat_waiting() |> ignore
  }
}

///|
/// The chat's services' popover opened or closed by its button.
fn jobs_toggle() -> Unit {
  chat_own.jobs_open.set(!chat_own.jobs_open.untracked())
}

///|
/// Where the screens' button's dot stands (screen_driven_dot): in its top right corner concentric with the button's
/// (its 10 round: the dot's 5 and 5 in), as the corner rule has it.
// kept across runs: a value (no field of it changes)
let screen_driven_room : @ui.Style = @ui.css("w=S8 h=S8 pt=S1_25 pr=S1_25 align=AEnd")

///|
/// The screens' button's dot while an agent drives one: as the services' (jobs_alarm_room), in the tone of an agent at
/// work.
// kept across runs: a value (no field of it changes)
let screen_driven_dot : @ui.Style = @ui.css("w=S2_5 h=S2_5 radius=Full bg=Warn border=B2 border_color=Bg")

///|
/// How wide the info's popover and the services' are (jobsPanel).
let chat_info_w : Double = 320.0

///|
let jobs_pop_w : Double = 360.0

///|
let subchats_pop_w : Double = 340.0

///|
/// How many pull requests the info names itself (the rest: 全部 N 个).
let info_pulls_most : Int = 3

///|
// kept across runs: a value (no field of it changes)
let info_pull_words : @ui.Style = @ui.style(w=@sf.grow)

///|
// kept across runs: a value (no field of it changes)
let info_pull_title : @ui.TextStyle = @ui.text_style(size=Ui, color=Fg, wrap=false, w=Cut)

///|
/// A tool's words and what it says of it, at the line's two ends, 12 apart (one under the other where the line has
/// not the room).
// kept across runs: a value (no field of it changes)
let info_label_flow : @ui.Style = @ui.style(row=true, w=@sf.grow, gap=S3, align=ACenter, justify=JBetween)

///|
/// What is in it between its rooms at its ends (page_bar_room): its title's row and its buttons 16 apart.
// kept across runs: a value (no field of it changes)
let chat_bar_inner : @ui.Style = @ui.style(row=true, w=@sf.grow, h=Full, gap=S4, align=ACenter)

///|
/// Its title, its people and agents 10 apart, 8 in (pageBarTitle), 4 kept past its last for the reach of the badge at
/// an agent's corner (agent_mark.mbt: 3 past it); never narrower than what is left in it needs (Ctx::box keep), ⌘F's
/// field beside it giving way first, down to its least.
// kept across runs: a value (no field of it changes)
let chat_bar_title_row : @ui.Style = @ui.style(row=true, w=@sf.grow, pl=S2, pr=S1, gap=S2_5, align=ACenter)

///|
/// How far its title stands in from where its row starts (chat_bar_title_row's pl=S2).
let chat_bar_title_in : Double = 8.0

///|
// kept across runs: a value (no field of it changes)
let chat_title_room : @ui.Style = @ui.css("row")

///|
/// What leaves the bar's title row first, short of room: its people, then its agents but the
/// first (the last of them first).
let chat_bar_drop_people : Int = 1

///|
let chat_bar_drop_agents : Int = 2

///|
/// How wide the title may be: 42% of the bar, 80 at least.
let chat_title_least : Double = 80.0

///|
let chat_title_part : Double = 0.42

///|
/// A page's title in its bar (sidebar.css.ts pageBar h1: 14 in 600, on 20).
// kept across runs: a value (no field of it changes)
let chat_title_words : @ui.TextStyle = @ui.text_style(size=Title, weight=Semibold, color=Fg, leading=L6, wrap=false, w=Cut)

///|
/// The station's tag (chatStation): 1 by 7 in, a line round it, round as a pill, its dot, mark and name 4 apart, 12,
/// muted (the words' ink and the strong line on hover); 160 wide at most.
// kept across runs: a value (no field of it changes)
let chat_station_tag : @ui.Style = @ui.style(
  row=true,
  max_w=@sf.chat_station_most,
  py=SPx,
  px=@sf.chat_station_in,
  gap=S1,
  align=ACenter,
  radius=Full,
  border=B1,
  border_color=Line,
  clip=true,
)

///|
// kept across runs: a value (no field of it changes)
let chat_station_hot : @ui.Style = chat_station_tag.then(@ui.css("border_color=Border"))

///|
/// The tag's height (its words' 18 line, 1 over and under) and its dot's side (via_direct's S2): its dot in its round
/// end (chat_station).
let chat_station_h : Double = 20.0

///|
let via_dot_side : Double = 8.0

///|
/// How far in from the tag's edge its dot stands: concentric with its round end (@sf.capsule_in; the line round it is
/// drawn over its padding, not in it).
let chat_station_dot_in : Double = @ui.capsule_in(chat_station_h / 2.0, via_dot_side, room=chat_station_h / 2.0)

///|
// kept across runs: a value (no field of it changes)
let chat_station_words : @ui.TextStyle = @ui.text_style(size=Meta, color=Muted, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let chat_station_words_hot : @ui.TextStyle = @ui.text_style(size=Meta, color=Fg, wrap=false)

///|
/// A station's mark in the bar (12).
let chat_station_mark : Double = 12.0

///|
/// How a station is reached, a dot 7 across: green, amber, red, grey.
// kept across runs: a value (no field of it changes)
let via_direct : @ui.Style = @ui.css("w=S2 h=S2 radius=Full bg=Positive")

///|
// kept across runs: a value (no field of it changes)
let via_relay : @ui.Style = @ui.css("w=S2 h=S2 radius=Full bg=Warn")

///|
// kept across runs: a value (no field of it changes)
let via_offline : @ui.Style = @ui.css("w=S2 h=S2 radius=Full bg=Danger")

///|
// kept across runs: a value (no field of it changes)
let via_waiting : @ui.Style = @ui.css("w=S2 h=S2 radius=Full bg=Muted")

///|
/// The same on a tile's corner (cornerDot): 10 across, ringed 2 in the page's ground, 3 past its edges.
fn corner_dot_of(via : String) -> @ui.Style {
  match via {
    "direct" => corner_direct
    "relay" => corner_relay
    "offline" => corner_offline
    _ => corner_waiting
  }
}

///|
// kept across runs: a value (no field of it changes)
let corner_direct : @ui.Style = @ui.css("w=S2_5 h=S2_5 radius=Full bg=Positive border=B2 border_color=Bg")

///|
// kept across runs: a value (no field of it changes)
let corner_relay : @ui.Style = @ui.css("w=S2_5 h=S2_5 radius=Full bg=Warn border=B2 border_color=Bg")

///|
// kept across runs: a value (no field of it changes)
let corner_offline : @ui.Style = @ui.css("w=S2_5 h=S2_5 radius=Full bg=Danger border=B2 border_color=Bg")

///|
// kept across runs: a value (no field of it changes)
let corner_waiting : @ui.Style = @ui.css("w=S2_5 h=S2_5 radius=Full bg=Muted border=B2 border_color=Bg")

///|
/// People in a stack (peopleStack): each 16 across, each 4 over the one before; +n after them, 11 muted.
let person_side : Double = 16.0

///|
// kept across runs: a value (no field of it changes)
let people_letter : @ui.TextStyle = @ui.text_style(size=Caption, weight=Semibold, color=Fg, wrap=false, leading=L3)

///|
/// An agent's mark in the bar (agentMarkBtn), round 6; an accent ring 2 round it while its history shows (among
/// several); with its station one tile (agentStation): the maker's square (the pointer's ground on hover) and the
/// station's part (its mark, or its name 140 at most, in by .19 of the tile and 1), the dot on the tile's corner.
// kept across runs: a value (no field of it changes)
let agent_mark_btn : @ui.Style = @ui.css("radius=Md")

///|
// kept across runs: a value (no field of it changes)
let agent_mark_btn_on : @ui.Style = @ui.css("radius=Md border=B2 border_color=Accent")

///|
// kept across runs: a value (no field of it changes)
let agent_station : @ui.Style = @ui.css("row h=S5 radius=Md bg=Neutral")

///|
// kept across runs: a value (no field of it changes)
let agent_station_on : @ui.Style = agent_station.then(@ui.css("border=B2 border_color=Accent"))

///|
/// The tile's corner (radius=Md's, 6): the two parts' outer ends are round by it, where they meet square (ui.css.ts
/// agentMarkJoined: the hover's ground meets the other part at a straight edge, not a notch).
let agent_station_round : Double = 6.0

///|
let agent_station_seam : Double = 0.0

///|
// kept across runs: a value (no field of it changes)
let agent_station_agent : @ui.Style = @ui.style(
  w=S5,
  h=S5,
  // det-ok(corners-each): one tile of two parts; only its outer ends are round, where they meet square (the user, 2026-10-27)
  radius=Corners(
    agent_station_round, agent_station_seam, agent_station_seam, agent_station_round,
  ),
)

///|
// kept across runs: a value (no field of it changes)
let agent_station_agent_hot : @ui.Style = agent_station_agent.then(
  @ui.css("bg=Hover"),
)

///|
// kept across runs: a value (no field of it changes)
let agent_station_part : @ui.Style = @ui.style(
  row=true,
  h=S5,
  max_w=@sf.agent_station_most,
  px=@sf.agent_station_in,
  align=ACenter,
  // det-ok(corners-each): the tile's other part, square where it meets the agent's (agent_station_agent)
  radius=Corners(
    agent_station_seam, agent_station_round, agent_station_round, agent_station_seam,
  ),
  clip=true,
)

///|
// kept across runs: a value (no field of it changes)
let agent_station_part_hot : @ui.Style = agent_station_part.then(@ui.css("bg=Hover"))

///|
/// The agent's card in the tile's whole (with touch, held): as a card of its own holds it, 10 in from the panel's
/// padding (the hover's padded), the station's card under it at the padding, its rows there.
// kept across runs: a value (no field of it changes)
let tile_card_agent : @ui.Style = @ui.css("w=Full p=S2_5")

///|
/// The dot on the tile's bottom right corner, 3 past it.
// kept across runs: a value (no field of it changes)
let agent_station_dot_room : @ui.Style = @ui.css("w=Full h=Full align=AEnd justify=JEnd").then(@sf.oversize(3.0))

///|
/// The services' button's dot (jobsTrigger ::after): 7 across, 6 in from its top right, ringed 2 in the page's ground.
// kept across runs: a value (no field of it changes)
let jobs_alarm_room : @ui.Style = @ui.css("w=S8 h=S8 pt=S1 pr=S1 align=AEnd")

///|
// kept across runs: a value (no field of it changes)
let jobs_alarm_fail : @ui.Style = @ui.css("w=S2_5 h=S2_5 radius=Full bg=Danger border=B2 border_color=Bg")

///|
// kept across runs: a value (no field of it changes)
let jobs_alarm_restart : @ui.Style = @ui.css("w=S2_5 h=S2_5 radius=Full bg=Warn border=B2 border_color=Bg")

///|
/// The info's facts (detailRow): what it is muted in a 6em column, 12 apart; 13; at the panel's words' inset. A fact
/// 28 high and 6 apart, as far from the next as the rows under them are (32 and 2: pengxiao, 2026-10-25, the panel's
/// rows unevenly apart).
// kept across runs: a value (no field of it changes)
let info_facts : @ui.Style = @ui.css("w=Full px=S4 gap=S1_5")

///|
/// Its labels' column at least (the web's 80).
let info_label_w : Double = 80.0

///|
// kept across runs: a value (no field of it changes)
let info_words : @ui.TextStyle = @ui.text_style(size=Ui, color=Fg, wrap=false)

///|
/// A chat named in the info (the one whose agent made it) pointed at: its words in the accent.
// kept across runs: a value (no field of it changes)
let info_words_hot : @ui.TextStyle = @ui.text_style(size=Ui, color=AccentText, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let info_muted : @ui.TextStyle = @ui.text_style(size=Ui, color=Muted, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let info_quiet : @ui.TextStyle = @ui.text_style(size=Meta, color=Muted, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let info_end : @ui.TextStyle = @ui.text_style(size=Meta, color=Muted, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let info_inline : @ui.Style = @ui.css("row gap=S1_5 align=ACenter")

///|
/// Its agents (detailsList): 8 under the facts, each its mark and label over its line, 2 apart.
// kept across runs: a value (no field of it changes)
let info_agents : @ui.Style = @ui.css("w=Full px=S4 pt=S2 gap=S1_5")

///|
// kept across runs: a value (no field of it changes)
let info_agent : @ui.Style = @ui.css("w=Full gap=S0_5")

///|
/// An agent's mark and label: the mark where the rows' icons stand under it, its label where their words do (14 and
/// 10 apart: info_row), its line under its label (pengxiao, 2026-10-25: their edges out of line).
// kept across runs: a value (no field of it changes)
let info_agent_head : @ui.Style = @ui.css("row gap=S2_5 align=ACenter")

///|
/// (the mark as wide as the rows' icons' column, its line as far in as its label: info_agent_line)
let info_mark_side : Double = 14.0

///|
// kept across runs: a value (no field of it changes)
let info_agent_line : @ui.Style = @ui.css("w=Full pl=S6")

///|
/// A group of its rows (infoTools, PanelRow): 16 under what is over it, as far as sets the groups apart without a
/// line, its rows 2 apart; a row a small panel's (@sf.pick_high: in its foot corners concentric with them, as a menu's
/// item is), its icon's 14 column and words 10 apart, 10 in, round with the panel, the pointer's ground on it.
// kept across runs: a value (no field of it changes)
let info_tools_base : @ui.Style = @ui.css("w=Full pt=S4 gap=S0_5")

///|
/// (`last` in the panel: its last row, a capsule with keyboard and mouse, in the panel's foot corners as far in as
/// makes it concentric with them, @sf.pick_reach)
fn info_tools(last : Bool) -> @ui.Style {
  // (beside the system's tabs, a phone's room: the groups nearer, the user 2026-11-01, 收紧内容)
  let base = if @sf.native_on() { info_tools_near } else { info_tools_base }
  if last {
    base.then(@ui.style(mb=@sf.room_of(-@sf.menu_row_reach(@sf.theme().rows.pick))))
  } else {
    base
  }
}

///|
/// A group of its rows beside the system's tabs (info_tools): 4 under what is over it, its rows as tall as a finger's
/// keeping them apart enough.
// kept across runs: a value (no field of it changes)
let info_tools_near : @ui.Style = @ui.css("w=Full pt=S1 gap=S0_5")

///|
fn info_tool() -> @ui.Style {
  info_tool_base.then(@sf.pick_high()).then(@sf.pick_reach())
}

///|
// kept across runs: a value (no field of it changes)
let info_tool_base : @ui.Style = @ui.css("row w=Full px=S2_5 gap=S2_5 align=ACenter radius=Inner hovered{bg=Hover}")

///|
// kept across runs: a value (no field of it changes)
let info_tool_icon : @ui.Style = @ui.css("w=S3_5 align=ACenter")


///|
/// A chat's people each on a line of their own in its info (beside the system's tabs: chat_info).
// kept across runs: a value (no field of it changes)
let info_people_list : @ui.Style = @ui.css("gap=S1_5")

///|
/// The window's width as the chat's bar's popovers were last drawn (bar_popovers: a turn closes them).
let info_width : FixedArray[Double] = [0.0]
