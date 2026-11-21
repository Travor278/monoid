// A chat's bar laid out Small as nodes of the window's tree (chat_bar's and bar_frame's, over the chat's page made once:
// narrow_made's "chat"), made once and changed as what it shows does: back, the title, its station while no agent is
// in it, its people, its agents' marks; 归档 coming and going as nothing is left in it or something is again, its
// services and jobs, what it is (ⓘ) and what is done with it ("…"). On the bar's glass once the chat's view is read,
// the page's ground under it till then (its title what it was opened by, nothing at its end).

///|
/// The bar of the chat page `page` is (none over any other) in node `v`, over the page's old view, from source `src`;
/// its pictures asked for on the page's time on top, `stint`.
fn chat_bar_node(v : @view.View, src : Source, page : () -> Page?, stint : () -> Int) -> Unit {
  let chat = fn() {
    match page() {
      Some(Chat(r)) => Some(r)
      _ => None
    }
  }
  // (by the chat it is of, given it: another one become in its place another bar)
  v.pick(fn() { { chat: chat() } }, fn(b, which) {
    guard which.chat is Some(r) else { return }
    chat_bar_of(b, src, r, stint)
  })
}

///|
/// The chat a page's bar is of (chat_bar_node), one told from another by where it is (its station and session), not by
/// the title it was opened by.
priv struct BarOf {
  chat : ChatRef?
}

///|
impl Eq for BarOf with equal(a, b) {
  a.chat.map(fn(r) { (r.station, r.session) }) == b.chat.map(fn(r) { (r.station, r.session) })
}

///|
let chat_bar_expand_ms : Double = 280.0

///|
let chat_bar_collapse_ms : Double = 260.0

///|
priv struct ChatBarState {
  manual_expanded : @signals.Signal[Bool]
  open_way : @motion.NodeWay
  row2_h : @signals.Signal[Double]
  extra_target : @signals.Signal[Double]
  crumb_h : @signals.Signal[Double]
  mut settled_initial : Bool
}

///|
let chat_bar_states : Map[String, ChatBarState] = Map([])

///|
fn chat_bar_reset() -> Unit {
  chat_bar_states.clear()
}

///|
fn chat_bar_key(r : ChatRef) -> String {
  r.station + "\u{1}" + r.session
}

///|
fn chat_bar_state(r : ChatRef) -> ChatBarState {
  let k = chat_bar_key(r)
  match chat_bar_states.get(k) {
    Some(s) => s
    None => {
      let s = {
        manual_expanded: @signals.signal(false, same=fn(a, b) { a == b }),
        open_way: @motion.NodeWay::new(0.0),
        row2_h: @signals.signal(0.0, same=fn(a, b) { a == b }),
        extra_target: @signals.signal(0.0, same=fn(a, b) { a == b }),
        crumb_h: @signals.signal(0.0, same=fn(a, b) { a == b }),
        settled_initial: false,
      }
      chat_bar_states[k] = s
      s
    }
  }
}

///|
/// Where chat `r`'s bar comes to end, its second row as it comes to show or not (a long title's, measured as the bar is
/// laid out, after the list was made and put where it opens; opened or shut by a press): what the list put somewhere
/// stands under. Read as it changes: its state made where the bar is not made yet.
fn bar_foot_coming(r : ChatRef) -> Double {
  let s = chat_bar_state(r)
  bar_foot() + s.extra_target.get() + s.crumb_h.get()
}

///|
fn bar_extra_shown(v : @view.View, r : ChatRef) -> Double {
  match chat_bar_states.get(chat_bar_key(r)) {
    Some(s) => s.open_way.shown(v) * s.row2_h.get() + s.crumb_h.get()
    None => 0.0
  }
}

///|
fn bar_clamp01(v : Double) -> Double {
  if v < 0.0 {
    0.0
  } else if v > 1.0 {
    1.0
  } else {
    v
  }
}

