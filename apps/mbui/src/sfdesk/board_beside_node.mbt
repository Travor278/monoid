// The chat beside the board's page (board.mbt's board_beside, under its own bar): made as nodes, its messages
// chat_body_nodes' and its composer sfpages' chat_composer_node in their list's foot, as the pane's chat page has them
// (pane_made's, chat_page_made's).

///|
/// Chat `r`'s page beside the board in `page`, Home's entry `serial`'s: made again in its place as another chat is
/// shown there.
fn board_beside_page(page : @view.View, src : Source, r : ChatRef, tips : @sf.TipLayer, serial : Int) -> Unit {
  page.pick(
    fn() { r.station + "\u{1}" + r.session },
    fn(p, _) {
      p.grow(Is(1.0)).min_height(Is(Some(0.0))) |> ignore
      board_beside_nodes(p, src, r, tips, serial)
    },
    at_once=true,
  )
}

///|
/// Chat `r`'s page beside the board made as nodes in `p`, as chat_page_made makes a chat's in the pane: its own source,
/// Home's entry's (what it reads let go with `p`), the chat's subscription held by `p`; its words picked with the mouse
/// and its menu; felt as it comes to need its viewer; its messages under the bar's room (board_beside's bar, none of
/// its own here), the composer in their list's foot; a picture flying from it drawn under the bar.
fn board_beside_nodes(p : @view.View, src : Source, r : ChatRef, tips : @sf.TipLayer, serial : Int) -> Unit {
  // (let go (closed, another card's chat in its place, or opened over the whole page): the core told it shows no more
  // and where it was left, as a page left is (sfapp's chat_left), by the source it outlives; said before what it reads
  // is let go, so its view is still there to tell it by)
  let read_by : Ref[Source?] = Ref(None)
  p.owns(fn() {
    let view = match read_by.val {
      Some(own) =>
        match @sfbase.chat_kept_from(own, r) {
          Some(v) => Some(v)
          None => @sfbase.chat_kept_from(src, r)
        }
      None => @sfbase.chat_kept_from(src, r)
    }
    @sfpages.chat_read_left(src, r, view, unless_shown=true) |> ignore
  })
  |> ignore
  let retained = @sfbase.page_entry_source(src, p, serial)
  read_by.val = Some(retained)
  @sfbase.page_entry_read(serial, retained, Chat(r))
  (@sfbase.page_chat_reader(retained, p, serial))(Chat(r))
  // (drawn while Home's entry is, or kept shown in place while the one on top waits: the pane's)
  let shows = fn() { pane_page_wait.draws(serial) }
  p.ground(By(fn() { @sf.theme().p.bg })) |> ignore
  context_node(p)
  @sfbase.feel_needed_node(p, retained, r)
  p.box(fn(col) {
    col.grow(Is(1.0)).min_height(Is(Some(0.0))) |> ignore
    chat_body_nodes(col, retained, r, tips, fn() { 0 }, fn(n) {
      n
      .box(fn(at) {
        @sfpages.chat_composer_node(
          at,
          retained,
          r,
          shows~,
          tips~,
          apart=fn() { false },
          over_it=fn(o) { wide_composer_bar_node(o, retained, r, tips, fn() { 0 }) },
        )
      })
      |> ignore
    }, shows)
  })
  |> ignore
  // (a picture flying from its list drawn here while under the bar, the bar over it: viewer_flight_slot)
  p.box(fn(slot) { @sfbase.viewer_flight_slot(slot, retained, serial, fn() { slot.window() }) }) |> ignore
}
