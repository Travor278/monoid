// The page's panel on the tape (Medium) held by the window's tree: its ground, its corners the tape's and the line round
// it the tree's, a step darker while it is behind the one in use (tape_behind); in it the stack (@ui.nav_flat_view), each
// page a node of its own built the old way in it (its island), a phone's screen: what is opened from it pushed over it,
// slid in and taken off by back as a phone's are, down to the page chosen to be shown in it, as the frame drew it before.

///|
/// How far behind the one in use the page's panel is drawn by what reads it in node `n` (tape_behind's): its ground a
/// step darker that far, the page's own where it is in use.
fn tape_page_ground(n : @view.View) -> Int64 {
  tape_ground(tape_behind_at(Page, tape_drawn_at(n)))
}

///|
/// The page's panel (in node `v`, as tape_panel_box gives it room): the page on top switched as the stack is told it
/// (page_switch_said), a passage picked as it is picked (tape_pick_said); its ground, corners and line, cutting what is
/// in it to them; the stack in it, as wide as beside the system's column (`under` its ground alone).
fn tape_page_pane(v : @view.View, src : Source) -> Unit {
  // (its tips over all of the window, as the old frame's are: none cut by the panel)
  let tips = @sf.TipLayer::new(fn() { tape_goes.node })
  // (what is drawn in it cut to its room, as the island it was drawn by before was: the panel's ground and line too)
  v.clips(Is(true)) |> ignore
  // (the page on top switched, as the stack is told it: before any page of it is built; a passage picked while the page
  // is not in use, as it is picked: tape_pick_said)
  page_switch_said(v, fn() { @sfbase.workspace_in_view(src).0 is Some(_) })
  tape_pick_said(v, src)
  v.box(fn(panel) {
    panel
    .grow(Is(1.0))
    .clips(Is(true))
    // (out of the semantics tree while the tape's side is over it, as the old page's tape_behind was)
    .hides(By(fn() { wide.tape_at.get() != Page }))
    .ground(By(fn() { tape_page_ground(panel) }))
    .edge(By(fn() { (1.0, @sf.theme().p.line) }))
    .padding(By(fn() { (0.0, 0.0, if tape_shown_side() is None { tape_room_now().under } else { 0.0 }, 0.0) }))
    |> ignore
    // (its corners the tape's, those at the window's edge following the window's: linked each, as @sf.corners_radius)
    @ui.tree_corners_linked(panel, fn() { Some(tape_pane_corners(Page, tape_shown_side() is Some(_))) })
    @ui.nav_flat_view(
      panel,
      app.nav,
      fn(_c, _p) {  },
      fn(p) { (tape_goes.ready)(p) },
      tape_goes.most,
      bg=fn() { tape_page_ground(panel) },
      // (a page's bar on the tape the tree's, over its own view: what the page says of it)
      head=fn(b, k, made) {
        // (and Home / Remote workbench, which draw their own top bar)
        let own_bar = @signals.untracked(fn() {
          app.nav.page_of(k) is Some((p, _)) && (@sfbase.chat_page_is(p) || p is Home || p == Place("remote"))
        })
        tape_bar_head(b, k, made && !own_bar, tips)
      },
      // (a page of the library's made once in its place, where it is: its bar the tape's, from what the page is)
      made=fn(p) { tape_made(src, p, tips) },
      // (what its bar said kept till its entry leaves the stack: shown again (beside the one over it as that goes back),
      // its bar there with it before its page is built again)
      gone=fn(k) { tape_bars.remove(k) },
      // (back its while the page is in use: the side panel's, the sidebar's first)
      takes_back=fn() { wide.tape_at.get() == Page },
      // (a chat's page made as nodes left kept, taken back as it is opened again: sfbase's chat_page_left_key)
      keeps_left=@sfbase.chat_page_left_key,
      transition=@ui.NavTransition::layered(),
    )
    |> ignore
  })
  |> ignore
}