///|
/// Chat `r`'s bar (chat_bar_node) in `b`.
fn chat_bar_of(b : @view.View, src : Source, r : ChatRef, stint : () -> Int) -> Unit {
  let from_fresh = @signals.untracked(fn() { @sfbase.fresh.became.get() == Some(r) })
  if from_fresh {
    @sfbase.fresh_choreo.val.arm(b)
  }
  let state = chat_bar_state(r)
  b.owns(fn() {
    let k = chat_bar_key(r)
    if chat_bar_states.get(k) is Some(now) && physical_equal(now, state) {
      chat_bar_states.remove(k)
    }
  })
  |> ignore
  let mid_w_sig : @signals.Signal[Double] = @signals.signal(0.0, same=fn(a, b) { a == b })
  let view = fn() { @sfbase.chat_view_now(src, r) }
  let read = fn() { view() is Some(_) }
  let title_now = fn() {
    match view() {
      Some(v) => v.title
      None => r.title
    }
  }
  let g = b
  let metrics = fn() {
    let mid_w = mid_w_sig.get()
    if !read() || mid_w <= 0.0 {
      return (false, false)
    }
    let th = @sf.theme()
    let sp = @sf.node_sp(g, th.t.title)
    let title_w = @sf.node_words_w(title_now(), sp, weight=600)
    // 3 CJK em (~1em each) + ellipsis (~0.75em): scales with font size without shaping an unrecorded literal in CI textref.
    let three_w = dmax(44.0, sp * 3.75)
    let avail = dmax(0.0, mid_w - 16.0)
    let overflows = title_w > avail
    let must_expand = overflows && avail < three_w
    let can_toggle = overflows && !must_expand
    (must_expand, can_toggle)
  }
  let must_expand_sig : @signals.Signal[Bool] = @signals.signal(false, same=fn(a, b) { a == b })
  let can_toggle_sig : @signals.Signal[Bool] = @signals.signal(false, same=fn(a, b) { a == b })
  let can_toggle = fn() { can_toggle_sig.get() }
  // ⌘F's bar open in this chat (opened from its sheet's 在对话中查找, chat_info_node): in the row in place of its
  // title and keys, its second row shut meanwhile
  // (the find's chat alone, not the chat's view: a change of the chat runs none of what reads it; it opens only
  // where the chat has a thread)
  let find_key = @sfpages.chat_key(r)
  let finding = fn() { @sfpages.find_chat() == find_key }
  let expanded = fn() {
    !finding() && (must_expand_sig.get() || (can_toggle_sig.get() && state.manual_expanded.get()))
  }
  g.reacts(metrics, fn(m) {
    must_expand_sig.set(m.0)
    can_toggle_sig.set(m.1)
  })
  // (what the bar's first row holds last told by an answer (the chat's first value, as the page opens): what it
  // leaves the title is laid out after that answer is over, and opens or shuts the second row at once as an answer's
  // change does, not on its way; told otherwise (live, a press, the find opened or shut), on its way again)
  let answer_settle = Ref(false)
  let bar_inputs = fn() {
    let v_shape = match view() {
      Some(v) => (true, v.title, v.archivable && !v.archived, v.people.length(), v.openers.length())
      None => (false, r.title, false, 0, 0)
    }
    (v_shape, finding(), state.manual_expanded.get())
  }
  g.reacts(bar_inputs, at_start=false, fn(_) { answer_settle.val = @view.answering_now() })
  g.reacts(fn() { (mid_w_sig.get() > 0.0, expanded(), state.row2_h.get()) }, fn(cur) {
    if cur.0 && (!state.settled_initial || answer_settle.val || @view.answering_now()) {
      // (open as it is first laid out, and as an answer changes what it holds: settled only once its second row's height
      // is known (that row made while it is open, measured shut), its way and the height it comes to put there at once
      // together, never open on a height of none first)
      if !cur.1 || cur.2 > 0.0 {
        state.settled_initial = true
        answer_settle.val = false
        state.open_way.put(if cur.1 { 1.0 } else { 0.0 })
        state.extra_target.set(if cur.1 { cur.2 } else { 0.0 })
      }
    } else if state.settled_initial {
      if cur.1 != (state.open_way.target() >= 0.5) {
        state.open_way.go_ms(
          g,
          if cur.1 { 1.0 } else { 0.0 },
          if cur.1 { chat_bar_expand_ms } else { chat_bar_collapse_ms },
        )
      }
      let target_h = if cur.1 { cur.2 } else { 0.0 }
      if state.extra_target.get() != target_h {
        state.extra_target.set(target_h)
      }
    }
  })
  // (frosted over the messages once they are read, as chat_bar's glass; on the page's ground till then)
  g.glass(By(fn() { if read() { Some(@sf.glass_bar()) } else { None } })) |> ignore
  g.reacts(can_toggle, fn(ok) {
    if !ok && state.manual_expanded.get() {
      state.manual_expanded.set(false)
    }
  })
  g.box(fn(row) {
      row
      .row(Is(true))
      .padding(By(fn() { (4.0, status_top_now(row.window_w()), 16.0, 0.0) }))
      .min_height(By(fn() { Some(status_top_now(row.window_w()) + bar_h) }))
      .lines_up(Is(Some(Middle)))
      |> ignore
      // (newly created from NewChat: keep outer glass stable while inner bar row crossfades in along bar_in)
      if from_fresh {
        row
        .alpha(By(fn() {
          if @sfbase.fresh_active(row) {
            @sfbase.fresh_progress(row, "bar_in")
          } else {
            1.0
          }
        }))
        .offset(By(fn() {
          if @sfbase.fresh_active(row) {
            let p = @sfbase.fresh_progress(row, "bar_in")
            (-6.0 * (1.0 - p), 0.0)
          } else {
            (0.0, 0.0)
          }
        }))
        |> ignore
      }
      // (the find closed, what it marked in the list let go: back, the bar's or the system's, while it is open)
      let find_close = fn() {
        (@sfpages.chat_find_list(r).forget)()
        @sfpages.find_close()
      }
      // back (Chat.kt BarFrame: 40 round, its chevron 22 in the accent's ink): the find closed first while it is open
      @sf.round_key_node(
        row,
        "chevron-left",
        fn() { tr("common.back") },
        fn() {
          if @signals.untracked(finding) {
            find_close()
          } else {
            @sfbase.go_back() |> ignore
          }
        },
        side=40.0,
        icon_size=22.0,
        ink=fn() { @sf.theme().p.accent_text },
      )
      // the title and what follows it, in one row; ⌘F's bar in their place while the find is open and, once it
      // closes, while it fades out as it was (sfdesk's chat_bar_wide_node: the pick's `leave_of`, its way out its
      // own), then they come back faded in over as long
      let back_in = Ref(false)
      row.pick(
        leave_of=fn(was, now) { if was && !now { @sfpages.find_in_ms } else { 0.0 } },
        fn() { finding() },
        fn(e, open) {
          e
          .row(Is(true))
          .grow(Is(1.0))
          .basis(Is(Some(0.0)))
          .shrink(Is(1.0))
          .min_width(Is(Some(0.0)))
          .lines_up(Is(Some(Middle)))
          |> ignore
          if open {
            back_in.val = true
            // (the system's back closes the find, not the chat)
            e.takes_back(find_close) |> ignore
            @sfpages.find_bar_node(
              e,
              src,
              r,
              fn() { view().bind(fn(v) { v.thread }) },
              @sfpages.chat_find_list(r),
              @sf.window_tips(),
            )
            .grow(Is(1.0))
            .basis(Is(Some(0.0)))
            .shrink(Is(1.0))
            .min_width(Is(Some(0.0)))
            |> ignore
          } else {
            if back_in.val {
              back_in.val = false
              e.alpha(By(@motion.presence_in(e, @motion.tween(@sfpages.find_in_ms, ease=Out)))) |> ignore
            }
            // (what moves in the row as 归档 or the services' key comes or goes: laid out at once where the change has
            // them, the people left out of it then or not at that moment alone, what is beside them drawn from where it
            // was to there on archive_tween; what an answer tells at once. The row's own, not the window's: bar_slides)
            let slides = bar_slides(e, fn() { bar_keys_shown(view) })
            let end_arriving = Ref(from_fresh && !@signals.untracked(read))
            bar_middle_node(e, src, r, view, stint, state, expanded, can_toggle, mid_w_sig, slides)
            e.show(read, at_once=true, fn(end) {
              if end_arriving.val {
                end_arriving.val = false
                end.alpha(By(@motion.presence_in(end, @motion.tween(140.0, ease=Out)))) |> ignore
              }
              bar_end_node(end, src, r, view, slides)
            })
          }
        },
      )
    })
    |> ignore
    let openers_now = fn() {
      match view() {
        Some(v) => v.openers
        None => []
      }
    }
    let show_crumb = fn() { !finding() && openers_now().length() > 0 }
    g.reacts(show_crumb, fn(on) {
      if !on && state.crumb_h.get() != 0.0 {
        state.crumb_h.set(0.0)
      }
    })
    g.show(fn() { show_crumb() || expanded() || state.open_way.shown(g) > 0.0 }, at_once=true, fn(extra) {
      extra.show(show_crumb, at_once=true, fn(crumb_host) {
        crumb_host.by_room(fn(cr, rr) {
          let strip = cr.box(fn(s) {
            bar_small_breadcrumb_node(s, openers_now)
          })
          cr.reacts(fn() { rr.tall(strip) }, fn(h) {
            if h > 0.0 && state.crumb_h.get() != h {
              state.crumb_h.set(h)
            }
          })
        })
        |> ignore
      })
      extra.show(fn() { expanded() || state.open_way.shown(extra) > 0.0 }, fn(row2_room) {
        let p = fn() { state.open_way.shown(row2_room) }
        row2_room
        .opens(
          By(fn() {
            let v = p()
            if v >= 1.0 && expanded() {
              None
            } else {
              Some(bar_clamp01(v))
            }
          }),
          from_foot=true,
        )
        .clips(By(fn() { p() < 1.0 }))
        |> ignore
        row2_room.box(fn(row2_pad) {
          row2_pad.padding(Is((0.0, 8.0, 0.0, 0.0))) |> ignore
          row2_pad.box(fn(row2_box) {
            let hp = fn() { state.open_way.shown(row2_box) }
            @sf.presses_node(
              row2_box,
              fn() {
                if expanded() && can_toggle() && hp() >= 1.0 {
                  state.manual_expanded.set(false)
                }
              },
              on=fn() { expanded() && can_toggle() && hp() >= 1.0 },
            )
            row2_box
            .row(Is(true))
            .min_height(By(fn() { if can_toggle() { Some(44.0) } else { None } }))
            .padding(Is((16.0, 0.0, 16.0, 8.0)))
            .lines_up(Is(Some(Middle)))
            .alpha(By(fn() { bar_clamp01((hp() - 0.15) / 0.85) }))
            |> ignore
            row2_box.by_room(fn(p2, rr2) {
              p2.grow(Is(1.0)).basis(Is(Some(0.0))).min_width(Is(Some(0.0))) |> ignore
              let t2 = p2.box(fn(t2) {
                t2
                .words(By(title_now))
                .words_look(By(fn() {
                  let th = @sf.theme()
                  { size: th.t.title, weight: 600, line: chat_title_line, wrap: true, tracking: @view.letters_own, balance: false, max_lines: 0 }
                }))
                .ink(By(fn() { @sf.theme().p.text }))
                |> ignore
              })
              p2.reacts(fn() { (rr2.tall(t2), can_toggle()) }, fn(cur) {
                if cur.0 > 0.0 && (expanded() || state.row2_h.get() <= 0.0) {
                  let box_h = if cur.1 { dmax(44.0, cur.0 + 8.0) } else { cur.0 + 8.0 }
                  state.row2_h.set(8.0 + box_h)
                }
              })
            })
            |> ignore
          })
          |> ignore
        })
        |> ignore
      })
    })
    |> ignore
}

