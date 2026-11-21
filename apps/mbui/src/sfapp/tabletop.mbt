// A chat on a device half open on its back half (a laptop's pose, Android's tabletop: @ui.system_tabletop, the hinge
// partly open and its fold across the view, as the system says them): what is read over the fold, what is touched
// under it. Its messages end over the fold (all that keeps clear of the composer keeps clear of the fold and what is
// under it: chat_foot_room); under the fold its composer, and under that the latest chats, one tap to another. The
// keyboard up, the composer rides on it, the chats under it out of the way. The page across the window whatever the size classes (laid out Small: @sf.layout); open flat, upright as
// a book, or closed, it is as on any screen.

///|
/// Under a chat's composer on a device half open: the latest chats, as much of them as the half has room for.
// kept across runs: a value (no field of it changes)
let tabletop_recent : @ui.Style = @ui.style(w=Full, h=@sf.grow, clip=true)

///|
/// How many of the list's chats it has, and how many rows are shown in their bones while they are read.
let recent_chats_most : Int = 6

///|
let recent_sample : Int = 4

///|
// kept across runs: a value (no field of it changes)
let recent_empty : @ui.TextStyle = @ui.text_style(size=Meta, color=Muted, w=Full)

///|
// kept across runs: a value (no field of it changes)
let recent_rows : @ui.Style = @ui.css("w=Full px=S1_5")

///|
/// A chat's composer made as nodes in its messages' list's foot (chat_page_made's `foot_node`), in `n`, at its own
/// height: over the navigation bar (the keyboard's top under it), its tips in `tips`; `shows`, whether its page shows
/// (chat_composer_node's).
/// On a device half open (@ui.system_tabletop), as chat_foot: all from the fold down, the composer at the top of the
/// half under it and the latest chats under that (recent_list_node), the messages kept over the fold by it.
fn chat_foot_node(
  n : @view.View,
  src : Source,
  r : ChatRef,
  shows : () -> Bool,
  tips : @sf.TipLayer,
  stint : () -> Int,
) -> Unit {
  n
  .row(Is(false))
  // (on the page's ground under the fold: what scrolls over it never seen through it)
  .ground(By(fn() { if @ui.system_tabletop() is Some(_) { @sf.theme().p.bg } else { 0L } }))
  .height(By(fn() {
    match @ui.system_tabletop() {
      Some((top, _)) => Some(dmax(0.0, n.window_h() - top))
      None => None
    }
  }))
  |> ignore
  // (the fold itself, from its top to where the half under it begins: none on any other device)
  n.show(at_once=true, fn() { @ui.system_tabletop() is Some(_) }, fn(fold) {
    fold.height(By(fn() {
      match @ui.system_tabletop() {
        Some((top, foot)) => Some(dmax(0.0, foot - top))
        None => Some(0.0)
      }
    }))
    |> ignore
  })
  @sfpages.chat_composer_node(n, src, r, shows~, tips~, over_it=fn(o) { chat_composer_bar_node(o, src, r, stint) }, over_full=true)
  n.show(at_once=true, fn() { @ui.system_tabletop() is Some(_) }, fn(recent) {
    // (the room left under the composer, never more: what it holds past it cut, not pushing the foot past the window)
    @sf.style_node(recent, fn() { tabletop_recent })
    recent.basis(Is(Some(0.0))).shrink(Is(1.0)).min_height(Is(Some(0.0))) |> ignore
    recent_list_node(recent, src, tips, r, stint)
  })
  n.box(fn(bar) { bar.height(By(fn() { Some(nav_foot()) })) |> ignore }) |> ignore
}

///|
/// recent_list_node's while its first answer is awaited (or could not be read): a made-up list's rows in their bones,
/// made once, outside what its pick makes.
fn recent_list_waiting(
  p : @view.View,
  tips : @sf.TipLayer,
  stint : () -> Int,
  read : () -> (@sfbase.ChatsView?, String?),
) -> Unit {
  @sf.waiting_node(
    p,
    fn(s) {
      for i in 0..<recent_sample {
        let item = @sfpages.sample_chat(i)
        @sfpages.chat_row_node(s, @sfbase.sample_source, tips, fn() { item }, "agents", fn() { false }, Whole, stint, more=i + 1 < recent_sample)
        |> ignore
      }
    },
    error=fn() { read().1.unwrap_or("") },
    note=fn() {
      match read().0 {
        Some({ note: Some(nt), .. }) => { reading: nt.reading, text: nt.text.unwrap_or(""), failing: nt.failing }
        _ => { reading: true, text: tr("common.reading"), failing: [] }
      }
    },
  )
}

///|
/// recent_list's, made as nodes: the list's first six chats (`current` marked; one pressed opens in its place, a swipe
/// archives it: chat_row_node's), or what the list says in their place.
fn recent_list_node(parent : @view.View, src : Source, tips : @sf.TipLayer, current : ChatRef, stint : () -> Int) -> Unit {
  let read = fn() {
    match workspace_in_view(src).0 {
      Some(w) => chats_of(src, w.id, "all")
      None => (None, None)
    }
  }
  // (0 waiting on its first answer, or what could not be read; 1 none; 2 its rows)
  let state = fn() {
    match read().0 {
      None => 0
      Some(v) if v.days.is_empty() =>
        match v.note {
          Some(note) if note.reading || note.failing.length() > 0 => 0
          _ => 1
        }
      Some(_) => 2
    }
  }
  parent.pick(state, at_once=true, fn(p, k) {
    match k {
      0 => recent_list_waiting(p, tips, stint, read)
      1 =>
        @sf.words_node(p, fn() { tr("android-misc.wide.empty") }, fn() { recent_empty }) |> ignore
      _ =>
        p.box(fn(box) {
          @sf.style_node(box, fn() { recent_rows })
          let items = fn() {
            let out : Array[ChatItem] = []
            match read().0 {
              Some(v) =>
                for d in v.days {
                  for it in d.items {
                    if out.length() < recent_chats_most {
                      out.push(it)
                    }
                  }
                }
              None => ()
            }
            out
          }
          let lead = fn() {
            match read().0 {
              Some(v) => v.leading
              None => "agents"
            }
          }
          box.each(items, fn(it) { @sfbase.row_name(it) }, fn(row, item) {
            let at = @signals.untracked(fn() { items().length() })
            @sfpages.chat_row_node(
              row,
              src,
              tips,
              fn() { item.get() },
              @signals.untracked(lead),
              fn() { row_is(item.get(), current) },
              Whole,
              stint,
              more=at > 1,
            )
            |> ignore
          })
        })
        |> ignore
    }
  })
}

