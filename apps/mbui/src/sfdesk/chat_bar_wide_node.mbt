// A chat's bar on 中屏 and 大屏 (chat_page.mbt's chat_bar) as nodes of the window's tree, made once over the chat's page
// (chat_page_made's `over`), changed as what it shows does: its title (while a new one goes, that one with a turning
// ring; a red mark a while where it did not), its station while no agent is in it (its card over it), its people, its
// agents (each its history beside the chat, its card on hover; the first one tile with the station it runs on); at its
// end ⌘F's bar while the find is open in it (find_bar_node), else 归档 while nothing is left in it, its services and
// jobs, its station's screens, 对话信息, "…" and the side panel's switch while the panel is closed, none of them where
// the system's bars have them (rail_native.mbt's bar_chat, handed as the old view builds). Where it keeps clear at its
// ends is the frame's (ChatBarEnds: the window's corner on 大屏, the page's panel's on the tape); laid out as the old
// bar was, by the same styles. What opens under it (its info, its jobs) is the old view's as yet, opened by the signals
// its buttons set, beside them (chat_bar_from).

///|
/// Where a chat's bar keeps clear at its ends and over its buttons, as the frame it is in says (chat_bar_wide_node's):
/// how much taller it is over its buttons (`over`: the tape's line), how far it is moved in from its ends while the
/// folded sidebar is shown a while (`margins`, before and after: less than none before, drawn moved back), its room
/// at its start (`start`, given whether a title starts it: one that has none starts with its marks, round as they
/// are) and at its end (`end`, given whether the side panel is open beside it and ⌘F's bar is in it),
/// the corner its buttons share with the window's (`linked`: none on the tape), its ground as drawn in node `bar`
/// (`ground`: the page's; on the tape, the page's panel's, a step darker while that is behind the one in use).
pub(all) struct ChatBarEnds {
  over : () -> Double
  margins : () -> (Double, Double)
  start : (Bool) -> Double
  end : (Bool, Bool) -> Double
  linked : () -> @ui.CornerOf?
  ground : (@view.View) -> Int64
}

///|
/// The bar of the chat page `page` is (none over any other page) in node `v`, over the page's old view, from source
/// `src`, keeping clear at its ends as `ends` says; its tips in `tips`, its pictures asked for on the page's time on
/// top, `stint`.
pub fn chat_bar_wide_node(
  v : @view.View,
  src : Source,
  page : () -> Page?,
  ends : ChatBarEnds,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  let chat = fn() {
    match page() {
      Some(Chat(r)) => Some(r)
      _ => None
    }
  }
  // (the new chat made as nodes with the page (its new_node's): its bar, dragging the window whatever it holds; its 文件
  // where a station lends its files, new_bar_of)
  let new_of = fn() {
    match page() {
      Some(NewChat) => @sfbase.workspace_in_view(src).0
      _ => None
    }
  }
  // (by the chat it is of: another one become in its place another bar, at once, as tall as a bar from the first: none
  // become one (a new chat, a place, 设置 left for a chat) is no bar growing)
  v.switch_by(fn() { (chat().map(fn(r) { (r.station, r.session) }), new_of().map(fn(w) { w.id })) }, fn(b, which) {
    match which {
      (Some(_), _) =>
        match @signals.untracked(chat) {
          Some(r) => wide_bar_of(b, src, r, ends, tips, stint)
          None => ()
        }
      (None, Some(_)) =>
        match @signals.untracked(new_of) {
          Some(w) => new_bar_of(b, src, w, ends, tips)
          None => ()
        }
      (None, None) => ()
    }
  })
}

///|
/// Workspace `w`'s new chat's bar in `b` (new_chat_page's, chat_bar_wide_node's): 文件 where a chat's bar has the side
/// panel's switch, at its end, as far in as `ends` keeps a chat's (the window's corner while its panel is not open beside
/// it), toggling its Station 文件 beside it (new_files_set); nothing else of it, the page's ground under it, its empty
/// part dragging the window where the window's buttons are the app's. Its tips in `tips`.
fn new_bar_of(b : @view.View, src : Source, w : Workspace, ends : ChatBarEnds, tips : @sf.TipLayer) -> Unit {
  let high = fn() { @sf.wide_bar_h + (ends.over)() }
  let beside = fn() { new_files_open(src, w.id) }
  // (its 文件 handed the system's bars where they are the app's, as a chat's actions are (chat_page.mbt's
  // chat_bar_handed_node): as the page comes on top, as the bars come or the column grows short, as a station to look in
  // comes or goes; the actions handed for another page let go first)
  b.reacts(fn() { (app.nav.top() is NewChat, @sf.native_on(), column_short.get(), new_drive_station(src, w) is Some(_)) }, fn(
    said,
  ) {
    guard said.0 else { return }
    @signals.untracked(fn() {
      nav_page_for(NewChat)
      nav_page.retain(fn(p) { p.0.id != "page/new/files" })
      if said.3 {
        bar_action("new/files", @sf.t("web-pages.chat.files"), "folder", fn() {
          new_files_set(src, w.id, !new_files_open(src, w.id))
        })
        |> ignore
      }
    })
  })
  b
  .row(Is(true))
  .height(By(fn() { Some(high()) }))
  .alpha(By(fn() { if @sfbase.first_page_waits.get() { 0.0 } else { 1.0 } }))
  .takes_unseen(Is(true))
  .offset(By(fn() { (dmin(0.0, (ends.margins)().0), 0.0) }))
  |> ignore
  bar_room_node(b, fn() { dmax(0.0, (ends.margins)().0) })
  b.box(fn(bar) {
    bar
    .row(Is(true))
    .grow(Is(1.0))
    .height(By(fn() { Some(high()) }))
    .padding(By(fn() { (0.0, (ends.over)(), 0.0, 1.0) }))
    .lines_up(Is(Some(Middle)))
    .lies_along(Is(End))
    // (its empty part drags the window, in one with its buttons in the app's top row: what is in it taking presses all
    // the same, so it is said to take them always, as a chat's bar's)
    .presses(Is(true))
    .moves_window(By(@ui.window_inset_now))
    |> ignore
    // (drawn in the page where the system's bars are not the app's: there, handed them, above)
    bar.show(fn() { !@sf.native_on() && new_drive_station(src, w) is Some(_) }, fn(e) {
      e.shrink(Is(0.0)) |> ignore
      @sf.icon_button_node(
        e,
        "folder",
        fn() { @sf.t("web-pages.chat.files") },
        fn() { new_files_set(src, w.id, !new_files_open(src, w.id)) },
        tips~,
        linked=ends.linked,
      )
      |> ignore
    })
    bar_room_node(bar, fn() { (ends.end)(beside(), false) })
  })
  |> ignore
  bar_room_node(b, fn() {
    let (ml, mr) = (ends.margins)()
    mr + dmin(0.0, ml)
  })
}