///|
/// What the middle of a chat's bar shows on Small screens, once its view is read (its first five people), and what
/// tells one such from another (`key`). Active agents and station live above the composer (`chat_composer_bar_node`).
priv struct BarMarks {
  key : String
  shown : Array[Person]?
}

///|
impl Eq for BarMarks with equal(a, b) {
  a.key == b.key
}

///|
/// The middle of the bar of chat `r` (its view `view`), in row `row`: its title, kept whole while what follows it may
/// leave the row for it, cut short only once nothing more may; then, once the view is read, its people (leaving the row
/// first when short of room).
fn bar_middle_node(
  row : @view.View,
  src : Source,
  r : ChatRef,
  view : () -> ChatView?,
  stint : () -> Int,
  state : ChatBarState,
  expanded : () -> Bool,
  can_toggle : () -> Bool,
  mid_w_sig : @signals.Signal[Double],
  slides : (@view.View) -> Unit,
) -> Unit {
  let marks = fn() {
    match view() {
      Some(v) => {
        let people = if v.people.length() > 5 { v.people[:5].to_owned() } else { v.people }
        let ps = people.map(fn(p) { "\{p.id}\u{1}\{p.display}\u{1}\{p.picture}" }).join("\u{2}")
        { key: "read\u{3}" + ps, shown: Some(people) }
      }
      None => { key: "", shown: None }
    }
  }
  // (made again as what it shows changes, given what it shows)
  row.pick(marks, fn(mid_outer, marks) {
    mid_outer
    .grow(Is(1.0))
    .basis(Is(Some(0.0)))
    .min_width(Is(Some(0.0)))
    |> ignore
    mid_outer.by_room(fn(mid, mid_room) {
      // (giving way before the title, what follows it leaving the row first: View::drops)
      mid
      .row(Is(true))
      .min_width(Is(Some(0.0)))
      .padding(Is((8.0, 0.0, 8.0, 0.0)))
      .gap(Is(8.0))
      .lines_up(Is(Some(Middle)))
      .fits(Is(true))
      |> ignore
      mid.reacts(fn() { mid_room.width() }, fn(w) {
        if marks.shown is Some(_) && w > 0.0 && mid_w_sig.get() != w {
          mid_w_sig.set(w)
        }
      })
      mid.box(fn(t_box) {
        let tp = fn() { state.open_way.shown(t_box) }
        @sf.presses_node(
          t_box,
          fn() {
            if !expanded() && can_toggle() && tp() <= 0.0 {
              state.manual_expanded.set(true)
            }
          },
          on=fn() { !expanded() && can_toggle() && tp() <= 0.0 },
        )
        t_box
        .lies_along(Is(Middle))
        .fit_whole(By(fn() { !expanded() }))
        .grow(By(fn() { if expanded() { 1.0 } else { 0.0 } }))
        .basis(By(fn() { if expanded() { Some(0.0) } else { None } }))
        .cuts(Is(true))
        .min_width(Is(Some(0.0)))
        .min_height(By(fn() { if !expanded() && can_toggle() && tp() <= 0.0 { Some(44.0) } else { None } }))
        .alpha(By(fn() { bar_clamp01(1.0 - tp() / 0.45) }))
        .offset(By(fn() { (0.0, 5.0 * bar_clamp01(tp() / 0.5)) }))
        |> ignore
        t_box.box(fn(t) {
          t
          .words(By(fn() {
            match view() {
              Some(v) => v.title
              None => r.title
            }
          }))
          .words_look(By(fn() {
            let th = @sf.theme()
            { size: th.t.title, weight: 600, line: chat_title_line, wrap: false, tracking: @view.letters_own, balance: false, max_lines: 0 }
          }))
          .ink(By(fn() { @sf.theme().p.text }))
          .fit_whole(By(fn() { !expanded() }))
          .cuts(Is(true))
          .allow_ellipsis(Is(true))
          .min_width(Is(Some(0.0)))
          |> ignore
        })
        |> ignore
      })
      |> ignore
      guard marks.shown is Some(people) else { return }
      if people.length() > 0 {
        let p = @sf.avatar_stack_node(mid, stack_faces(src, people, stint), 16.0, fn() { @sf.theme().p.bg })
        p.drops(Is(bar_drop_people)).laid_nowhere(By(expanded)) |> ignore
        slides(p)
      }
    })
    |> ignore
  })
}