///|
/// A passage of a message picked while the page is not in use (held where it shows beside the sidebar), followed in
/// node `v`: the page comes over with it, its bar there to be pressed (pengxiao, 2026-10-25: 引用 pressed there went to
/// what showed of the page and brought it over, quoting nothing). As it is picked, once (@sfbase.picked: a new
/// identity; a chat's page made as nodes, its messages' words picked of the window's tree, @ui.picked_now: which
/// selection it is), never as it stays picked: a passage left picked keeps nothing from being brought over after
/// (pengxiao, 2026-10-25: the sidebar pressed or pulled over went straight back).
fn tape_pick_said(v : @view.View, src : Source) -> Unit {
  // (what is picked, as told, while a workspace is in view: none taken while none is, what is picked then taken as one
  // is again; of the tree's words, only what a message's are of)
  v.reacts(
    fn() {
      let made = match @ui.picked_now() {
        Some(p) if !p.of.is_empty() => Some(p.made)
        _ => None
      }
      (@sfbase.picked.get().serial, made, @sfbase.workspace_in_view(src).0 is Some(_))
    },
    fn(now) {
      let (serial, made, held) = now
      guard held else { return }
      let pick = match (serial, made) {
        (0, Some(m)) => "words \{m}"
        (0, None) => ""
        _ => serial.to_string()
      }
      if pick != "" &&
        pick != wide.tape_pick.get() &&
        wide.tape_at.get() != Page &&
        wide.tape_ask.get() is None &&
        wide.tape_pull.get() is None {
        wide.tape_ask.set(Some(Page))
      }
      wide.tape_pick.set(pick)
    },
  )
}

///|
/// The page's panel's corners as what is in it stands in them (pane_round): as wide as beside the column, its right
/// corners none of what is in it while a side panel is beside it.
fn tape_page_round() -> FixedArray[@ui.CornerOf] {
  let side = tape_shown_side()
  let under = if side is None { tape_room_now().under } else { 0.0 }
  beside_column(tape_pane_corners(Page, side is Some(_)), under)
}

///|
/// A page's bar on the tape as a page made once said of itself (tape_made); the node of the tree's that shows it reads it
/// (tape_bar_head).
priv struct TapeBar {
  said : @signals.Signal[PaneBarSaid?]
  back : () -> Unit
  /// what a page made once said of itself as it was last told (page_node's `said`), kept with its entry
  page_said : @signals.Signal[@sf.PageSaid?]
  /// what such a page does in its bar, as it gave it, how tall it stands there in a page laid out so, and which making
  /// of the page gave it (the bar's made again for each)
  page_actions : @signals.Signal[((@view.View) -> Unit, (@sf.Look) -> Double, Int)?]
}

///|
/// The makings of pages that give the tape's bar what they do, numbered.
// kept across runs: a count
let tape_actions_made : Ref[Int] = Ref(0)

///|
fn next_tape_actions_gen() -> Int {
  tape_actions_made.val += 1
  tape_actions_made.val
}

///|
/// Each page's bar on the tape, by its entry (its number): made as its page is first shown or built, let go as the entry
/// leaves the stack (nav_flat_view's `gone`), not as its node stops showing.
// kept across runs: emptied as a run begins (tape_goes_reset), each let go with its entry
let tape_bars : Map[Int, TapeBar] = Map([])

///|
/// The bar of entry `k`'s page, made as it is first asked.
fn tape_bar_of(k : Int) -> TapeBar {
  match tape_bars.get(k) {
    Some(b) => b
    None => {
      let b = {
        said: @signals.signal(None, same=fn(a, b) { a == b }),
        back: fn() {  },
        page_said: @signals.signal(None, same=fn(a, b) { a == b }),
        page_actions: @signals.signal_by(None, same=fn(a, b) {
          match (a, b) {
            (None, None) => true
            (Some(x), Some(y)) => x.2 == y.2
            _ => false
          }
        }),
      }
      tape_bars[k] = b
      b
    }
  }
}