///|
/// Chat `r`'s bar in `b` (chat_bar_wide_node's): its row as page_bar_row's (as high as a bar is, with what is over its
/// buttons; its margins while the folded sidebar is shown a while), its box (chat_bar_box's: its line under it, the
/// page's ground; its empty part dragging the window where the window's buttons are the app's), its rooms at its ends.
fn wide_bar_of(b : @view.View, src : Source, r : ChatRef, ends : ChatBarEnds, tips : @sf.TipLayer, stint : () -> Int) -> Unit {
  let view = fn() { @sfbase.chat_view_now(src, r) }
  // (what opens under it, as the bar is made: chat_pops_node)
  chat_pops_node(b, src, r, view, stint)
  let finding = fn() {
    match view() {
      Some(v) => @sfpages.find_chat() == chat_key(r) && v.thread is Some(_)
      None => false
    }
  }
  // (whether a title starts it: a chat with none starts with its marks)
  let titled = fn() {
    match view() {
      Some(v) => v.title != ""
      None => r.title != ""
    }
  }
  let beside = fn() {
    match view() {
      Some(v) => side_of(v).0.length() > 0
      None => false
    }
  }
  // ⌘F's bar while the find is open and, once it closes, while it fades out as it was (the pick's `leave_of`, its way
  // out its own: find_bar_node's presence_in); then the chat's buttons in its place, faded in over as long from there
  // alone (`back_in`): a bar made with the find shut shows them at once, nothing more made for it. Which of the two
  // holds the place, for its room at its end (`find_shown`), as each is made
  let back_in = Ref(false)
  let find_shown = @signals.signal(@signals.untracked(finding), same=fn(a, b) { a == b })
  let high = fn() { @sf.wide_bar_h + (ends.over)() }
  b.by_room(fn(held, room) {
    held
    .row(Is(true))
    .height(By(fn() { Some(high()) }))
    // (drawn at none while the app's first page waits, as the page's old view is: sfbase's first_page_waits)
    .alpha(By(fn() { if @sfbase.first_page_waits.get() { 0.0 } else { 1.0 } }))
    .takes_unseen(Is(true))
    // (its margins as spaces at its ends, one less than none taken back by drawing the row moved back as far)
    .offset(By(fn() { (dmin(0.0, (ends.margins)().0), 0.0) }))
    |> ignore
    bar_room_node(held, fn() { dmax(0.0, (ends.margins)().0) })
    held.box(fn(bar) {
      @sf.style_node(bar, fn() { chat_bar_box_node }, in_row=true)
      bar
      .ground(By(fn() { (ends.ground)(bar) }))
      .height(By(fn() { Some(high()) }))
      .padding(By(fn() { (0.0, (ends.over)(), 0.0, 1.0) }))
      // (its empty part drags the window, in one with its buttons in the app's top row: what is in it taking presses
      // all the same, so it is said to take them always)
      .presses(Is(true))
      .moves_window(By(fn() { @ui.window_inset() }))
      |> ignore
      bar_room_node(bar, fn() { (ends.start)(titled()) })
      bar.box(fn(inner) {
        @sf.style_node(inner, fn() { chat_bar_inner }, in_row=true)
        wide_bar_title_row(inner, src, r, view, fn() { room.width() }, tips, stint)
        // ⌘F's bar, in place of the buttons while the find is open: it covers none of the chat. Closed, it goes out
        // over find_in_ms before the buttons come (one, then the other: never both seen)
        inner.pick(
          leave_of=fn(was, now) { if was && !now { @sfpages.find_in_ms } else { 0.0 } },
          fn() { finding() },
          fn(e, open) {
            find_shown.set(open)
            if open {
              back_in.val = true
              // (what holds it giving way as it does: the old row's had none of its own)
              e.row(Is(true)).shrink(Is(1.0)).min_width(Is(Some(0.0))) |> ignore
              @sfpages.find_bar_node(
                e,
                src,
                r,
                fn() { view().bind(fn(v) { v.thread }) },
                @sfpages.chat_find_list(r),
                tips,
              )
              |> ignore
            } else {
              // (back from ⌘F's bar faded out: faded in from now, as long)
              if back_in.val {
                back_in.val = false
                let seen = @motion.presence_in(e, @motion.tween(@sfpages.find_in_ms, ease=Out))
                e.alpha(By(seen)) |> ignore
              }
              wide_bar_keys(e, src, r, view, ends, tips, stint)
            }
          },
        )
      })
      |> ignore
      bar_room_node(bar, fn() { (ends.end)(beside(), find_shown.get()) })
    })
    |> ignore
    bar_room_node(held, fn() {
      let (ml, mr) = (ends.margins)()
      mr + dmin(0.0, ml)
    })
  })
  // (as high as the bar, what takes presses in it within it)
  .height(By(fn() { Some(high()) }))
  |> ignore
}

///|
/// The bar's box as chat_bar_box but for its ground, the frame's (ChatBarEnds' `ground`).
// kept across runs: a value (no field of it changes)
let chat_bar_box_node : @ui.Style = @ui.style(row=true, w=@sf.grow, h=@sf.wide_bar_h_size, pb=SPx, align=ACenter)