///|
/// What slides along row `row` of a chat's bar as what `by` reads changes (归档, the services' key): each part said
/// of it (the function given back) drawn from where it was drawn as the change came to where the change lays it out,
/// on archive_tween from the change's moment, while it takes room in the row before and after; laid out at once all
/// the same. What comes or goes itself (a part with no room on one side of the change) fades where it stands, its own.
/// What an answer tells, at once. Where each is drawn as the change comes: on its way, where its way set out from (where
/// the change before laid it out) and how far off that it is then, whether or not a frame drew it there yet (one turned
/// back between frames is drawn from where it was on its way, not from where the frame before drew it plus that way);
/// at rest, where it was placed (as its last frame drew it). Once the change is told whole (every structure it changes
/// made or let go), where it lays it out: the row's own, nothing laid out for the rest of the window as its changes come
/// (as Moves' laid_before_causes would).
fn[T : Eq] bar_slides(row : @view.View, by : () -> T) -> (@view.View) -> Unit {
  // (each part, its way, where the change that set it off laid it out, and whether drawn_off is bound yet)
  let parts : Array[(@view.View, @motion.NodeWay, Ref[Double], Ref[Bool])] = []
  row.reacts(by, at_start=false, fn(_) {
    guard !@view.answering_now() else { return }
    let at = row.cause_at()
    let was = parts
      .filter(fn(p) { p.0.alive() && p.0.was_placed() })
      .map(fn(p) {
        let (x, _, w, _) = p.0.placed_window_now()
        let drawn = if p.1.goes_at(at) { p.2.val + p.1.value_at(at) } else { x }
        (p.0, p.1, p.2, p.3, drawn, w)
      })
    @signals.after_flush(fn() {
      for q in was {
        let (v, way, ground, bound, was_x, was_w) = q
        guard v.alive() else { continue }
        let (now_x, _, now_w, _) = v.laid_window_now()
        if was_w > 0.5 && now_w > 0.5 {
          ground.val = now_x
          // (drawn where it is laid out already, as when a change turned back at once: what was left of the way
          // before is let go of, not drawn on past where it is)
          if (was_x - now_x).abs() > 0.5 {
            if !bound.val {
              bound.val = true
              v.drawn_off(By(fn() { (way.shown(v), 0.0) })) |> ignore
            }
            way.put_at(v, was_x - now_x, 0.0, archive_tween, at)
          } else {
            way.put(0.0)
          }
        }
      }
    })
  })
  fn(v) {
    let way = @motion.NodeWay::new(0.0)
    parts.push((v, way, Ref(0.0), Ref(false)))
    v.owns(fn() {
      way.stop()
      match parts.search_by(fn(p) { physical_equal(p.0, v) }) {
        Some(i) => parts.remove(i) |> ignore
        None => ()
      }
    })
    |> ignore
    v.carries_until(fn() { way.ends_at() }) |> ignore
  }
}

///|
/// Whether a chat's bar shows 归档 (nothing left in it), its view `view` as it is now.
fn bar_archivable(view : () -> ChatView?) -> Bool {
  match view() {
    Some(v) => v.archivable && !v.archived
    None => false
  }
}

///|
/// Whether a chat has services or jobs (its bar's key to them), its jobs' summary `jobs` as the core says it.
fn bar_has_jobs(jobs : () -> Json?) -> Bool {
  let j = jobs()
  flag(j, "hasJobs") || items(j, "jobs").length() > 0
}

///|
/// What of chat `r`'s bar's end is shown on Small screens: none before the view is read; once it is, 归档 while it is.
fn bar_keys_shown(view : () -> ChatView?) -> (Bool, Bool) {
  match view() {
    Some(_) => (true, bar_archivable(view))
    None => (false, false)
  }
}