///|
/// Over entry `k`'s page in the page's panel (node `b`): its bar, the tree's (pane_bar_node), as its page said it as it
/// was built; over one made once (`made`: tape_made) as it says of itself (tape_made_bar); none where an old view
/// said none or keeps its own (one with actions, built the old way with them); the panel's corners its ends', its
/// ground the panel's.
fn tape_bar_head(b : @view.View, k : Int, made : Bool, tips : @sf.TipLayer) -> Unit {
  let tb = tape_bar_of(k)
  // (a page made once: its bar there whatever it has said yet, from what it said of itself and where it was put on
  // from (its back); else as its old view said it. Where it was put on from as last said, kept while the stack is
  // told of a change before it is whole (an entry put in place and kept shown by its owner, told in either order))
  let under : Ref[Page?] = Ref(None)
  // (and whether it is a place of the rail's itself, kept so with it: no back over one, whatever is under it)
  let place = Ref(false)
  let said = fn() {
    if !made {
      return tb.said.get()
    }
    // (文件 and a station's drive: a bar of their own, none over them, but a folder laid out narrow, which names
    // itself to it)
    if app.nav.page_of(k) is Some((Files | Drive(_), _)) && tb.page_said.get() is None {
      return None
    }
    match app.nav.page_of(k) {
      Some((p, u)) => {
        under.val = u
        place.val = p is Place(_)
      }
      None => ()
    }
    Some(tape_made_bar(under.val, place.val, tb.page_said.get()))
  }
  b.show(fn() { said() is Some(_) }, fn(h) {
    pane_bar_node(
      h,
      said,
      fn() {
        if made {
          app.nav.pop() |> ignore
        } else {
          (tb.back)()
        }
      },
      fn() {
        let side = tape_shown_side()
        let under = if side is None { tape_room_now().under } else { 0.0 }
        beside_column(tape_pane_corners(Page, side is Some(_)), under)
      },
      fn() { tape_page_ground(h) },
      tips,
      // (the page's width, as its page is built in it: the stack's room in the panel)
      fn() { tape_page_at(tape_drawn_at(h)) },
      // (nothing of it read out while the panel is not in use, as the page under it: tape_behind)
      fn() { wide.tape_at.get() != Page },
      // (what a page made once does, at its end)
      actions=fn() { if made { tb.page_actions.get() } else { None } },
    )
    |> ignore
  })
}