///|
/// The bar's title row in `inner` (chat_bar_title_row's: never narrower than what is left in it needs, ⌘F's field
/// beside it giving way first): the title, 42% of the bar's width (`across`) at most, 80 at least, cut short; then,
/// once the view is read, its station's tag while no agent is in it, its people (the first to leave the row short of
/// room), its agents (the last but the first leaving next), each made again as what it draws changes. Each of them the
/// row's own (what leaves it, as the old row's boxes: a row leaves out of what it holds, View::fits).
fn wide_bar_title_row(
  inner : @view.View,
  src : Source,
  r : ChatRef,
  view : () -> ChatView?,
  across : () -> Double,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  inner.box(fn(row) {
    @sf.style_node(row, fn() { chat_bar_title_row }, in_row=true)
    row.keeps_held(Is(true)).fits(Is(true)) |> ignore
    wide_bar_breadcrumb(row, view, across, tips)
    wide_bar_title(row, src, r, view, across, tips)
    let people = fn() {
      match view() {
        Some(v) => v.people
        None => []
      }
    }
    row.show(fn() { people().length() > 0 }, along_row=true, fn(p) {
      p.drops(Is(chat_bar_drop_people)) |> ignore
      p.pick(fn() { people().map(fn(p) { "\{p.id}\u{1}\{p.display}\u{1}\{p.picture}" }).join("\u{2}") }, fn(q, _) {
        wide_people(q, src, @signals.untracked(people), 5, tips, stint)
      })
    })
  })
  |> ignore
}

///|
/// Led parent-chat route breadcrumb before the chat title on Medium/Large screens:
/// - 0 ancestors: renders nothing (zero visual noise on ordinary chats and chats opened for a person)
/// - 1-2 ancestors: `[ spawned + parent1 ] › [ parent2 ] ›`
/// - 3+ ancestors: `[ spawned + root ] › [ … ] › [ direct parent ] ›` (clicking `…` opens a menu of middle ancestors)
fn wide_bar_breadcrumb(
  row : @view.View,
  view : () -> ChatView?,
  across : () -> Double,
  tips : @sf.TipLayer,
) -> Unit {
  let openers = fn() {
    match view() {
      Some(v) => v.openers
      None => []
    }
  }
  let key_of = fn() {
    openers().map(fn(o) { "\{o.chat.station}\u{1}\{o.chat.session}\u{1}\{o.chat.title}\u{1}\{o.archived}" }).join("\u{2}")
  }
  row.show(fn() { openers().length() > 0 }, at_once=true, fn(wrap) {
    wrap.row(Is(true)).lines_up(Is(Some(Middle))).gap(Is(2.0)).shrink(Is(0.0)) |> ignore
    wrap.pick(at_once=true, key_of, fn(bc, _) {
      bc.row(Is(true)).lines_up(Is(Some(Middle))).gap(Is(2.0)).shrink(Is(0.0)) |> ignore
      let list = @signals.untracked(openers)
      let n = list.length()
      guard n > 0 else { return }
      let seg_max = fn() { dmax(56.0, dmin(140.0, across() * 0.16)) }
      let crumb_item = fn(p : @view.View, o : @sfbase.Opener, first : Bool) {
        let tip_text = if o.archived && o.note != "" { o.chat.title + " (" + o.note + ")" } else { o.chat.title }
        @sf.action_box_node(p, fn() { o.chat.title }, fn(_) { @sfbase.open_page(Chat(o.chat)) }, fn(b) {
          b
          .row(Is(true))
          .height(Is(Some(@sf.bar_key_side)))
          .padding(Is((6.0, 0.0, 6.0, 0.0)))
          .gap(Is(4.0))
          .lines_up(Is(Some(Middle)))
          .radius(Is(8.0))
          .max_width(By(fn() { Some(seg_max()) }))
          |> ignore
          @sf.hover_ground_node(b)
          @sf.focus_ring_node(b)
          if first {
            @sf.icon_node(b, "spawned", 14.0, By(fn() { if @sf.lit_node(b) { @sf.theme().p.text } else { @sf.theme().p.muted } }))
            |> ignore
          }
          @sf.words_node(b, fn() { o.chat.title }, fn() {
            if @sf.lit_node(b) {
              wide_crumb_words_hot
            } else {
              wide_crumb_words
            }
          })
          .allow_ellipsis(Is(true))
          .min_width(Is(Some(0.0)))
          |> ignore
          @sf.tip_node(tips, b, fn() { tip_text }) |> ignore
        })
        .says(Is(Some(@view.said(Link, label=o.chat.title))))
        |> ignore
      }
      let chevron = fn(p : @view.View) {
        @sf.icon_node(p, "chevron-right", 12.0, By(fn() { @sf.theme().p.subtle })) |> ignore
      }
      if n <= 2 {
        for i, o in list {
          crumb_item(bc, o, i == 0)
          chevron(bc)
        }
      } else {
        crumb_item(bc, list[0], true)
        chevron(bc)
        let middle = list[1:n - 1].to_owned()
        @sf.action_box_node(bc, fn() { @sf.t("web-pages.chat.breadcrumbMore") }, fn(at) {
          let items : Array[@sf.MenuItem?] = middle.map(fn(o) {
            let label = if o.archived && o.note != "" { o.chat.title + " (" + o.note + ")" } else { o.chat.title }
            Some(@sf.menu_item_of(label, icon="spawned", fn() { @sfbase.open_page(Chat(o.chat)) }))
          })
          @sf.menu(items, from=Node(at))
        }, fn(b) {
          b
          .row(Is(true))
          .height(Is(Some(@sf.bar_key_side)))
          .padding(Is((6.0, 0.0, 6.0, 0.0)))
          .lines_up(Is(Some(Middle)))
          .lies_along(Is(Middle))
          .radius(Is(8.0))
          |> ignore
          @sf.hover_ground_node(b)
          @sf.focus_ring_node(b)
          @sf.icon_node(b, "more", 14.0, By(fn() { if @sf.lit_node(b) { @sf.theme().p.text } else { @sf.theme().p.muted } }))
          |> ignore
          @sf.tip_node(tips, b, fn() { @sf.t("web-pages.chat.breadcrumbMore") }) |> ignore
        })
        |> ignore
        chevron(bc)
        crumb_item(bc, list[n - 1], false)
        chevron(bc)
      }
    })
  })
}