///|
/// At the end of chat `r`'s bar (its view `view`, read), in `e`: 归档 while nothing is left in it, what it is (ⓘ) and
/// "…"; each drawn on its way from where it was as 归档 comes or goes (`slides`). Active jobs, screen and sub-chats
/// live above the composer (`chat_composer_bar_node`).
fn bar_end_node(
  e : @view.View,
  src : Source,
  r : ChatRef,
  view : () -> ChatView?,
  slides : (@view.View) -> Unit,
) -> Unit {
  e.row(Is(true)).lines_up(Is(Some(Middle))) |> ignore
  // (its "…" is its chat's whole row's: held while its page is open (let go of as it is left, chat_left), asked as it
  // opens: @sfpages.chat_menu_of)
  @signals.untracked(fn() { @sfbase.chat_whole_held(src, r) }) |> ignore
  let archivable = fn() { bar_archivable(view) }
  let doing_key = "archive/" + r.station + "/" + r.session
  e.box(fn(k) {
    // (there as it is made where it is so; set off as it becomes so or stops, at that cause's moment: reacts' first
    // run, as it is made, goes nowhere, the way already there). Its room laid out at once as it becomes so or stops
    // (what is beside it drawn on its way there: `slides`); its button at its room's end, so where it stood as the room
    // goes, fading out there over what comes into it, fading in where it comes
    let share = @motion.NodeWay::new(if @signals.untracked(archivable) { 1.0 } else { 0.0 })
    k.reacts(archivable, fn(on) {
      if @view.answering_now() {
        share.put(if on { 1.0 } else { 0.0 })
      } else {
        share.go_ms(k, if on { 1.0 } else { 0.0 }, @sf.dur_ms)
      }
    })
    slides(k)
    let s = fn() { share.shown(k) }
    k
    .row(Is(true))
    .width(By(fn() { Some(if archivable() { nav_key_side + bar_keys_apart() } else { 0.0 }) }))
    .lies_along(Is(End))
    .laid_nowhere(By(fn() { s() <= 0.0 && !archivable() }))
    |> ignore
    k.box(fn(b) {
      b
      .width(Is(Some(nav_key_side)))
      .min_width(Is(Some(nav_key_side)))
      .height(Is(Some(nav_key_side)))
      .lines_up(Is(Some(Middle)))
      .lies_along(Is(Middle))
      .alpha(By(s))
      .presses(By(archivable))
      |> ignore
      b.pick(at_once=true, fn() { @sfbase.doing(doing_key) }, fn(slot, is_doing) {
        if is_doing {
          @sf.spinner_node(slot) |> ignore
        } else {
          @sf.round_key_node(
            slot,
            "archive",
            fn() { tr("android-chat.archive") },
            // (the chat's view as it is at the press)
            fn() {
              match view() {
                Some(v) if v.archivable && !v.archived => archive_chat(src, r, v)
                _ => ()
              }
            },
            icon_size=20.0,
          )
        }
      })
    })
    |> ignore
  })
  |> ignore
  // what it is (its info's sheet), then what is done with it ("…": the menu a row of the list has)
  e.box(fn(k) {
    slides(k)
    k.row(Is(true)).padding(By(fn() { (bar_keys_apart(), 0.0, 0.0, 0.0) })) |> ignore
    @sf.round_key_node(k, "info", fn() { tr("android-chat.info.title") }, fn() { open_info(src, r) }, icon_size=20.0)
  })
  |> ignore
  e.box(fn(k) {
    slides(k)
    k.row(Is(true)).padding(By(fn() { (bar_keys_apart(), 0.0, 0.0, 0.0) })) |> ignore
    @sf.round_key_node(
      k,
      "more",
      fn() { tr("common.more") },
      fn() {
        let w = match workspace_in_view(src).0 {
          Some(w) => w.id
          None => ""
        }
        let chat = src.topic("chat", chat_params(r)).get().value
        let (x, y, mw, mh) = k.placed_window_now()
        @sfpages.open_chat_menu(src, w, r, @sfpages.chat_extra_items(src, r, chat), from=At(x, y, mw, mh))
      },
      icon_size=18.0,
    )
  })
  |> ignore
}

///|
/// The station's tag above the composer while no agent is in the chat (station_chip's, as nodes): a tap opens its card.
fn station_chip_node(
  v : @view.View,
  address : String,
  s : Station,
  via : () -> String,
  stint : () -> Int,
) -> Unit {
  v.box(fn(k) {
    @sf.presses_node(k, fn() {
      let (x, y, w, h) = k.placed_window_now()
      @settings.open_station_peek(address, from=At(x, y, w, h))
    })
    k
    .row(Is(true))
    .min_height(Is(Some(44.0)))
    .lines_up(Is(Some(Middle)))
    .says(Is(Some(@view.said(Group, label=s.name))))
    |> ignore
    k.box(fn(pill) {
      pill
      .row(Is(true))
      .min_height(Is(Some(mark_side())))
      .max_width(Is(Some(104.0)))
      .padding(By(fn() { (if via() != "" { station_dot_in } else { station_tag_end }, 2.0, station_tag_end, 2.0) }))
      .gap(Is(4.0))
      .radius(Is(6.0))
      .ground(By(fn() { mark_ground().0 }))
      .edge(By(fn() { (mark_ground().1, @sf.theme().p.line) }))
      .lines_up(Is(Some(Middle)))
      |> ignore
      pill.show(fn() { via() != "" }, along_row=true, fn(d) { via_dot_in(d, via, via_dot_side, 0.0) })
      if @sf.has_station_mark(s.emoji, s.icon) {
        @sf.station_mark_node(pill, fn() { s.emoji }, fn() { s.icon }, 12.0, fn() { @sf.theme().p.muted }, stint)
      }
      pill.box(fn(t) {
        t
        .words(Is(s.name))
        .words_look(By(fn() {
          { size: @sf.theme().t.caption, weight: 400, line: 16.0, wrap: false, tracking: @view.letters_own, balance: false, max_lines: 0 }
        }))
        .ink(By(fn() { @sf.theme().p.muted }))
        .cuts(Is(true))
        .min_width(Is(Some(0.0)))
        |> ignore
      })
      |> ignore
    })
    |> ignore
  })
  |> ignore
}

///|
/// Node `d` drawn as how a station is reached, a dot (via_dot's, as a node), `size` across, ringed `ring` in the page's
/// ground, its colour following `via` in place.
fn via_dot_in(d : @view.View, via : () -> String, size : Double, ring : Double) -> Unit {
  let inner = size - ring * 2.0
  d
  .width(Is(Some(size)))
  .height(Is(Some(size)))
  .radius(Is(size / 2.0))
  .lines_up(Is(Some(Middle)))
  .lies_along(Is(Middle))
  .row(Is(true))
  .ground(By(fn() { if ring > 0.0 { @sf.theme().p.bg } else { 0L } }))
  |> ignore
  d.box(fn(i) {
    i
    .width(Is(Some(inner)))
    .height(Is(Some(inner)))
    .radius(Is(inner / 2.0))
    .ground(By(fn() {
      let p = @sf.theme().p
      match via() {
        "direct" => p.online
        "relay" => 0xD9962BFFL
        "offline" => p.red
        _ => p.muted
      }
    }))
    |> ignore
  })
  |> ignore
}

