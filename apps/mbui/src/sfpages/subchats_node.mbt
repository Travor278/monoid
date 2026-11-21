// Shared sub-chats list (led child chats from `chat_create for: "me"`) rendered as nodes for the Medium/Large
// popover, the right side-panel `subchats` tab, and the Small bottom sheet.

///|
/// Only the chats this chat's agent leads (`led == true`): chats opened for a person (`for: "person"`) are excluded.
pub fn led_subchats(opened : Array[@sfbase.OpenedChat]) -> Array[@sfbase.OpenedChat] {
  opened.filter(fn(o) { o.led })
}

///|
/// Highest-priority status tone across led sub-chats for the bar entry dot: `"fail"` > `"need"` > `"run"` > `""`.
pub fn opened_summary_tone(opened : Array[@sfbase.OpenedChat]) -> String {
  let mut has_need = false
  let mut has_run = false
  for o in opened {
    if !o.led || o.archived {
      continue
    }
    if o.mark == "failed" {
      return "fail"
    }
    if o.state_lead is ("need" | "decision") || o.mark == "block" {
      has_need = true
    } else if o.mark == "run" {
      has_run = true
    }
  }
  if has_need {
    "need"
  } else if has_run {
    "run"
  } else {
    ""
  }
}

///|
/// Shared sub-chats list in `v`: optional header with live running/waiting counts (separate nodes, never `·`-joined),
/// active sub-chats first and archived sub-chats under a section heading when present, optional footer action to open
/// the right side-panel `subchats` tab (`in_panel`).
pub fn subchats_list_node(
  v : @view.View,
  opened : () -> Array[@sfbase.OpenedChat],
  close? : () -> Unit,
  in_panel? : () -> Unit,
  show_head? : Bool = true,
) -> Unit {
  let subchats = fn() { led_subchats(opened()) }
  let active = fn() { subchats().filter(fn(o) { !o.archived }) }
  let archived = fn() { subchats().filter(fn(o) { o.archived }) }
  let running_count = fn() {
    let mut n = 0
    for o in active() {
      if o.mark == "run" {
        n += 1
      }
    }
    n
  }
  let need_count = fn() {
    let mut n = 0
    for o in active() {
      if o.state_lead is ("need" | "decision") || o.mark == "block" {
        n += 1
      }
    }
    n
  }
  if show_head {
    v.box(fn(head) {
      @sf.style_node(head, fn() { subchats_head })
      @sf.words_node(head, fn() { @sf.t("web-pages.chat.subchats") }, fn() { subchats_head_title }) |> ignore
      head.box(fn(counts) {
        @sf.style_node(counts, fn() { subchats_counts }, in_row=true)
        counts.show(at_once=true, fn() { running_count() > 0 }, fn(rn) {
          @sf.words_node(
            rn,
            fn() { @sf.t("web-pages.chat.subchatsRunning", args=[("n", running_count().to_string())]) },
            fn() { subchats_count_words },
          )
          .ink(By(fn() { @sf.theme().p.green_ink }))
          |> ignore
        })
        counts.show(at_once=true, fn() { need_count() > 0 }, fn(nn) {
          @sf.words_node(
            nn,
            fn() { @sf.t("web-pages.chat.subchatsNeed", args=[("n", need_count().to_string())]) },
            fn() { subchats_count_words },
          )
          .ink(By(fn() { @sf.theme().p.warn_ink }))
          |> ignore
        })
      })
      |> ignore
    })
    |> ignore
  }
  v.pick(at_once=true, fn() { subchats().length() == 0 }, fn(body, empty) {
    if empty {
      body.box(fn(e) {
        @sf.style_node(e, fn() { subchats_empty })
        @sf.words_node(e, fn() { @sf.t("web-pages.chat.subchatsNone") }, fn() { subchats_empty_words }) |> ignore
      })
      |> ignore
      return
    }
    let key_of = fn(o : @sfbase.OpenedChat) { o.chat.station + "\u{1}" + o.chat.session }
    let by_key = body.keyed_by(subchats, key_of)
    body.box(fn(list) {
      @sf.style_node(list, fn() { subchats_list })
      list.show(at_once=true, fn() { active().length() > 0 }, fn(g) {
        @sf.style_node(g, fn() { subchats_group })
        g.each(fn() { active().map(key_of) }, fn(k) { k }, fn(row, k) {
          let id = k.untracked()
          subchat_row_node(row, fn() { by_key.get(id) }, close?=close)
        })
      })
      list.show(at_once=true, fn() { archived().length() > 0 }, fn(g) {
        @sf.style_node(g, fn() {
          if active().length() > 0 {
            subchats_group_spaced
          } else {
            subchats_group
          }
        })
        g.box(fn(h) {
          @sf.style_node(h, fn() { subchats_section_head })
          @sf.words_node(h, fn() { @sf.t("web-pages.chat.subchatsArchived") }, fn() { subchats_section_words }) |> ignore
        })
        |> ignore
        g.each(fn() { archived().map(key_of) }, fn(k) { k }, fn(row, k) {
          let id = k.untracked()
          subchat_row_node(row, fn() { by_key.get(id) }, close?=close)
        })
      })
    })
    |> ignore
  })
  match in_panel {
    Some(open_panel) =>
      v.show(at_once=true, fn() { subchats().length() > 0 }, fn(foot) {
        @sf.style_node(foot, fn() { subchats_foot })
        foot.box(fn(l) { @sf.style_node(l, fn() { subchats_divider }) }) |> ignore
        let words = fn() { @sf.t("web-main.jobs.inPanel") }
        @sf.action_box_node(foot, words, fn(_) { open_panel() }, fn(b) {
          @sf.style_node(b, fn() { subchats_foot_btn.then(subchats_round) }, in_row=true)
          @sf.hover_ground_node(b)
          @sf.focus_ring_node(b)
          @sf.icon_node(b, "panel-open", 14.0, By(fn() { if @sf.lit_node(b) { @sf.theme().p.text } else { @sf.theme().p.muted } }))
          |> ignore
          @sf.words_node(b, words, fn() { if @sf.lit_node(b) { subchats_foot_hot } else { subchats_foot_words } }) |> ignore
        })
        |> ignore
      })
    None => ()
  }
}