///|
// kept across runs: a value (no field of it changes)
let wide_crumb_words : @ui.TextStyle = @ui.text_style(size=Ui, color=Muted, wrap=false, w=Cut)

///|
// kept across runs: a value (no field of it changes)
let wide_crumb_words_hot : @ui.TextStyle = @ui.text_style(size=Ui, color=Fg, wrap=false, w=Cut)

///|
// kept across runs: a value (no field of it changes)
let wide_subchats_count : @ui.TextStyle = @ui.text_style(size=Meta, weight=Medium, color=Muted, wrap=false, tabular=true)

///|
// kept across runs: a value (no field of it changes)
let wide_subchats_count_hot : @ui.TextStyle = @ui.text_style(size=Meta, weight=Medium, color=Fg, wrap=false, tabular=true)

///|
/// The chat's title in its row (chat_title's): while a new one goes (`chat.rename`), that one, a turning ring beside
/// it; its own again where it did not, a red mark there a while saying why.
fn wide_bar_title(
  row : @view.View,
  src : Source,
  r : ChatRef,
  view : () -> ChatView?,
  across : () -> Double,
  tips : @sf.TipLayer,
) -> Unit {
  // (a rename of this chat: by the session the page names it by, or by its thread, as its "…" names it by its row's:
  // a chat a new chat's page became is named by the key it was sent under all along, its row by its station's session)
  let ours = fn(d : Json?) {
    let p = field(d, "params")
    text(d, "call") == "chat.rename" &&
    text(p, "station") == r.station &&
    (text(p, "session") == r.session ||
    (match (opt_number(p, "thread"), view()) {
      (Some(th), Some(v)) => v.thread == Some(th)
      _ => false
    }))
  }
  let renaming = fn() {
    let mut renaming = ""
    for d in items(src.topic("doing", {}).get().value, "doing") {
      let dv = Some(d)
      if text(dv, "stage") != "failed" && ours(dv) {
        renaming = text(field(dv, "params"), "title")
      }
    }
    renaming
  }
  // (what shows: the one going while one goes)
  let title = fn() {
    match renaming() {
      "" =>
        match view() {
          Some(v) => v.title
          None => r.title
        }
      now => now
    }
  }
  let failed = fn() { core_failed_of(src, fn(d) { ours(Some(d)) }) }
  row.box(fn(t) {
    // (42% of the bar at most, 80 at least; giving way with ⌘F's field once the people have left, down to 4 of its
    // letters)
    @sf.style_node(t, fn() { chat_title_room.then(@ui.style(max_w=Fixed(dmax(chat_title_least, across() * chat_title_part)))) }, in_row=true)
    t.shrink(Is(1.0)) |> ignore
    @sf.words_node(
      t,
      title,
      fn() { chat_title_words },
    )
    |> ignore
    // (read out as its words, where they are)
    t.says(By(fn() { Some(@view.said(Text, label=title())) })) |> ignore
  })
  |> ignore
  row.show(fn() { renaming() != "" || failed() is Some(_) }, along_row=true, fn(d) {
    @sfpages.doing_mark_node(d, fn() { renaming() != "" }, failed, size=wide_doing_mark)
    @sf.tip_node(
      tips,
      d,
      fn() {
        match failed() {
          Some(why) => why
          None => @sf.t("web-pages.settings.stations.renaming")
        }
      },
      within=true,
    )
    |> ignore
  })
}

///|
/// The doing mark's size beside the title (doing_mark's, not inline: 14).
let wide_doing_mark : Double = 14.0

///|
/// The machine the chat runs on beside its title while it has no agent to share a tile with (chat_station's): how it is
/// reached a dot before it, its mark, its name, a quiet tag, its words' ink and the strong line under the hand; its
/// card over it as the pointer rests there, from the presenters as a finger taps it.
fn wide_station_tag(
  m : @view.View,
  address : String,
  s : Station,
  via : () -> String,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  m.box(fn(k) {
    // (a mouse's press on it the bar's: lit by the pointer within it)
    let hot = fn() { @sf.lit_within_node(k) }
    @sf.style_node(
      k,
      fn() {
        let look = if hot() { chat_station_hot } else { chat_station_tag }
        if via() != "" {
          look.then(@ui.style(pl=@sf.room_of(chat_station_dot_in)))
        } else {
          look
        }
      },
      in_row=true,
    )
    k.says(Is(Some(@view.said(Group, label=s.name)))) |> ignore
    @sf.hover_card_node(tips, k, fn(c) { @settings.station_peek_card_node(c, address, stint) }, tile=true, padded=false, tapped=fn() {
      @settings.open_station_peek(address, from=Node(k))
    })
    |> ignore
    // (how it is reached, none where none is said: laid out nowhere then, the same node: no structure round it)
    k.box(fn(d) {
      wide_via_dot(d, via)
      d.laid_nowhere(By(fn() { via() == "" })) |> ignore
    })
    |> ignore
    if @sf.has_station_mark(s.emoji, s.icon) {
      @sf.station_mark_node(k, fn() { s.emoji }, fn() { s.icon }, chat_station_mark, fn() {
        if hot() {
          @sf.theme().p.text
        } else {
          @sf.theme().p.muted
        }
      }, stint)
    }
    @sf.words_node(k, fn() { s.name }, fn() { if hot() { chat_station_words_hot } else { chat_station_words } }) |> ignore
  })
  |> ignore
}

///|
/// How a station is reached as a dot (via_dot's).
/// Node `d` drawn as the dot itself, its colour following `via` in place.
fn wide_via_dot(d : @view.View, via : () -> String) -> Unit {
  @sf.style_node(
    d,
    fn() {
      match via() {
        "direct" => via_direct
        "relay" => via_relay
        "offline" => via_offline
        _ => via_waiting
      }
    },
    in_row=true,
  )
}