///|
/// `people` as the faces of a stack (@sf.avatar_stack_node's): their pictures as the core gives them (Source.picture)
/// on the time on top of the page they are on (`stint`).
fn stack_faces(src : Source, people : Array[Person], stint : () -> Int) -> Array[@sf.StackFace] {
  people.map(fn(p) {
    {
      id: p.id,
      name: p.display,
      pictured: p.picture != "",
      picture: fn() { if p.picture != "" { (src.picture)(p.picture, stint()) } else { "" } },
    }
  })
}

///|
/// An agent's mark in the bar (model_mark's, as nodes), `size` square: its maker's mark on a soft tile, its state on
/// the corner.
fn model_mark_node(v : @view.View, a : Agent, badge : () -> String, size : Double) -> Unit {
  v.box(fn(m) {
    m.width(Is(Some(size))).height(Is(Some(size))) |> ignore
    mark_tile_node(m, a, size)
    badge_slot_node(m, badge, size)
  })
  |> ignore
}

///|
/// An agent's state on the corner of its `size` mark in `m`, drawn again in place as `badge` changes: over the mark,
/// as big as it, so it moves nothing beside it.
fn badge_slot_node(m : @view.View, badge : () -> String, size : Double) -> Unit {
  // (the pick's own node the badge itself, none round it; none made while it has none, as most marks have, till it
  // first comes to one)
  @sfpages.agent_badge_slot(m, badge, size)
}

///|
/// The maker's tile of an agent's mark, `size` square, its maker's mark in its middle.
fn mark_tile_node(v : @view.View, a : Agent, size : Double) -> Unit {
  v.box(fn(t) {
    t
    .width(Is(Some(size)))
    .height(Is(Some(size)))
    .radius(Is(mark_corner(size)))
    .ground(By(fn() { mark_ground().0 }))
    .edge(By(fn() { (mark_ground().1, @sf.theme().p.line) }))
    .row(Is(true))
    .lines_up(Is(Some(Middle)))
    .lies_along(Is(Middle))
    |> ignore
    @sf.maker_mark_node(t, a.maker, a.runtime, mark_logo(size)) |> ignore
  })
  |> ignore
}

///|
/// The chat's first agent with the station it runs on, one tile (agent_station_mark's, as nodes): the maker's square,
/// then the station's mark or name; the agent's state on the maker's corner, how the station is reached on the tile's.
/// Until the station is known, the agent's mark alone.
fn agent_station_node(
  v : @view.View,
  a : Agent,
  badge : () -> String,
  station : Station?,
  via : () -> String,
  stint : () -> Int,
) -> Unit {
  let m = mark_side()
  match station {
    None => model_mark_node(v, a, badge, m)
    Some(s) => {
      v.box(fn(tile) {
        tile
        .row(Is(true))
        .height(Is(Some(m)))
        .radius(Is(6.0))
        .ground(By(fn() { mark_ground().0 }))
        .edge(By(fn() { (mark_ground().1, @sf.theme().p.line) }))
        .lines_up(Is(Some(Middle)))
        |> ignore
        tile.box(fn(mk) {
          mk.width(Is(Some(m))).height(Is(Some(m))).row(Is(true)).lines_up(Is(Some(Middle))).lies_along(Is(Middle))
          |> ignore
          @sf.maker_mark_node(mk, a.maker, a.runtime, mark_logo(m)) |> ignore
        })
        |> ignore
        // the station's part: its mark, or its name kept short
        let (most, inside, said_line) = station_part_type()
        tile.box(fn(sp) {
          sp.max_width(Is(Some(most))).padding(Is((inside, 0.0, inside, 0.0))).row(Is(true)).lines_up(Is(Some(Middle)))
          |> ignore
          if @sf.has_station_mark(s.emoji, s.icon) {
            @sf.station_mark_node(sp, fn() { s.emoji }, fn() { s.icon }, mark_station(), fn() { @sf.theme().p.muted }, stint)
          } else {
            sp.box(fn(t) {
              t
              .words(Is(s.name))
              .words_look(By(fn() {
                { size: @sf.theme().t.caption, weight: 400, line: said_line, wrap: false, tracking: @view.letters_own, balance: false, max_lines: 0 }
              }))
              .ink(By(fn() { @sf.theme().p.muted }))
              .cuts(Is(true))
              .min_width(Is(Some(0.0)))
              |> ignore
            })
            |> ignore
          }
        })
        |> ignore
        tile.box(fn(over) {
          over.over(Is(true)) |> ignore
          badge_slot_node(over, badge, m)
          over.show(at_once=true, fn() { via() != "" }, fn(d) {
            d.over(Is(true)).lines_up(Is(Some(End))) |> ignore
            d.box(fn(at) {
              at.offset(Is((3.0, m - 7.0))) |> ignore
              via_dot_in(at, via, 10.0, 2.0)
            })
            |> ignore
          })
        })
        |> ignore
      })
      |> ignore
    }
  }
}