///|
/// A single sub-chat row: first-line aligned status mark, title + optional state summary, first-line aligned chevron.
fn subchat_row_node(row : @view.View, item : () -> @sfbase.OpenedChat?, close? : () -> Unit) -> Unit {
  let title = fn() {
    match item() {
      Some(o) => o.chat.title
      None => ""
    }
  }
  let state_text = fn() {
    match item() {
      Some(o) => o.state_text
      None => ""
    }
  }
  let is_archived = fn() {
    match item() {
      Some(o) => o.archived
      None => false
    }
  }
  // 0: run dot, 1: need dot, 2: fail dot, 3: archived icon, 4: done icon, 5: spawned icon
  let mark_kind = fn() {
    match item() {
      Some(o) =>
        if o.archived {
          3
        } else if o.mark == "failed" {
          2
        } else if o.state_lead is ("need" | "decision") || o.mark == "block" {
          1
        } else if o.mark == "run" {
          0
        } else if o.state_lead == "done" {
          4
        } else {
          5
        }
      None => 5
    }
  }
  @sf.action_box_node(row, title, fn(_) {
    match @signals.untracked(item) {
      Some(o) => {
        match close {
          Some(f) => f()
          None => ()
        }
        @sfbase.open_page(Chat(o.chat))
      }
      None => ()
    }
  }, fn(b) {
    @sf.style_node(b, fn() { subchats_row.then(subchats_round) })
    b.min_height(Is(Some(44.0))) |> ignore
    @sf.hover_ground_node(b)
    @sf.focus_ring_node(b)
    b.box(fn(on) {
      @sf.style_node(on, fn() { subchats_row_on }, in_row=true)
      on.grow(Is(1.0)).basis(Is(Some(0.0))).min_width(Is(Some(0.0))) |> ignore
      @sf.first_line_node(on, Ui, leading=L6, fn(d) {
        d.width(Is(Some(14.0))).lines_up(Is(Some(Middle))).lies_along(Is(Middle)) |> ignore
        d.pick(at_once=true, mark_kind, fn(m, kind) {
          match kind {
            0 => @sf.state_dot_node(m, size=8.0, breathes=true, fn() { "live" })
            1 => @sf.state_dot_node(m, size=8.0, breathes=true, fn() { "restart" })
            2 => @sf.state_dot_node(m, size=8.0, breathes=false, fn() { "fail" })
            3 => @sf.icon_node(m, "archive", 14.0, By(fn() { @sf.theme().p.muted })) |> ignore
            4 => @sf.icon_node(m, "check", 14.0, By(fn() { @sf.theme().p.green_ink })) |> ignore
            _ => @sf.icon_node(m, "spawned", 14.0, By(fn() { @sf.theme().p.muted })) |> ignore
          }
        })
      })
      |> ignore
      on.box(fn(w) {
        @sf.style_node(w, fn() { subchats_row_text }, in_row=true)
        w.grow(Is(1.0)).basis(Is(Some(0.0))).min_width(Is(Some(0.0))) |> ignore
        @sf.words_node(w, title, fn() { if is_archived() { subchats_title_archived } else { subchats_title } })
        .allow_ellipsis(Is(true))
        |> ignore
        w.show(at_once=true, fn() { state_text() != "" }, fn(st) {
          @sf.words_node(st, state_text, fn() { subchats_state_words }).allow_ellipsis(Is(true)) |> ignore
        })
      })
      |> ignore
    })
    |> ignore
    @sf.first_line_node(b, Ui, leading=L6, fn(e) {
      e.width(Is(Some(16.0))).lines_up(Is(Some(Middle))).lies_along(Is(Middle)) |> ignore
      @sf.icon_node(e, "chevron-right", 14.0, By(fn() { if @sf.lit_node(b) { @sf.theme().p.text } else { @sf.theme().p.subtle } }))
      |> ignore
    })
    |> ignore
  })
  |> ignore
}