///|
/// People overlapping a little (people_stack's): the library's stack (@sf.avatar_stack_node), `most` of them at most,
/// each a 16 face ringed 1.5 in the sidebar's ground (their picture, or their initial on the paper), each ringed face 7
/// along the one before it and drawn over it, the first's ring standing out of where the stack starts; more, +n after them;
/// their names in its tip.
fn wide_people(
  parent : @view.View,
  src : Source,
  people : Array[Person],
  most : Int,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  let faces = people.map(fn(p) {
    let face : @sf.StackFace = {
      id: p.id,
      name: p.display,
      pictured: p.picture != "",
      picture: fn() { if p.picture != "" { (src.picture)(p.picture, stint()) } else { "" } },
    }
    face
  })
  @sf.avatar_stack_node(
    parent,
    faces,
    person_side,
    fn() { @sf.theme().p.sidebar },
    over=7.0,
    // (each over the one before, one with no picture its initial on the paper: the old page's people_stack, drawn the
    // same as it beside it)
    first_over=false,
    letter=(fn() { @sf.theme().p.paper }, fn() { people_letter }),
    most~,
    tips~,
    tip=fn() {
      @sf.t("web-main.people.in", args=[("names", people.map(fn(p) { p.display }).join(@sf.t("web-main.list.separator")))])
    },
  )
  .margin(Is((-1.5, 0.0, 0.0, 0.0)))
  |> ignore
}

///|
/// One of the chat's agents in the bar (agent_tile's): its mark (20), pressed its history's tab opens (in front,
/// closes); its card as the pointer rests on it; marked among several while its history shows. The chat's first, one
/// tile with the station it runs on (`station`: its mark, or its name kept short; how it is reached a dot on the
/// tile's corner); with touch the tile itself the button, held its card and its station's as one.
fn wide_agent_tile(
  parent : @view.View,
  src : Source,
  r : ChatRef,
  a : Agent,
  badge : () -> String,
  marked : () -> Bool,
  station : Station?,
  via : () -> String,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  let said = fn() { @sf.t("web-pages.chat.historyOf", args=[("agent", a.who)]) }
  // (of the chat's head alone: sfbase's chat_head_json, told as its agents change, not as a word comes into a message)
  let badge_said = fn() { text(field(agent_json(@sfbase.chat_head_json(src, r), a.key), "session"), "badgeText") }
  let toggle = fn() { side_toggle(src, r, a.key) }
  // (its card, given the hand's card: what is opened from it stands beside it; kept open while that is)
  let hand : Ref[@sf.HoverHand?] = Ref(None)
  let held : Ref[() -> Bool] = Ref(fn() { false })
  let card = fn() {
    match hand.val {
      Some(h) => (h.card)()
      None => None
    }
  }
  match station {
    Some(s) if @sf.tile_whole() =>
      // (with touch the tile itself the button, as it is drawn: tapped its history's; held, its card and its
      // station's as one: the user, 2026-10-27: 它们是一体的)
      @sf.action_box_node(parent, said, fn(_) { toggle() }, on_hold=fn() { if hand.val is Some(h) { (h.hold)() } }, fn(t) {
        @sf.style_node(t, fn() { if marked() { agent_station_on } else { agent_station } }, in_row=true)
        hand.val = Some(
          @sf.hover_card_node(
            tips,
            t,
            fn(c) {
              c.box(fn(o) {
                @sf.style_node(o, fn() { tile_card_agent })
                held.val = @sfpages.agent_card_node(o, src, r, a.key, tips, card, across=true)
              })
              |> ignore
              @settings.station_peek_part_node(c, r.station, stint)
            },
            tile=true,
            padded=false,
            held=fn() { (held.val)() },
            pointed=fn() { t.pointed_in() },
          ),
        )
        let hot = fn() { @sf.lit_node(t) }
        t.box(fn(g) {
          @sf.style_node(g, fn() { if hot() { agent_station_agent_hot } else { agent_station_agent } }, in_row=true)
          wide_tile_seam(g, true)
          wide_agent_mark(g, a, badge, badge_said, joined=true)
        })
        |> ignore
        t.box(fn(p) {
          @sf.style_node(p, fn() { if hot() { agent_station_part_hot } else { agent_station_part } }, in_row=true)
          wide_tile_seam(p, false)
          wide_station_part(p, s, fn() { false }, stint)
        })
        |> ignore
        wide_tile_dot(t, via)
      })
      |> ignore
    Some(s) =>
      parent.box(fn(t) {
        @sf.style_node(t, fn() { if marked() { agent_station_on } else { agent_station } }, in_row=true)
        let agent = @sf.action_box_node(t, said, fn(_) { toggle() }, on_hold=fn() { if hand.val is Some(h) { (h.hold)() } }, fn(g) {
          let hot = fn() { @sf.lit_node(g) }
          @sf.style_node(g, fn() { if hot() { agent_station_agent_hot } else { agent_station_agent } }, in_row=true)
          wide_tile_seam(g, true)
          hand.val = Some(
            @sf.hover_card_node(
              tips,
              g,
              fn(c) { held.val = @sfpages.agent_card_node(c, src, r, a.key, tips, card) },
              tile=true,
              held=fn() { (held.val)() },
              pointed=fn() { g.pointed_in() },
            ),
          )
          wide_agent_mark(g, a, badge, badge_said, joined=true)
        })
        t.box(fn(p) {
          // (a mouse's press on it the bar's: lit by the pointer within it, but where the agent's half reaches over it
          // (its room a press's, the press there the agent's): that half's alone there, lit and its card)
          let hot = fn() { @sf.lit_within_node(p, yields_to=agent) }
          @sf.style_node(p, fn() { if hot() { agent_station_part_hot } else { agent_station_part } }, in_row=true)
          wide_tile_seam(p, false)
          p.says(Is(Some(@view.said(Group, label=s.name)))) |> ignore
          @sf.hover_card_node(tips, p, fn(c) { @settings.station_peek_card_node(c, r.station, stint) }, tile=true, padded=false, yields_to=agent, tapped=fn() {
            @settings.open_station_peek(r.station, from=Node(p))
          })
          |> ignore
          wide_station_part(p, s, hot, stint)
        })
        |> ignore
        wide_tile_dot(t, via)
      })
      |> ignore
    None =>
      @sf.action_box_node(parent, said, fn(_) { toggle() }, on_hold=fn() { if hand.val is Some(h) { (h.hold)() } }, fn(t) {
        @sf.style_node(t, fn() { if marked() { agent_mark_btn_on } else { agent_mark_btn } }, in_row=true)
        hand.val = Some(
          @sf.hover_card_node(
            tips,
            t,
            fn(c) { held.val = @sfpages.agent_card_node(c, src, r, a.key, tips, card) },
            tile=true,
            held=fn() { (held.val)() },
            pointed=fn() { t.pointed_in() },
          ),
        )
        wide_agent_mark(t, a, badge, badge_said, joined=false)
      })
      |> ignore
  }
}