///|
/// Compact single-row led ancestor breadcrumb strip under Row 1 on Small screens:
/// 1-2 ancestors shown directly, 3+ ancestors collapse middle items into a `…` menu.
/// Touch target height >= 44pt so every link passes `room_faults`.
fn bar_small_breadcrumb_node(s : @view.View, openers : () -> Array[@sfbase.Opener]) -> Unit {
  let key_of = fn() {
    openers().map(fn(o) { "\{o.chat.station}\u{1}\{o.chat.session}\u{1}\{o.chat.title}\u{1}\{o.archived}" }).join("\u{2}")
  }
  s
  .row(Is(true))
  .padding(Is((16.0, 0.0, 16.0, 0.0)))
  .gap(Is(4.0))
  .lines_up(Is(Some(Middle)))
  .min_height(Is(Some(44.0)))
  |> ignore
  @sf.icon_node(s, "spawned", 14.0, By(fn() { @sf.theme().p.muted })) |> ignore
  s.pick(at_once=true, key_of, fn(bc, _) {
    bc.row(Is(true)).grow(Is(1.0)).basis(Is(Some(0.0))).min_width(Is(Some(0.0))).gap(Is(2.0)).lines_up(Is(Some(Middle)))
    |> ignore
    let list = @signals.untracked(openers)
    let n = list.length()
    guard n > 0 else { return }
    let crumb_item = fn(p : @view.View, o : @sfbase.Opener) {
      @sf.action_box_node(p, fn() { o.chat.title }, fn(_) { @sfbase.open_page(Chat(o.chat)) }, fn(b) {
        b
        .row(Is(true))
        .min_height(Is(Some(44.0)))
        .min_width(Is(Some(44.0)))
        .max_width(Is(Some(140.0)))
        .padding(Is((6.0, 0.0, 6.0, 0.0)))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(Middle))
        .radius(Is(8.0))
        |> ignore
        @sf.hover_ground_node(b)
        @sf.focus_ring_node(b)
        @sf.words_node(b, fn() { o.chat.title }, fn() {
          if @sf.lit_node(b) {
            small_crumb_words_hot
          } else {
            small_crumb_words
          }
        })
        .allow_ellipsis(Is(true))
        .min_width(Is(Some(0.0)))
        |> ignore
      })
      .says(Is(Some(@view.said(Link, label=o.chat.title))))
      |> ignore
    }
    let chevron = fn(p : @view.View) {
      @sf.icon_node(p, "chevron-right", 12.0, By(fn() { @sf.theme().p.subtle })) |> ignore
    }
    if n <= 2 {
      for i, o in list {
        if i > 0 {
          chevron(bc)
        }
        crumb_item(bc, o)
      }
    } else {
      crumb_item(bc, list[0])
      chevron(bc)
      let middle = list[1:n - 1].to_owned()
      let more_ref : Ref[@view.View?] = Ref(None)
      let more_btn = @sf.action_box_node(bc, fn() { @sf.t("web-pages.chat.breadcrumbMore") }, fn(_) {
        let items : Array[@sf.MenuItem?] = middle.map(fn(o) {
          let label = if o.archived && o.note != "" { o.chat.title + " (" + o.note + ")" } else { o.chat.title }
          Some(@sf.menu_item_of(label, icon="spawned", fn() { @sfbase.open_page(Chat(o.chat)) }))
        })
        match more_ref.val {
          Some(at) => @sf.menu(items, from=Node(at))
          None => ()
        }
      }, fn(b) {
        b
        .row(Is(true))
        .min_height(Is(Some(44.0)))
        .min_width(Is(Some(44.0)))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(Middle))
        .radius(Is(8.0))
        |> ignore
        @sf.hover_ground_node(b)
        @sf.focus_ring_node(b)
        @sf.icon_node(b, "more", 14.0, By(fn() { if @sf.lit_node(b) { @sf.theme().p.text } else { @sf.theme().p.muted } }))
        |> ignore
      })
      more_ref.val = Some(more_btn)
      chevron(bc)
      crumb_item(bc, list[n - 1])
    }
  })
}

///|
// kept across runs: a value (no field of it changes)
let small_crumb_words : @ui.TextStyle = @ui.text_style(size=Meta, color=Muted, wrap=false, w=Cut)

///|
// kept across runs: a value (no field of it changes)
let small_crumb_words_hot : @ui.TextStyle = @ui.text_style(size=Meta, color=Fg, wrap=false, w=Cut)