///|
// kept across runs: a value (no field of it changes)
let subchats_round : @ui.Style = @ui.style(radius=@sf.panel_in)

///|
// kept across runs: a value (no field of it changes)
let subchats_head : @ui.Style = @ui.css("row w=Full pt=S1_5 px=S2_5 pb=S1_5 gap=S2 align=ACenter justify=JBetween")

///|
// kept across runs: a value (no field of it changes)
let subchats_counts : @ui.Style = @ui.css("row gap=S2 align=ACenter")

///|
// kept across runs: a value (no field of it changes)
let subchats_head_title : @ui.TextStyle = @ui.text_style(size=Ui, weight=Semibold, color=Fg, leading=L6, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let subchats_count_words : @ui.TextStyle = @ui.text_style(size=Caption, weight=Medium, color=Muted, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let subchats_empty : @ui.Style = @ui.css("w=Full py=S6 px=S4 align=ACenter justify=JCenter")

///|
// kept across runs: a value (no field of it changes)
let subchats_empty_words : @ui.TextStyle = @ui.text_style(size=Ui, color=Muted, wrap=true)

///|
// kept across runs: a value (no field of it changes)
let subchats_list : @ui.Style = @ui.css("w=Full")

///|
// kept across runs: a value (no field of it changes)
let subchats_group : @ui.Style = @ui.css("w=Full gap=S0_5")

///|
// kept across runs: a value (no field of it changes)
let subchats_group_spaced : @ui.Style = @ui.css("w=Full mt=S2 gap=S0_5")

///|
// kept across runs: a value (no field of it changes)
let subchats_section_head : @ui.Style = @ui.css("w=Full px=S2_5 pt=S1 pb=S1")

///|
// kept across runs: a value (no field of it changes)
let subchats_section_words : @ui.TextStyle = @ui.text_style(size=Caption, weight=Medium, color=Muted, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let subchats_row : @ui.Style = @ui.css("row w=Full py=S2 px=S2_5 gap=S2_5 align=AStart")

///|
// kept across runs: a value (no field of it changes)
let subchats_row_on : @ui.Style = @ui.css("row gap=S2_5 align=AStart")

///|
// kept across runs: a value (no field of it changes)
let subchats_row_text : @ui.Style = @ui.css("gap=SPx")

///|
// kept across runs: a value (no field of it changes)
let subchats_title : @ui.TextStyle = @ui.text_style(size=Ui, weight=Medium, color=Fg, leading=L6, wrap=false, w=Cut)

///|
// kept across runs: a value (no field of it changes)
let subchats_title_archived : @ui.TextStyle = @ui.text_style(size=Ui, weight=Medium, color=Muted, leading=L6, wrap=false, w=Cut)

///|
// kept across runs: a value (no field of it changes)
let subchats_state_words : @ui.TextStyle = @ui.text_style(size=Meta, color=Muted, wrap=false, w=Cut)

///|
// kept across runs: a value (no field of it changes)
let subchats_foot : @ui.Style = @ui.css("w=Full pt=S1_5")

///|
// kept across runs: a value (no field of it changes)
let subchats_divider : @ui.Style = @ui.css("w=Full h=SPx bg=Line mb=S1_5")

///|
// kept across runs: a value (no field of it changes)
let subchats_foot_btn : @ui.Style = @ui.css("row w=Full py=S2 px=S2_5 gap=S2 align=ACenter")

///|
// kept across runs: a value (no field of it changes)
let subchats_foot_words : @ui.TextStyle = @ui.text_style(size=Ui, color=Muted, wrap=false)

///|
// kept across runs: a value (no field of it changes)
let subchats_foot_hot : @ui.TextStyle = @ui.text_style(size=Ui, color=Fg, wrap=false)