///|
/// An agent's mark in the bar (agent_mark's, 20 across): its maker's mark on its tile (none of its own where `joined`:
/// the tile it is in paints its ground and hover), its badge at its corner, said as `said` says.
fn wide_agent_mark(parent : @view.View, a : Agent, badge : () -> String, said : () -> String, joined~ : Bool) -> Unit {
  parent.box(fn(m) {
    @sf.style_node(
      m,
      fn() {
        (if joined { wide_mark_contents } else { wide_mark_tile }).then(
          @ui.style(w=Fixed(wide_mark_side), h=Fixed(wide_mark_side), radius=@sf.agent_mark_corner(wide_mark_side)),
        )
      },
      in_row=true,
    )
    m.says(By(fn() { if said() == "" { None } else { Some(@view.said(Group, label=said())) } })) |> ignore
    @sf.maker_mark_node(m, a.maker, a.runtime, (wide_mark_side * wide_logo_of).round()) |> ignore
    // (its state drawn again in place as it changes: over the mark, as big as it, moving nothing in its row)
    // (none made while it has none, as most marks have, till it first comes to one: agent_badge_slot)
    @sfpages.agent_badge_slot(m, badge, wide_mark_side)
  })
  |> ignore
}

///|
/// The mark's side in the bar, and how large its maker's mark is on it (agent_mark's .62).
let wide_mark_side : Double = 20.0

///|
let wide_logo_of : Double = 0.62

///|
// kept across runs: a value (no field of it changes)
let wide_mark_tile : @ui.Style = @ui.css("bg=Neutral align=ACenter justify=JCenter")

///|
// kept across runs: a value (no field of it changes)
let wide_mark_contents : @ui.Style = @ui.css("align=ACenter justify=JCenter")

///|
/// A half of the first agent's tile round at its outer end alone (agent_station_agent's and agent_station_part's
/// corners, which style_node does not take: square where the two meet), the agent's at its start (`first`).
fn wide_tile_seam(half : @view.View, first : Bool) -> Unit {
  let (r, s) = (agent_station_round, agent_station_seam)
  half.corners(Is(Some(if first { (r, s, s, r) } else { (s, r, r, s) }))) |> ignore
}

///|
/// The station's part of the first agent's tile: its mark (12; the words' ink while `hot`), or its name kept short.
fn wide_station_part(p : @view.View, s : Station, hot : () -> Bool, stint : () -> Int) -> Unit {
  if @sf.has_station_mark(s.emoji, s.icon) {
    @sf.station_mark_node(p, fn() { s.emoji }, fn() { s.icon }, chat_station_mark, fn() {
      if hot() {
        @sf.theme().p.text
      } else {
        @sf.theme().p.muted
      }
    }, stint)
  } else {
    @sf.words_node(p, fn() { s.name }, fn() { if hot() { chat_station_words_hot } else { chat_station_words } }) |> ignore
  }
}

///|
/// How the station is reached, a dot on the tile's bottom right corner, 3 past it, over the tile (none: "").
fn wide_tile_dot(t : @view.View, via : () -> String) -> Unit {
  // (none where none is said: laid out nowhere then, the same nodes: no structure round them)
  t.box(fn(o) {
    o.over(Is(true)).laid_nowhere(By(fn() { via() == "" })) |> ignore
    @sf.style_node(o, fn() { agent_station_dot_room })
    o.box(fn(d) { @sf.style_node(d, fn() { corner_dot_of(via()) }) }) |> ignore
  })
  |> ignore
}