///|
// kept across runs: a value (no field of it changes)
let small_composer_pill_words : @ui.TextStyle = @ui.text_style(size=Meta, color=Fg, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let small_composer_pill_count : @ui.TextStyle = @ui.text_style(size=Meta, weight=Medium, color=Muted, wrap=false, tabular=true)

///|
/// Active controls strip directly above the composer on Small screens:
/// - Left: frequent controls (Agent + Station pills, or Station chip when no agent)
/// - Right: live/active controls (Active Jobs, Driven Screen, Led Sub-chats), grouped under a single `show` so
///   ordinary chats with none pay at most one idle slot node.
fn chat_composer_bar_node(o : @view.View, src : Source, r : ChatRef, stint : () -> Int) -> Unit {
  let view = fn() { @sfbase.chat_view_now(src, r) }
  let station_held = @sfbase.station_mark_held(src, r.station)
  let station_now = fn() { station_held.get() }
  let jobs_held = @sfbase.topic_value_held(src, "chatJobs", chat_jobs_summary_params(r))
  let jobs = fn() { jobs_held.get() }
  let via = fn() {
    let w = match workspace_in_view(src).0 {
      Some(w) => w.id
      None => ""
    }
    match station_marks(src, w).iter().find_first(fn(s) { s.address == r.station }) {
      Some(s) => s.via
      None => ""
    }
  }
  let badge_of = fn(key : String) {
    fn() {
      match view() {
        Some(v) =>
          match v.agents.iter().find_first(fn(x) { x.key == key }) {
            Some(x) => x.badge
            None => ""
          }
        None => ""
      }
    }
  }
  let has_jobs = fn() { bar_has_jobs(jobs) }
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
  let has_left = fn() {
    match view() {
      Some(v) => v.agents.length() > 0 || station_now() is Some(_)
      None => false
    }
  }
  let has_right = fn() { has_jobs() || driven() || has_subchats() }
  let has_any = fn() { view() is Some(_) && (has_left() || has_right()) }
  o
  .row(Is(true))
  .lines_up(Is(Some(Middle)))
  .lies_along(Is(Between))
  .gap(Is(8.0))
  .padding(Is((10.0, 0.0, 10.0, 0.0)))
  .ground(By(fn() { @sf.theme().p.bg }))
  .laid_nowhere(By(fn() { !has_any() }))
  |> ignore
  o.box(fn(left) {
    left.row(Is(true)).gap(Is(6.0)).lines_up(Is(Some(Middle))).shrink(Is(1.0)).min_width(Is(Some(0.0))) |> ignore
    let agents = fn() {
      match view() {
        Some(v) => v.agents
        None => []
      }
    }
    left.each(
      at_once=true,
      fn() {
        let ags = agents()
        if ags.length() > 0 {
          ags.mapi(fn(i, ag) { (i, Some(ag)) })
        } else if view() is Some(_) && station_now() is Some(_) {
          [(-1, None)]
        } else {
          []
        }
      },
      fn(p) {
        match p.1 {
          Some(ag) => {
            let s = if p.0 == 0 {
              match station_now() {
                Some(st) => "\{st.name}\u{1}\{st.emoji}\u{1}\{st.icon}"
                None => ""
              }
            } else {
              ""
            }
            "a\u{1}\{p.0}\u{1}\{ag.key}\u{1}\{ag.maker}\u{1}\{ag.runtime}\u{1}\{ag.who}\u{1}\{s}"
          }
          None =>
            match station_now() {
              Some(st) => "s\u{1}\{st.name}\u{1}\{st.emoji}\u{1}\{st.icon}"
              None => "s"
            }
        }
      },
      fn(slot, p) {
        let (i, ag_opt) = p.untracked()
        let station = @signals.untracked(station_now)
        match ag_opt {
          None =>
            match station {
              Some(s) => station_chip_node(slot, r.station, s, via, stint)
              None => ()
            }
          Some(ag) => {
            let key = ag.key
            let label = match station {
              Some(s) if i == 0 => ag.who + " · " + s.name
              _ => ag.who
            }
            @sf.action_box_node(slot, fn() { label }, label_is=label, fn(_) { open_agent(src, r, key) }, fn(k) {
              k
              .row(Is(true))
              .min_height(Is(Some(44.0)))
              .min_width(Is(Some(44.0)))
              .lines_up(Is(Some(Middle)))
              .lies_along(Is(Start))
              |> ignore
              if i == 0 {
                agent_station_node(k, ag, badge_of(key), station, via, stint)
              } else {
                model_mark_node(k, ag, badge_of(key), mark_side())
              }
            })
            |> ignore
          }
        }
      },
    )
  })
  |> ignore
  o.show(has_right, at_once=true, fn(right) {
    right.row(Is(true)).gap(Is(6.0)).lines_up(Is(Some(Middle))).shrink(Is(0.0)) |> ignore
    right.show(has_jobs, at_once=true, fn(j_slot) {
      let alarm = fn() { text(jobs(), "alarm") }
      @sf.action_box_node(j_slot, fn() { tr("android-misc.jobs.title") }, fn(_) { open_chat_jobs(src, r) }, fn(k) {
        k
        .row(Is(true))
        .min_height(Is(Some(44.0)))
        .min_width(Is(Some(44.0)))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(End))
        |> ignore
        k.box(fn(pill) {
          pill
          .row(Is(true))
          .min_height(Is(Some(mark_side())))
          .padding(Is((8.0, 2.0, 8.0, 2.0)))
          .gap(Is(5.0))
          .radius(Is(6.0))
          .ground(By(fn() { mark_ground().0 }))
          .edge(By(fn() { (mark_ground().1, @sf.theme().p.line) }))
          .lines_up(Is(Some(Middle)))
          .lies_along(Is(Middle))
          |> ignore
          @sf.icon_node(pill, "web", 14.0, By(fn() { @sf.theme().p.muted })) |> ignore
          pill.show(fn() { alarm() == "fail" || alarm() == "restart" }, at_once=true, fn(d) {
            d
            .width(Is(Some(6.0)))
            .height(Is(Some(6.0)))
            .radius(Is(3.0))
            .ground(By(fn() { if alarm() == "fail" { @sf.theme().p.red } else { @ui.tree_theme().color(Warn) } }))
            |> ignore
          })
        })
        |> ignore
      })
      |> ignore
    })
    right.show(driven, at_once=true, fn(s_slot) {
      @sf.action_box_node(s_slot, fn() { @sf.t("web-pages.chat.screen") }, fn(at) {
        match @signals.untracked(view) {
          Some(v) => chat_remote_open(src, r, v, from=Node(at), along=End)
          None => ()
        }
      }, fn(k) {
        k
        .row(Is(true))
        .min_height(Is(Some(44.0)))
        .min_width(Is(Some(44.0)))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(End))
        |> ignore
        k.box(fn(pill) {
          pill
          .row(Is(true))
          .min_height(Is(Some(mark_side())))
          .padding(Is((8.0, 2.0, 8.0, 2.0)))
          .gap(Is(5.0))
          .radius(Is(6.0))
          .ground(By(fn() { mark_ground().0 }))
          .edge(By(fn() { (mark_ground().1, @sf.theme().p.line) }))
          .lines_up(Is(Some(Middle)))
          .lies_along(Is(Middle))
          |> ignore
          @sf.icon_node(pill, "monitor", 14.0, By(fn() { @sf.theme().p.muted })) |> ignore
          pill.box(fn(d) {
            d
            .width(Is(Some(6.0)))
            .height(Is(Some(6.0)))
            .radius(Is(3.0))
            .ground(By(fn() { @sf.theme().p.primary }))
            |> ignore
          })
          |> ignore
        })
        |> ignore
      })
      |> ignore
    })
    right.show(has_subchats, at_once=true, fn(sc_slot) {
      let tone = fn() {
        match view() {
          Some(v) => @sfpages.opened_summary_tone(v.opened)
          None => ""
        }
      }
      @sf.action_box_node(sc_slot, fn() { @sf.t("web-pages.chat.subchats") }, fn(_) { open_subchats(src, r) }, fn(k) {
        k
        .row(Is(true))
        .min_height(Is(Some(44.0)))
        .min_width(Is(Some(44.0)))
        .lines_up(Is(Some(Middle)))
        .lies_along(Is(End))
        |> ignore
        k.box(fn(pill) {
          pill
          .row(Is(true))
          .min_height(Is(Some(mark_side())))
          .padding(Is((8.0, 2.0, 8.0, 2.0)))
          .gap(Is(5.0))
          .radius(Is(6.0))
          .ground(By(fn() { mark_ground().0 }))
          .edge(By(fn() { (mark_ground().1, @sf.theme().p.line) }))
          .lines_up(Is(Some(Middle)))
          .lies_along(Is(Middle))
          |> ignore
          @sf.icon_node(pill, "spawned", 14.0, By(fn() { @sf.theme().p.muted })) |> ignore
          @sf.words_node(pill, fn() { @sf.t("web-pages.chat.subchats") }, fn() { small_composer_pill_words }) |> ignore
          @sf.words_node(pill, fn() { led_subchats().length().to_string() }, fn() { small_composer_pill_count }) |> ignore
          pill.show(fn() { tone() != "" }, at_once=true, fn(d) {
            d
            .width(Is(Some(6.0)))
            .height(Is(Some(6.0)))
            .radius(Is(3.0))
            .ground(By(fn() {
              match tone() {
                "fail" => @sf.theme().p.red
                "need" => @ui.tree_theme().color(Warn)
                _ => @sf.theme().p.online
              }
            }))
            |> ignore
          })
        })
        |> ignore
      })
      |> ignore
    })
  })
}