///|
/// The pages of the library's made once as nodes in the page's panel, in the place of their old view (nav_flat_view's
/// `made`), by what each is: 关于, 记忆, 归档 and 自动决策, as the settings' list opens them; a station's own archiving, as 归档
/// opens it; 更新日志 as 关于 opens it; 一台 station 的记忆 as 记忆 opens it. Each laid out by the page's width (the stack's
/// in the panel at rest, as the tape lays it out now: page_node narrow or wide; narrow while that is not known); 关于,
/// 记忆 and 更新日志 a right click in them copying what is picked. Under the tape's bar (tape_bar_head, from
/// tape_made_bar): no title, no back of its own, nothing over it in its room.
fn tape_made(
  src : Source,
  page : Page,
  tips : @sf.TipLayer,
) -> (String, (@view.View, () -> Page, Page?, () -> Int, Int) -> Unit)? {
  // (as wide as the stack in the panel at rest, as the tape lays it out now: the page's width, 0 while not known)
  let width = fn() {
    let r = tape_room_now()
    r.main_to - (if tape_shown_side() is None { r.under } else { 0.0 })
  }
  // (made in the workspace in view, its settings' core; what it says of itself kept with its entry, `k`)
  let made = fn(
    kind : String,
    f : (
      @view.View,
      @settings.Core,
      () -> @settings.Here,
      () -> Int,
      (@sf.PageSaid) -> Unit,
      ((@view.View) -> Unit, (@sf.Look) -> Double) -> Unit,
    ) -> Unit,
  ) {
    Some(
      (
        kind,
        fn(v : @view.View, _page : () -> Page, _under : Page?, stint : () -> Int, k : Int) {
          let told = fn(s : @sf.PageSaid) { tape_bar_of(k).page_said.set(Some(s)) }
          v.switch_by(fn() { @sfbase.workspace_in_view(src).0.map(fn(w) { w.id }) }, fn(p, _id) {
            // (what the page made in `p` does in the bar, its own while `p` is: given as it is made, let go with `p`
            // where none since gave the bar another's)
            let last_gen = Ref(0)
            let acts = fn(make : (@view.View) -> Unit, side : (@sf.Look) -> Double) {
              let gen = next_tape_actions_gen()
              last_gen.val = gen
              tape_bar_of(k).page_actions.set(Some((make, side, gen)))
            }
            p.owns(fn() {
              let tb = tape_bar_of(k)
              if last_gen.val > 0 && tb.page_actions.untracked() is Some((_, _, g)) && g == last_gen.val {
                tb.page_actions.set(None)
              }
            })
            |> ignore
            match @signals.untracked(fn() { @sfbase.workspace_in_view(src).0 }) {
              Some(w) => {
                let core = settings_core(src, w)
                let here = fn() { @settings.here_of(core, w.id, w.name) }
                @settings.frame(core, @signals.untracked(here))
                // (a dialog a fixture's mode puts up over its page, before the page is made: setting_page's)
                settings_fixture(src, core)
                // (made in a panel of its own: lent to all it makes, however late, its cards the panel's: @sf.pane_lent)
                p.lends(@sf.pane_lent, true) |> ignore
                f(p, core, here, stint, told, acts)
              }
              None => ()
            }
          })
        },
      ),
    )
  }
  match page {
    // (Home: the board while it is chosen, else the panel's ground: board.mbt)
    Home => Some(board_tape_made(src, tips, width))
    // (laid out by the page's width, narrow or wide: page_node's)
    Setting(About) =>
      made("about", fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @sfpages.about_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    // (a web service whose chat the station has not said, or that it does not find: service_beside_node)
    // (no old view: made so whatever pane_makes says)
    Service(station, job) =>
      made("service/" + station + "/" + job, fn(p, _core, _here, _stint, _told, _acts) {
        service_beside_node(p, src, station, job)
      })
    // (已归档, none of its chats beside the side column's list of them: what it is)
    Archived => made("archived", fn(p, _core, _here, _stint, _told, _acts) { archive_main_node(p) })
    Setting(Archive) =>
      made("archive", fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.archive_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    Setting(Memories) =>
      made("memories", fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.memories_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(Changelog) =>
      made("changelog", fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @sfpages.changelog_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    // (the profiles' place: the profile picked in its list, made once as its page is, none to pick yet the first to add;
    // made in every case, as it has no old view)
    Place("profiles") =>
      made("place/profiles", fn(p, core, here, stint, told, _acts) {
        context_node(p)
        profiles_place_node(p, src, core, here, stint, fn() { tape_made_frame }, width, said=told, tips~)
      })
    // (the stations' place: the station picked in its list made once as its page is, none the first to add)
    Place("stations") =>
      made("place/stations", fn(p, core, here, stint, told, _acts) {
        context_node(p)
        stations_place_node(p, src, core, here, stint, fn() { tape_made_frame }, width, said=told, tips~)
      })
    Place("remote") =>
      Some(
        (
          "place/remote",
          fn(v, _page, _under, _stint, k) {
            v.switch_by(fn() { @sfbase.workspace_in_view(src).0.map(fn(w) { w.id }) }, fn(p, ws_id) {
              guard ws_id is Some(wid) else { return }
              context_node(p)
              p.lends(@sf.pane_lent, true) |> ignore
              @sfpages.remote_workbench_node(
                p,
                src,
                fn() { @sfbase.workspace_in_view(src).0.map_or(wid, fn(w) { w.id }) },
                tips,
                // (its tabs, ＋ among them, clear of the panel's top corners as the files' bar is (tape_bar_clear_start):
                // they stand wherever the room left puts them, so none of them can be concentric with a corner)
                start_pad=fn() { dmax(12.0, tape_remote_radii()[0]) },
                end_pad=fn() { dmax(12.0, tape_remote_radii()[1]) },
                // (a screen driven by a finger, its actions at its foot clear of the panel's foot corners: under the
                // round of the rounder of them, past what their row keeps under them)
                foot_pad=fn() {
                  if @sf.soft_keyboard() {
                    let r = tape_remote_radii()
                    dmax(0.0, dmax(r[2], r[3]) - tape_remote_foot_in)
                  } else {
                    0.0
                  }
                },
                width~,
                shown=pane_shows(k),
                keep_screen=fn(st, sc) {
                  side_screen_shown(src, st, sc) ||
                  (app.nav.top() is Screen(top) && top.station == st && top.screen == sc)
                },
              )
            })
          },
        ),
      )
    // (a place of the rail's whose page is one of those: that page as the settings open it, at the stack's root, made
    // under its own kind)
    Place(name) =>
      match @settings.route_of(name) {
        // (those whose old view is gone: every frame makes them once, as a page or a place)
        Some(r) if @settings.made_once(r) =>
          tape_made(src, Setting(r), tips).map(fn(m) { ("place/" + m.0, m.1) })
        _ => None
      }
    // (the settings come to beside their list: its first row's page, made once as that page is)
    Settings | Setting(Home) => tape_made(src, Setting(settings_landing), tips).map(fn(m) { ("settings/" + m.0, m.1) })
    // (by its station: another station's another page, not this one become it)
    Setting(Memory(address)) =>
      made("memory/" + address, fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.memory_node(p, core, here, address, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    Setting(Shortcuts) =>
      made("shortcuts", fn(p, core, _here, stint, told, _acts) {
        context_node(p)
        // (recording while it is the one on top of the stack: its stay there, stint's)
        @sfpages.shortcuts_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, active=fn() {
          app.nav.top_stay().1 == stint()
        }, said=told, width~)
      })
    Setting(Notifications) =>
      made("notifications", fn(p, core, here, stint, told, _acts) {
        context_node(p)
        @sfpages.notify_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, stint~, said=told, width~)
      })
    // (by its station, skill and the part first shown: another's another page)
    Setting(MemoryDoc(address, skill, at)) =>
      made("memory-doc/" + address + "/" + skill + "/" + at.to_string(), fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.memory_doc_node(p, core, here, address, skill, at, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(AutoPolicy(st)) =>
      made("auto-policy/" + st, fn(p, core, here, _stint, told, _acts) {
        @sfpages.policy_node(p, core, here, st, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(Appearance) =>
      made("appearance", fn(p, core, _here, _stint, told, _acts) {
        @sfpages.appearance_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(Experimental) =>
      made("experimental", fn(p, core, _here, _stint, told, _acts) {
        @sfpages.experimental_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    // the stations' list, the profiles' (by station: another station's another page) and an account's on several
    // stations (sfpages' stations_list.mbt, profiles_list.mbt), their ＋ in the bar; made in every case, as they have no
    // old view
    Setting(Stations) =>
      made("stations", fn(p, core, here, _stint, told, acts) {
        context_node(p)
        @sfpages.stations_list_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~, bar_actions=acts)
      })
    Setting(Profiles("")) =>
      made("profiles/", fn(p, core, here, _stint, told, acts) {
        context_node(p)
        @sfpages.profiles_page_node(
          p,
          src,
          core,
          here,
          @settings.profiles_narrow_overview,
          on_back=core.pop,
          frame=fn() { tape_made_frame },
          said=told,
          width~,
          tips~,
          bar_actions=acts,
        )
      })
    Setting(Profiles(only)) =>
      made("profiles/" + only, fn(p, core, here, _stint, told, acts) {
        context_node(p)
        @sfpages.profiles_list_node(p, core, here, only, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~, bar_actions=acts)
      })
    Setting(ProfileAccount(key)) =>
      made("profile-account/" + key, fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.profile_account_node(p, core, here, key, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // (by its station and id: another's another page; made in every case, as it has no old view)
    Setting(Profile(address, id)) =>
      made("profile/" + address + "/" + id, fn(p, core, here, stint, told, _acts) {
        context_node(p)
        @sfpages.profile_node(p, core, here, address, id, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~, stint~)
      })
    Setting(NewProfile(address)) =>
      made("new-profile/" + address, fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.new_profile_node(p, core, src, here, address, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    Setting(LocalStation) =>
      made("local-station", fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @sfpages.local_station_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    // (by its station: another station's another page, not this one become it)
    Setting(Station(address)) =>
      made("station/" + address, fn(p, core, here, stint, told, _acts) {
        context_node(p)
        @sfpages.station_node(p, core, src, here, address, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~, stint~)
      })
    Setting(Permissions) =>
      made("permissions", fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @sfpages.permissions_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(Me) =>
      made("me", fn(p, core, here, stint, told, _acts) {
        context_node(p)
        @sfpages.me_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, stint~, said=told, width~)
      })
    Setting(Fonts) =>
      made("fonts", fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @sfpages.fonts_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(BarSettings) =>
      made("bars", fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @sfpages.bars_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(Security) =>
      made("security", fn(p, core, here, stint, told, _acts) {
        context_node(p)
        @sfpages.security_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, stint~, said=told, width~)
      })
    Setting(SecurityOpen) =>
      made("security-open", fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.security_open_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(Workspace) =>
      made("workspace", fn(p, core, here, stint, told, _acts) {
        context_node(p)
        @sfpages.workspace_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, stint~, said=told, width~, tips~)
      })
    Setting(VaultItems) =>
      made("vault-items", fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.vault_items_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // 文件 and a station's drive (sfpages' files_page_node.mbt): a bar of their own (no tape bar over them:
    // tape_bar_head), a folder opened from them another entry over them (files_go)
    Files =>
      made("files-home", fn(p, _core, _here, _stint, _told, _acts) {
        guard @signals.untracked(fn() { @sfbase.workspace_in_view(src).0 }) is Some(w) else { return }
        @sfpages.files_home_node(p, src, w.id, frame=fn() { tape_made_frame }, width~, on_back=fn() { app.nav.pop() |> ignore }, tips~, ends=tape_files_ends)
      })
    Drive(at) =>
      made("drive/" + at.station + "/" + at.root.unwrap_or("") + "/" + at.path, fn(p, _core, _here, _stint, told, acts) {
        guard @signals.untracked(fn() { @sfbase.workspace_in_view(src).0 }) is Some(w) else { return }
        @sfpages.drive_page_node(p, src, w.id, fn() { at }, frame=fn() { tape_made_frame }, width~, on_back=fn() { app.nav.pop() |> ignore }, go=files_go, tips~, bar=(told, acts), ends=tape_files_ends)
      })
    Setting(KeptFiles) =>
      made("kept", fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @settings.kept_node(p, core, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // (by its station and thread: another chat's another page)
    Setting(KeptChat(station, thread)) =>
      made("kept/" + station + "/" + thread.to_string(), fn(p, core, _here, _stint, told, _acts) {
        context_node(p)
        @settings.kept_chat_node(p, core, station, thread, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // (by the station whose step is said first: another station's another page)
    Setting(AdbShare(focus)) =>
      made("adb/" + focus, fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @settings.adb_node(p, core, focus, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~, sub=fn() {
          here().sub
        })
      })
    Setting(Vault) =>
      made("vault", fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.vault_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // (by its vault and item: another's another page)
    Setting(VaultItem(vault, item)) =>
      made("vault-item/" + vault + "/" + item, fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.vault_item_node(p, core, here, vault, item, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // (by its station and id: another's another page; 添加连接 in the bar)
    Setting(Connects(only)) =>
      made("connects/" + only, fn(p, core, here, stint, told, acts) {
        @sfpages.connects_node(p, src, core, here, only, on_back=core.pop, frame=fn() { tape_made_frame }, stint~, said=told, width~, tips~, bar_actions=acts)
      })
    Setting(Connect(station, id)) =>
      made("connect/" + station + "/" + id, fn(p, core, here, stint, told, _acts) {
        @sfpages.connect_node(p, src, core, here, station, id, on_back=core.pop, frame=fn() { tape_made_frame }, stint~, said=told, width~, tips~)
      })
    Setting(AutoCompletion) =>
      made("auto-completion", fn(p, core, here, _stint, told, acts) {
        context_node(p)
        @sfpages.completion_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~, bar_actions=acts)
      })
    Setting(Usage) =>
      made("usage", fn(p, core, here, _stint, told, acts) {
        context_node(p)
        @sfpages.usage_node(p, core, src, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~, bar_actions=acts)
      })
    // (by its days: another's of other days another page)
    Setting(UsagePrices(days)) =>
      made("usage-prices/" + days.to_string(), fn(p, core, here, _stint, told, _acts) {
        context_node(p)
        @sfpages.usage_prices_node(p, core, here, days, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(Archiving) =>
      made("archiving", fn(p, core, here, stint, told, _acts) {
        @sfpages.archiving_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, stint~, said=told, width~)
      })
    Setting(AutoDecisions) =>
      made("auto-decisions", fn(p, core, here, _stint, told, _acts) {
        @sfpages.decisions_node(p, core, here, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // (by its station: another station's another page, not this one become it)
    Setting(StationArchiving(st)) =>
      made("station-archiving/" + st, fn(p, core, here, _stint, told, _acts) {
        @sfpages.station_archiving_node(p, core, here, st, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~)
      })
    Setting(StationMove(st)) =>
      made("station-move/" + st, fn(p, core, here, _stint, told, _acts) {
        @sfpages.station_move_node(p, core, here, st, on_back=core.pop, frame=fn() { tape_made_frame }, said=told, width~, tips~)
      })
    // (a chat, and the new chat that becomes one in place: the same page, a node of the tree's)
    page if @sfbase.chat_page_is(page) =>
      Some(
        (
          @sfbase.chat_page_kind(),
          fn(v, _page, _under, stint, k) {
            // (its bar the tree's, over the page: chat_bar_wide_node, keeping clear of the panel's corners as a
            // page's bar on the tape does; the tape's head over it none, tape_bar_head)
            let page_src = @sfbase.chat_page_made(
              v,
              src,
              k,
              drawn=fn(serial) { tape_page_wait.draws(serial) },
              over=fn(o, src, page, stint) { chat_bar_wide_node(o, src, page, tape_chat_bar_ends(o), tips, stint) },
              // (its messages nodes, its composer made as nodes in their list's foot)
              // (built in the page's panel, as tape_page_one builds the page: what stands in its corners concentric with them)
              body=fn(col, s, r, composer, shows, on_stack) {
                // (on the panel's ground, a step darker while it is behind the one in use, going with the tape's move:
                // tape_page_ground, as the island's own was, in the place of the page's ground chat_page_made gives it)
                col.ground(By(fn() { tape_page_ground(col) })) |> ignore
                // (behind the sidebar on the tape, nothing of it read out: tape_behind's)
                col.hides(By(fn() { wide.tape_at.get() != Page })) |> ignore
                context_node(col)
                chat_body_nodes(col, s, r, tips, stint, composer, shows, in_pane=true, on_stack~)
              },
              // (its composer made as nodes in the list's foot, in the page's panel: what stands in its corners concentric
              // with them, sfpages' chat_composer_node)
              foot_node=fn(n, s, r, shows, laid) {
                // (shown as the page is in front on the tape: behind its sidebar, its composer takes no cursor yet,
                // brought up it does, as a page come into sight does)
                @sfpages.chat_composer_node(
                  n,
                  s,
                  r,
                  shows=fn() { shows() && (!wide.tape.get() || wide.tape_at.get() == Page) },
                  laid~,
                  tips~,
                  apart=fn() { wide.tape.get() },
                  pane=fn() { Some(tape_page_round()) },
                  over_it=fn(o) { wide_composer_bar_node(o, s, r, tips, stint) },
                )
              },
              // (its column on the page's way as the tape takes its panel to another width: laid out as at its narrower end)
              narrower=fn(_s, n) { tape_page_narrower(n) },
              // (the new chat it is till it becomes one, made as nodes in the page's panel: sfpages' new_chat_node, on the
              // panel's ground as the chat's column is)
              new_node=fn(n, s) {
                n.hides(By(fn() { wide.tape_at.get() != Page })) |> ignore
                match @signals.untracked(fn() { @sfbase.workspace_in_view(s).0 }) {
                  Some(w) => @sfpages.new_chat_node(n, s, w, new_frame_node(s, w, width, ground=tape_page_ground, apart=fn() {
                      wide.tape.get()
                    }, pane=fn() { Some(tape_page_round()) }), tips)
                  None => ()
                }
              },
            )
            // (its chat's side panel its own as the page is a chat's: kept with it on the stack's kept left, at rest with
            // it, taken back with it (tape_side_node's each))
            v.reacts(fn() { app.nav.page_of(k).map(fn(e) { e.0 }) }, fn(po) {
              match po {
                Some(Chat(r)) => tape_chat_entries[k] = (r, page_src)
                _ => tape_chat_entries.remove(k)
              }
              tape_chat_entries_rev.set(tape_chat_entries_rev.untracked() + 1)
            })
            v.owns(fn() {
              tape_chat_entries.remove(k)
              tape_chat_entries_rev.set(tape_chat_entries_rev.untracked() + 1)
            })
            |> ignore
          },
        ),
      )
    _ => None
  }
}

///|
/// Where a chat's bar in the page's panel on the tape keeps clear at its ends (chat_bar_wide_node's): as a page's bar
/// there (pane_bar_node's, the same rule: tape_bar_start_room, tape_bar_end_room), the panel's corners as they are
/// told it (tape_bar_head's); as much taller over its buttons as the tape's line has them (tape_bar_over); its title
/// on the panel's words' line; what ends it, ⌘F's field where that is open, concentric with the panel's top right
/// corner; its buttons round on that line, no corner of the window's; its ground the panel's (tape_page_ground), as a
/// page's bar there has it.
fn tape_chat_bar_ends(n : @view.View) -> ChatBarEnds {
  let corners = fn() {
    let side = tape_shown_side()
    let under = if side is None { tape_room_now().under } else { 0.0 }
    beside_column(tape_pane_corners(Page, side is Some(_)), under)
  }
  {
    over: fn() { @sf.tape_bar_over() },
    margins: fn() { (0.0, 0.0) },
    // (words first as ever; a chat with no title starts with its marks, each round: past the panel's top left arc, the
    // first of them never in it (@sf.tape_bar_start_of's corner))
    start: fn(titled) {
      let words = tape_bar_start_room(corners(), false)
      if titled {
        words
      } else {
        dmax(words, corners()[0].radius(@ui.tree_corner_roots_now()) - chat_bar_title_in)
      }
    },
    end: fn(_, finding) {
      let side = if finding { @sfpages.find_field_h } else { @sf.bar_key_side }
      let base_end = tape_bar_end_room(corners(), side~)
      if !@ui.window_keys_own() {
        return base_end
      }
      let r = tape_room_now()
      let t = tape_drawn_at(n)
      let page_right = tape_x_at(r, t) + tape_col_at(t) + tape_page_at(t)
      let past_right = dmax(@sf.window_in, r.tw - page_right)
      let keys_clear = @sf.window_keys_room_tape(roots=@ui.tree_corner_roots_now()) + bar_in - past_right
      dmax(base_end, keys_clear)
    },
    linked: fn() { None },
    ground: tape_page_ground,
  }
}

///|
/// What the tape gives a page made once in its panel (tape_made): the bar over it names it and has back (named, no
/// back), nothing over it in its room, the settings' room at its foot (setting_page's).
// kept across runs: a value
let tape_made_frame : @sf.PageFrame = { back: None, top: 0.0, foot: 0.0, named: true }

///|
/// The bar over a page made once in the page's panel (tape_made), as it said of itself (`said`: its title, what it is
/// for; none yet, nothing said), back where the page it was put on from (`under`) is one of the settings' or a place
/// of the rail's (setting_page's); none over a `place` of the rail's itself, whatever is under it (place_page's).
fn tape_made_bar(under : Page?, place : Bool, said : @sf.PageSaid?) -> PaneBarSaid {
  let back = match under {
    Some(u) if !place && u is (Setting(_) | Place(_)) => Some(@sfbase.back_label(u))
    _ => None
  }
  // (back as the page says it, where it says it: a station's profiles, that station's name; page_node's `back_as`)
  let back = match (back, said) {
    (Some(_), Some(s)) if s.back != "" => Some(s.back)
    _ => back
  }
  match said {
    Some(s) => { back, title: s.title, small: "", about: s.about }
    None => { back, title: "", small: "", about: "" }
  }
}

///|
/// Where the files' page's own bar stands in the page's panel (no tape bar over it: tape_bar_head), as a page's bar
/// there does (pane_bar_node's): its start clear of the panel's top left corner, its last button concentric with the top
/// right one where it can be, on the tape's one line (how far down to it).
fn tape_files_ends() -> (Double, Double, Double) {
  let side = tape_shown_side()
  let under = if side is None { tape_room_now().under } else { 0.0 }
  let corners = beside_column(tape_pane_corners(Page, side is Some(_)), under)
  (tape_bar_start_room(corners, true), tape_bar_end_room(corners), @sf.tape_bar_over())
}

///|
/// What a screen's row of actions at its foot keeps under them (sfpages' screen_foot_actions, py=S1).
// kept across runs: a value (no field of it changes)
let tape_remote_foot_in : Double = 4.0

///|
/// The radii of the page's panel on the tape as 远程's workbench stands in it (as tape_chat_bar_ends tells a chat's bar
/// them): top left, top right, bottom right, bottom left.
fn tape_remote_radii() -> FixedArray[Double] {
  let side = tape_shown_side()
  let under = if side is None { tape_room_now().under } else { 0.0 }
  @sf.corner_radii(beside_column(tape_pane_corners(Page, side is Some(_)), under))
}