///|
/// The bar's buttons at its end in `e` (chat_bar's keys_row, none where the system's bars have them): 归档 while
/// nothing is left in it, its services and jobs (a dot while one died lately or a service restarts), its station's
/// screens, 对话信息, "…", the side panel's switch while the panel is closed and an agent is in it.
fn wide_bar_keys(
  e : @view.View,
  src : Source,
  r : ChatRef,
  view : () -> ChatView?,
  ends : ChatBarEnds,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  e.box(fn(k) {
    @sf.style_node(k, fn() { @sf.keys_row() }, in_row=true)
    let own = fn() { view() is Some(_) && !@sf.native_on() }
    let scope = fn() {
      match @sfbase.workspace_in_view(src).0 {
        Some(w) => w.id
        None => ""
      }
    }
    let chat = fn() { @sfbase.chat_head_json(src, r) }
    // nothing left in it (the core's `archivable`): archived with one press
    k.show(
      fn() {
        own() &&
        (match view() {
          Some(v) => v.archivable && !v.archived
          None => false
        })
      },
      along_row=true,
      fn(b) {
        @sf.icon_button_node(b, "archive", fn() { @sf.t("web-pages.chat.archive") }, fn() {
          match (@signals.untracked(view), @signals.untracked(fn() { @sfbase.workspace_in_view(src).0 })) {
            (Some(v), Some(w)) => archive_asked(src, w, r, v, @signals.untracked(chat))
            _ => ()
          }
        }, tips~, linked=ends.linked, shortcut="chat.archive")
        |> ignore
      },
    )
    // its services and jobs, while it has any
    // idle remote screens entry stays in the top bar; when an agent actively drives a screen, it moves above the composer
    k.show(
      fn() {
        own() &&
        (match view() {
          Some(v) => chat_has_remote(v) && !chat_screens_driven(v.screens)
          None => false
        })
      },
      along_row=true,
      fn(b) {
        let me : Ref[@view.View?] = Ref(None)
        let button = @sf.icon_button_node(b, "monitor", fn() { @sf.t("web-pages.chat.screen") }, fn() {
          match (@signals.untracked(view), me.val) {
            (Some(v), Some(at)) => chat_remote_open(src, r, v, from=Node(at))
            _ => ()
          }
        }, tips~, linked=ends.linked, shortcut="chat.screen")
        me.val = Some(button)
      },
    )
    // what it is (its info's popover beside it: chat_pops_node's), what is done with it ("…": the menu a row of the sidebar has)
    k.show(own, at_once=true, fn(b) {
      b.row(Is(true)).gap(Is(4.0)).lines_up(Is(Some(Middle))) |> ignore
      let button = @sf.icon_button_node(b, "info", fn() { @sf.t("web-pages.chat.info") }, fn() {
        chat_own.info_open.set(!chat_own.info_open.untracked())
      }, tips~, linked=ends.linked)
      chat_info_pop_node(b, src, r, view, stint, Some(button))
      let me : Ref[@view.View?] = Ref(None)
      me.val = Some(
        @sf.icon_button_node(b, "more", fn() { @sf.t("common.more") }, fn() {
          let extra = @sfpages.chat_extra_items(src, r, @signals.untracked(chat))
          match me.val {
            Some(at) => @sfpages.open_chat_menu(src, @signals.untracked(scope), r, extra, from=Node(at), along=End)
            None => ()
          }
        }, tips~, linked=ends.linked),
      )
    })
    // the side panel's switch while it is closed: the first agent's history in it; coming and going along the row, what
    // is beside it going its way with it (along_row), as the panel slides closed or open
    let panel_closed_with_switch = fn() {
      own() &&
      (match view() {
        Some(v) => side_of(v).0.length() == 0 && v.agents.length() > 0
        None => false
      })
    }
    k.show(
      panel_closed_with_switch,
      along_row=true,
      fn(b) {
        @sf.icon_button_node(b, "panel-open", fn() { @sf.t("web-pages.chat.openPanel") }, fn() {
          match @signals.untracked(view) {
            Some(v) if v.agents.length() > 0 => side_change(src, r, "open", Some(v.agents[0].key))
            _ => ()
          }
        }, tips~, linked=ends.linked, shortcut="chat.history")
        |> ignore
      },
    )
  })
  |> ignore
}

///|
// kept across runs: a value (no field of it changes)
let wide_subchats_words : @ui.TextStyle = @ui.text_style(size=Meta, color=Fg, wrap=false)

///|
/// Active controls strip directly above the composer on Medium / Large screens (isomorphic with Small's
/// `chat_composer_bar_node`):
/// - Left: frequent controls (Agent + Station tiles via `wide_agent_tile`, or `wide_station_tag` when no agent)
/// - Right: live/active controls (Active Jobs, Driven Screen, Led Sub-chats) under a single `show` so ordinary chats
///   with none pay at most one idle slot node. Popovers for Jobs and Sub-chats anchor upward (`side=Top`).
fn wide_composer_bar_node(
  o : @view.View,
  src : Source,
  r : ChatRef,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  let view = fn() { @sfbase.chat_view_now(src, r) }
  let station_held = @sfbase.station_mark_held(src, r.station)
  let station = fn() { station_held.get() }
  let station_key = fn() {
    match station() {
      Some(s) => "\{s.name}\u{1}\{s.emoji}\u{1}\{s.icon}"
      None => ""
    }
  }
  let via = fn() {
    match station() {
      Some(s) => s.via
      None => ""
    }
  }
  let agents = fn() {
    match view() {
      Some(v) => v.agents
      None => []
    }
  }
  let jobs_held = @sfbase.topic_value_held(src, "chatJobs", chat_jobs_summary_params(r))
  let jobs = fn() { jobs_held.get() }
  let has_jobs = fn() { flag(jobs(), "hasJobs") || items(jobs(), "jobs").length() > 0 }
  let alarm = fn() { if has_jobs() { text(jobs(), "alarm") } else { "" } }
  let driven = fn() {
    match view() {
      Some(v) => chat_screens_driven(v.screens)
      None => false
    }
  }
  let led_subchats = fn() {
    match view() {
      Some(v) => @sfpages.led_subchats(v.opened)
      None => []
    }
  }
  let has_subchats = fn() { led_subchats().length() > 0 }
  let subchats_tone = fn() {
    match view() {
      Some(v) => @sfpages.opened_summary_tone(v.opened)
      None => ""
    }
  }
  let has_right = fn() { has_jobs() || driven() || has_subchats() }
  let own = fn() { !@sf.native_on() }
  o
  .row(Is(true))
  .lines_up(Is(Some(Middle)))
  .lies_along(Is(Between))
  .gap(Is(8.0))
  .padding(Is((2.0, 0.0, 2.0, 6.0)))
  |> ignore
  // Left group: frequent Agent + Station controls under a single `each` (no idle show/pick slots)
  o.box(fn(left) {
    left.row(Is(true)).gap(Is(6.0)).lines_up(Is(Some(Middle))).shrink(Is(1.0)).min_width(Is(Some(0.0))) |> ignore
    left.each(
      at_once=true,
      fn() {
        let all = agents()
        if all.length() > 0 {
          all.mapi(fn(i, a) { (i, Some(a)) })
        } else if view() is Some(_) && station() is Some(_) {
          [(-1, None)]
        } else {
          []
        }
      },
      fn(item) {
        match item.1 {
          Some(a) =>
            "a\u{1}\{item.0}\u{1}\{a.key}\u{1}\{a.maker}\u{1}\{a.runtime}\u{1}\{a.who}" +
            (if item.0 == 0 { "\u{1}" + station_key() } else { "" })
          None => "s\u{1}" + station_key()
        }
      },
      fn(k, it) {
        let (i, a_opt) = it.untracked()
        match a_opt {
          None => {
            k.radius(Is(999.0)).ground(By(fn() { @sf.theme().p.bg })) |> ignore
            match @signals.untracked(station) {
              Some(s) => wide_station_tag(k, r.station, s, via, tips, stint)
              None => ()
            }
          }
          Some(a) => {
            let key = a.key
            let badge = fn() {
              match it.get().1 {
                Some(x) => x.badge
                None => ""
              }
            }
            let marked = fn() {
              let front = match view() {
                Some(v) => side_of(v).1
                None => ""
              }
              agents().length() > 1 && front == key
            }
            let s = if i == 0 { @signals.untracked(station) } else { None }
            wide_agent_tile(k, src, r, a, badge, marked, s, via, tips, stint)
          }
        }
      },
    )
  })
  |> ignore
  // Right group: live/active controls under a single `show`
  o.show(has_right, at_once=true, fn(right) {
    right.row(Is(true)).gap(Is(6.0)).lines_up(Is(Some(Middle))).shrink(Is(0.0)) |> ignore
    // Active Jobs pill
    right.show(has_jobs, at_once=true, fn(b) {
      let button = @sf.action_box_node(b, fn() { @sf.t("web-pages.chat.services") }, fn(_) { jobs_pressed(src, r) }, fn(btn) {
        btn
        .row(Is(true))
        .height(Is(Some(20.0)))
        .padding(Is((6.0, 0.0, 6.0, 0.0)))
        .gap(Is(4.0))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(Middle))
        .radius(Is(6.0))
        .edge(By(fn() { (1.0, @sf.theme().p.line) }))
        |> ignore
        @sf.hover_ground_node(btn, on=fn() { !chat_own.jobs_open.get() })
        btn.ground(By(fn() { if chat_own.jobs_open.get() { @sf.theme().p.hover } else { @sf.theme().p.card } })) |> ignore
        @sf.focus_ring_node(btn)
        let hot = fn() { @sf.lit_node(btn) || chat_own.jobs_open.get() }
        @sf.icon_node(btn, "web", 12.0, By(fn() { if hot() { @sf.theme().p.text } else { @sf.theme().p.muted } })) |> ignore
        btn.show(fn() { alarm() == "fail" || alarm() == "restart" }, at_once=true, fn(d) {
          d
          .width(Is(Some(6.0)))
          .height(Is(Some(6.0)))
          .radius(Is(3.0))
          .ground(By(fn() { if alarm() == "fail" { @sf.theme().p.red } else { @ui.tree_theme().color(Warn) } }))
          |> ignore
        })
        @sf.tip_node(tips, btn, fn() { @sf.t("web-pages.chat.services") }, shortcut="chat.jobs") |> ignore
      })
      if @signals.untracked(own) {
        chat_jobs_pop_node(b, src, r, Some(button))
      }
    })
    // Driven Screen pill
    right.show(driven, at_once=true, fn(b) {
      @sf.action_box_node(b, fn() { @sf.t("web-pages.chat.screen") }, fn(at) {
        match @signals.untracked(view) {
          Some(v) => chat_remote_open(src, r, v, from=Node(at), along=End)
          None => ()
        }
      }, fn(btn) {
        btn
        .row(Is(true))
        .height(Is(Some(20.0)))
        .padding(Is((6.0, 0.0, 6.0, 0.0)))
        .gap(Is(4.0))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(Middle))
        .radius(Is(6.0))
        .edge(By(fn() { (1.0, @sf.theme().p.line) }))
        |> ignore
        @sf.hover_ground_node(btn)
        btn.ground(By(fn() { @sf.theme().p.card })) |> ignore
        @sf.focus_ring_node(btn)
        let hot = fn() { @sf.lit_node(btn) }
        @sf.icon_node(btn, "monitor", 12.0, By(fn() { if hot() { @sf.theme().p.text } else { @sf.theme().p.muted } })) |> ignore
        btn.box(fn(d) {
          d
          .width(Is(Some(6.0)))
          .height(Is(Some(6.0)))
          .radius(Is(3.0))
          .ground(By(fn() { @sf.theme().p.primary }))
          |> ignore
        })
        |> ignore
        @sf.tip_node(tips, btn, fn() { @sf.t("web-pages.chat.screen") }, shortcut="chat.screen") |> ignore
      })
      |> ignore
    })
    // Led Sub-chats pill
    right.show(has_subchats, at_once=true, fn(b) {
      let label = fn() { @sf.t("web-pages.chat.subchats") }
      let button = @sf.action_box_node(b, label, fn(_) { toggle_subchats_pop() }, fn(btn) {
        btn
        .row(Is(true))
        .height(Is(Some(20.0)))
        .padding(Is((6.0, 0.0, 6.0, 0.0)))
        .gap(Is(4.0))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(Middle))
        .radius(Is(6.0))
        .edge(By(fn() { (1.0, @sf.theme().p.line) }))
        |> ignore
        @sf.hover_ground_node(btn, on=fn() { !chat_own.subchats_open.get() })
        btn.ground(By(fn() { if chat_own.subchats_open.get() { @sf.theme().p.hover } else { @sf.theme().p.card } })) |> ignore
        @sf.focus_ring_node(btn)
        let hot = fn() { @sf.lit_node(btn) || chat_own.subchats_open.get() }
        @sf.icon_node(btn, "spawned", 12.0, By(fn() { if hot() { @sf.theme().p.text } else { @sf.theme().p.muted } })) |> ignore
        @sf.words_node(btn, label, fn() { wide_subchats_words }) |> ignore
        @sf.words_node(btn, fn() { led_subchats().length().to_string() }, fn() {
          if hot() {
            wide_subchats_count_hot
          } else {
            wide_subchats_count
          }
        })
        |> ignore
        btn.show(at_once=true, fn() { subchats_tone() != "" }, fn(d) {
          d
          .width(Is(Some(6.0)))
          .height(Is(Some(6.0)))
          .radius(Is(3.0))
          .ground(By(fn() {
            match subchats_tone() {
              "fail" => @sf.theme().p.red
              "need" => @ui.tree_theme().color(Warn)
              _ => @sf.theme().p.online
            }
          }))
          |> ignore
        })
        @sf.tip_node(tips, btn, label) |> ignore
      })
      if @signals.untracked(own) {
        chat_subchats_pop_node(b, src, r, view, Some(button))
      }
    })
  })
}
