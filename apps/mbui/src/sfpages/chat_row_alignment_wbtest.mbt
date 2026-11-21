// The end of each chat row is one column, whatever marks the chat and whoever is in it. In particular, a missing
// station or origin mark must not leave a gap after the last visible mark.

///|
fn alignment_center(r : (Double, Double, Double, Double)) -> Double {
  r.0 + r.2 / 2.0
}

///|
/// The actual drawn unplug icon's centre, not its semantic slot.
fn alignment_unplug(t : @ui.Tester) -> Double raise {
  let (x, y, w, h) = t.get(Image, label="Offline").rect
  match t.shape_boxes().iter().find_first(fn(s) {
    let (cx, cy) = (s.1 + s.3 / 2.0, s.2 + s.4 / 2.0)
    cx >= x && cx <= x + w && cy >= y && cy <= y + h
  }) {
    Some(s) => s.1 + s.3 / 2.0
    None => fail("the unplugged icon is not drawn: \{Repr(t.shape_boxes())}")
  }
}

///|
test "a station picture reserves a column only once it can be drawn" {
  for platform in [0, 2] {
    @sfbase.reset()
    reset()
    @sf.set_words(@sfbase.fill)
    let picture = @signals.signal("")
    let was = @sf.picture_of.val
    @sf.picture_of.val = fn(_, _) { picture.get() }
    defer { @sf.picture_of.val = was }
    let item = @signals.signal({
      ..sample_chat(0), title: "Image row", station_name: "Station", station_icon: "https://example.test/station.png",
      offline: Some("Offline"),
    })
    let t = @ui.Tester::new(
      fn(c) { @sf.begin(c) |> ignore },
      w=320.0,
      h=200.0,
      platform~,
      images=[("picture-a", 64, 64), ("picture-b", 64, 64)],
      finish=false,
    )
    @ui.set_view_app(fn(root) {
      @ui.set_tree_theme(@sf.ui_theme_now)
      let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
      let tips = @sf.TipLayer::new(fn() { Some(popup) })
      chat_row_node(root, @sfbase.sample_source, tips, fn() { item.get() }, "agents", fn() { false }, Side, fn() { 0 }) |> ignore
    })
    t.draw()
    let (x, _, w, _) = t.get(Link, label="Image row").rect
    let column = x + w - @sf.row_corner
    let unplug_at_end = fn() -> Unit raise {
      assert_true((alignment_unplug(t) - column).abs() < 0.5, msg="unplug \{alignment_unplug(t)}, column \{column}")
      assert_true(t.query(Image, label="Station") is None, msg="an undrawn station mark still has a slot")
    }
    unplug_at_end()
    picture.set("picture-a")
    t.frame()
    unplug_at_end()
    guard t.pending() is [(_, id), ..] else { fail("the picture was not asked for") }
    t.finish(1, id)
    t.frame()
    guard t.drawn_images() is [image, ..] else { fail("the decoded picture is not drawn") }
    assert_true((image[0] + image[2] / 2.0 - column).abs() < 0.5 && image[8] > 0.99, msg="picture \{Repr(image)}, column \{column}")
    assert_true(alignment_unplug(t) < column - kind_slot_w)
    picture.set("picture-b")
    t.frame()
    unplug_at_end()
    assert_eq(t.drawn_images().length(), 0, msg="the old picture is still drawn")
    guard t.pending() is [(_, id), ..] else { fail("the replacement picture was not asked for") }
    t.finish(1, id, ok=false)
    t.frame()
    unplug_at_end()
    item.set({ ..item.get(), station_icon: "glyph:does-not-exist" })
    t.frame()
    unplug_at_end()
    item.set({ ..item.get(), station_emoji: "🌿" })
    t.frame()
    guard t.rect_of("🌿") is Some(emoji) else { fail("the fallback emoji is not drawn") }
    assert_true((alignment_center(emoji) - column).abs() < 0.5, msg="emoji \{Repr(emoji)}, column \{column}")
    item.set({ ..item.get(), station_emoji: "", station_icon: "glyph:desktop" })
    t.frame()
    assert_true((alignment_center(t.get(Image, label="Station").rect) - column).abs() < 0.5)
    assert_true(alignment_unplug(t) < column - kind_slot_w)
    item.set({ ..item.get(), station_emoji: "🌿", station_icon: "" })
    t.frame()
    guard t.rect_of("🌿") is Some(emoji) else { fail("the emoji is not drawn after the glyph") }
    assert_true((alignment_center(emoji) - column).abs() < 0.5)
    item.set({ ..item.get(), station_emoji: "", station_icon: "https://example.test/station.png" })
    picture.set("")
    t.frame()
    unplug_at_end()
    assert_eq(t.audit(), [])
  }
}

///|
test "each status lead and its words align with the title's mark and words" {
  for platform in [0, 2] {
    for at in [@sf.ListAt::Side, Whole] {
      @sfbase.reset()
      reset()
      @sf.set_words(@sfbase.fill)
      let base = {
        ..sample_chat(0), title: "Title starts here", tone: "busy", state_text: Some("Status starts here"),
        state_rest: "Status starts here",
      }
      let item = @signals.signal(base)
      let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform~)
      @ui.set_view_app(fn(root) {
        @ui.set_tree_theme(@sf.ui_theme_now)
        let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
        let tips = @sf.TipLayer::new(fn() { Some(popup) })
        chat_row_node(root, @sfbase.sample_source, tips, fn() { item.get() }, "agents", fn() { false }, at, fn() { 0 }) |> ignore
      })
      t.draw()
      for (lead, label, settled) in [
        ("need", @sf.t("web-main.chatMark.alert"), false),
        ("done", @sf.t("web-main.status.done"), false),
        ("done", @sf.t("web-main.chatMark.settled"), true),
        ("wait", @sf.t("web-main.status.waiting"), false),
        ("watch", "Status starts here", false),
      ] {
        item.set({ ..base, state_lead: lead, settled })
        t.run_for(@ui.move_most_ms)
        guard t.rect_of("Title starts here") is Some(title) else { fail("the title is missing") }
        guard t.rect_of("Status starts here") is Some(status) else { fail("the status is missing") }
        let mark = alignment_center(t.get(Image, label=@sf.t("web-main.chatMark.busy")).rect)
        let icon = alignment_center(t.get(Image, label~).rect)
        assert_true((title.0 - status.0).abs() < 0.5, msg="platform \{platform}, \{lead}: title \{title.0}, status \{status.0}")
        assert_true((mark - icon).abs() < 0.5, msg="platform \{platform}, \{lead}: title mark \{mark}, status icon \{icon}")
        assert_eq(t.audit(), [])
      }
    }
  }
}

///|
test "a failed row action uses the end column when there is no other mark" {
  for platform in [0, 2] {
    @sfbase.reset()
    reset()
    @sf.set_words(@sfbase.fill)
    let item = { ..sample_chat(0), title: "Failure", station: "ws1/st1" }
    let base = @sfbase.sample_source
    let src : Source = {
      ..base,
      topic_read: fn(name, params) {
        if name == "doing" {
          {
            value: Some({
              "doing": [{
                "call": "chat.archive", "stage": "failed", "error": "Archive failed",
                "params": { "station": "ws1/st1", "session": Json::string(item.session) },
              }],
            }),
            error: None,
            version: 1,
          }
        } else {
          (base.topic_read)(name, params)
        }
      },
    }
    let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform~)
    @ui.set_view_app(fn(root) {
      @ui.set_tree_theme(@sf.ui_theme_now)
      let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
      let tips = @sf.TipLayer::new(fn() { Some(popup) })
      chat_row_node(root, src, tips, fn() { item }, "agents", fn() { false }, Side, fn() { 0 }) |> ignore
    })
    t.draw()
    let (x, _, w, _) = t.get(Link, label="Failure").rect
    let column = x + w - @sf.row_corner
    let failure = alignment_center(t.get(Image, label="Archive failed").rect)
    assert_true((failure - column).abs() < 0.5, msg="failure \{failure}, column \{column}")
    assert_eq(t.audit(), [])
  }
}

///|
test "faces, a creator's ring and the more count share the same column as the row's mark" {
  for platform in [0, 2] {
    for at in [@sf.ListAt::Side, Tape, Whole] {
      for scale in [1.0, 1.3] {
        @sfbase.reset()
        reset()
        @sf.set_words(@sfbase.fill)
        let people : Array[@sfbase.Person] = [
          { id: "a", email: "", name: "Ada", display: "Ada", picture: "", mine: false },
          { id: "b", email: "", name: "Bo", display: "Bo", picture: "", mine: false },
          { id: "c", email: "", name: "Chen", display: "Chen", picture: "", mine: false },
          { id: "d", email: "", name: "Dan", display: "Dan", picture: "", mine: false },
        ]
        let base = {
          ..sample_chat(0), title: "People row", station_name: "Station", station_emoji: "🌿", agents: [],
          people_text: "People",
        }
        let cases = [
          ({ ..base, people: [people[0]] }, false, 0.0),
          ({ ..base, people: [people[0], people[1]], creator: "b" }, false, face_gap_w),
          ({ ..base, people }, true, 0.0),
        ]
        let item = @signals.signal(cases[0].0)
        let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform~)
        t.set_font_scale(scale)
        @ui.set_view_app(fn(root) {
          @ui.set_tree_theme(@sf.ui_theme_now)
          let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
          let tips = @sf.TipLayer::new(fn() { Some(popup) })
          chat_row_node(root, @sfbase.sample_source, tips, fn() { item.get() }, "agents", fn() { false }, at, fn() { 0 }) |> ignore
        })
        t.draw()
        for (row, more, gap) in cases {
          item.set(row)
          t.run_for(@ui.move_most_ms)
          let column = alignment_center(t.get(Image, label="Station").rect)
          let (x, _, w, _) = t.get(Image, label="People").rect
          let last = if more {
            guard t.rect_of("+1") is Some(r) else { fail("the more count is missing") }
            alignment_center(r)
          } else {
            x + w - @sf.theme().chat_list.face_d / 2.0 - gap
          }
          assert_true((last - column).abs() < 0.5, msg="platform \{platform}, scale \{scale}, more \{more}: last \{last}, column \{column}")
          assert_eq(t.audit(), [])
        }
      }
    }
  }
}

///|
test "the archive action takes the same column when a mouse points at a row" {
  for at in [@sf.ListAt::Side, Tape, Whole] {
    @sfbase.reset()
    reset()
    @sf.set_words(@sfbase.fill)
    let item = { ..sample_chat(0), title: "Archive row", station_name: "Station", station_emoji: "🌿" }
    let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform=0, pointing=Mouse)
    @ui.set_view_app(fn(root) {
      @ui.set_tree_theme(@sf.ui_theme_now)
      let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
      let tips = @sf.TipLayer::new(fn() { Some(popup) })
      chat_row_node(root, @sfbase.sample_source, tips, fn() { item }, "agents", fn() { false }, at, fn() { 0 }) |> ignore
    })
    t.draw()
    let (x, y, w, h) = t.get(Link, label=item.title).rect
    let column = alignment_center(t.get(Image, label="Station").rect)
    t.move_to(x + w / 2.0, y + h / 2.0)
    t.run_for(@sf.dur_ms)
    let archive = t.get(Button, label=@sf.t("web-main.chat.archiveNamed", args=[("title", item.title)])).rect
    assert_true((alignment_center(archive) - column).abs() < 0.5, msg="archive \{alignment_center(archive)}, column \{column}")
    assert_true(alignment_center(t.get(Image, label="Station").rect) < column, msg="the station mark clears the archive action")
    assert_eq(t.audit(), [])
  }
}

///|
test "an agent overflow count ends on the same column as the station mark" {
  for platform in [0, 2] {
    for at in [@sf.ListAt::Side, Whole] {
      @sfbase.reset()
      reset()
      @sf.set_words(@sfbase.fill)
      let item = {
        ..sample_chat(0), title: "Many agents", station_name: "Station", station_emoji: "🌿",
        agents: [
          { key: "a", maker: "openai", runtime: "codex", text: "OpenAI" },
          { key: "b", maker: "anthropic", runtime: "claude", text: "Anthropic" },
          { key: "c", maker: "google", runtime: "gemini", text: "Google" },
          { key: "d", maker: "deepseek", runtime: "dsh", text: "DeepSeek" },
        ],
      }
      let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform~)
      @ui.set_view_app(fn(root) {
        @ui.set_tree_theme(@sf.ui_theme_now)
        let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
        let tips = @sf.TipLayer::new(fn() { Some(popup) })
        chat_row_node(root, @sfbase.sample_source, tips, fn() { item }, "agents", fn() { false }, at, fn() { 0 }) |> ignore
      })
      t.draw()
      guard t.rect_of("+1") is Some(count) else { fail("the agent count is missing") }
      let column = alignment_center(t.get(Image, label="Station").rect)
      assert_true((alignment_center(count) - column).abs() < 0.5, msg="agent count \{alignment_center(count)}, column \{column}")
      assert_eq(t.audit(), [])
    }
  }
}

///|
test "mixed people and agent rows end in the same column, including creators and overflow" {
  for platform in [0, 2] {
    for at in [@sf.ListAt::Side, Whole] {
      let people : Array[@sfbase.Person] = [
        { id: "a", email: "", name: "Ada", display: "Ada", picture: "", mine: false },
        { id: "b", email: "", name: "Bo", display: "Bo", picture: "", mine: false },
        { id: "c", email: "", name: "Chen", display: "Chen", picture: "", mine: false },
        { id: "d", email: "", name: "Dan", display: "Dan", picture: "", mine: false },
      ]
      let agents : Array[@sfbase.RowAgent] = [
        { key: "a", maker: "openai", runtime: "codex", text: "OpenAI" },
        { key: "b", maker: "anthropic", runtime: "claude", text: "Anthropic" },
        { key: "c", maker: "google", runtime: "gemini", text: "Google" },
        { key: "d", maker: "deepseek", runtime: "dsh", text: "DeepSeek" },
      ]
      for (lead, np, na, creator, last) in [
        ("people", 1, 1, "", "agent"),
        ("people", 2, 4, "b", "more"),
        ("agents", 2, 1, "b", "face"),
        ("agents", 4, 1, "c", "more"),
      ] {
        @sfbase.reset()
        reset()
        @sf.set_words(@sfbase.fill)
        let item = {
          ..sample_chat(0), title: "Mixed row", station_name: "Station", station_emoji: "🌿", people_text: "People",
          people: people[:np].to_owned(), agents: agents[:na].to_owned(), creator,
        }
        let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform~)
        @ui.set_view_app(fn(root) {
          @ui.set_tree_theme(@sf.ui_theme_now)
          let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
          let tips = @sf.TipLayer::new(fn() { Some(popup) })
          chat_row_node(root, @sfbase.sample_source, tips, fn() { item }, lead, fn() { false }, at, fn() { 0 }) |> ignore
        })
        t.draw()
        let column = alignment_center(t.get(Image, label="Station").rect)
        let center = if last == "more" {
          guard t.rect_of("+1") is Some(r) else { fail("the overflow count is missing") }
          alignment_center(r)
        } else if last == "face" {
          let (x, _, w, _) = t.get(Image, label="People").rect
          x + w - @sf.theme().chat_list.face_d / 2.0 - face_gap_w
        } else {
          let (x, _, w, _) = t.get(Image, label="OpenAI").rect
          x + w - aside_agent_w / 2.0
        }
        assert_true((center - column).abs() < 0.5, msg="\{lead}, \{last}: \{center}, column \{column}")
        assert_eq(t.audit(), [])
      }
    }
  }
}

///|
test "the last chat-row mark and its agent stand in the archive column for every kind of mark" {
  for platform in [0, 2] {
    for at in [@sf.ListAt::Side, Tape, Whole] {
      for scale in [1.0, 1.3] {
        @sfbase.reset()
        reset()
        @sf.set_words(@sfbase.fill)
        let base : @sfbase.ChatItem = {
          ..sample_chat(0),
          title: "Alignment",
          station_name: "Station",
          agents: [{ key: "a", maker: "openai", runtime: "codex", text: "Agent" }],
        }
        let opened : @sfbase.Opener = {
          chat: { station: "s", session: "parent", title: "Parent", station_name: "Station" },
          text: "Opened by Parent",
          archived: false,
          note: "",
          led: false,
        }
        let cases : Array[(@sfbase.ChatItem, String)] = [
          ({ ..base, offline: Some("Offline") }, "Offline"),
          ({ ..base, reconnecting: Some("Reconnecting") }, "Reconnecting"),
          ({ ..base, offline: Some("Updating"), updating: true }, "Updating"),
          ({ ..base, connect: true, origin_kind: "slack", origin_text: "Slack" }, "Slack"),
          ({ ..base, connect: true, origin_kind: "feishu", origin_text: "Feishu" }, "Feishu"),
          ({ ..base, connect: true, origin_kind: "comma", origin_text: "Comma" }, "Comma"),
          ({ ..base, opener: Some(opened) }, "Opened by Parent"),
          ({ ..base, station_icon: "glyph:desktop" }, "Station"),
          ({ ..base, station_emoji: "🌿" }, "Station"),
          ({ ..base, offline: Some("Offline"), opener: Some(opened), station_emoji: "🌿" }, "Station"),
        ]
        let item = @signals.signal(cases[0].0)
        let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform~)
        t.set_font_scale(scale)
        @ui.set_view_app(fn(root) {
          @ui.set_tree_theme(@sf.ui_theme_now)
          let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
          let tips = @sf.TipLayer::new(fn() { Some(popup) })
          chat_row_node(root, @sfbase.sample_source, tips, fn() { item.get() }, "agents", fn() { false }, at, fn() { 0 }) |> ignore
        })
        t.draw()
        for (row, label) in cases {
          item.set(row)
          t.run_for(@ui.move_most_ms)
          let (x, _, w, _) = t.get(Link, label="Alignment").rect
          let column = x + w - @sf.row_corner
          let mark = alignment_center(t.get(Image, label~).rect)
          let (ax, _, aw, _) = t.get(Image, label="Agent").rect
          // The agent group has a two-point inset before its 16-point last mark.
          let agent = ax + aw - aside_agent_w / 2.0
          let place = match at { Side => "side"; Tape => "tape"; Whole => "whole" }
          let context = "platform \{platform}, \{place}, scale \{scale}, \{label}"
          assert_true((mark - column).abs() < 0.5, msg="\{context}: mark \{mark}, column \{column}")
          assert_true((agent - column).abs() < 0.5, msg="\{context}: agent \{agent}, column \{column}")
          let (_, iy, _, ih) = t.get(Image, label~).rect
          if row.station_emoji != "" {
            guard t.rect_of(row.station_emoji) is Some(emoji) else { fail("\{context}: emoji not drawn") }
            assert_true((alignment_center(emoji) - column).abs() < 0.5, msg="\{context}: emoji \{Repr(emoji)}")
          } else {
            let actual = t.shape_boxes().iter().any(fn(s) {
              (s.1 + s.3 / 2.0 - column).abs() < 0.5 && s.2 + s.4 / 2.0 >= iy && s.2 + s.4 / 2.0 <= iy + ih
            })
            // Updating is drawn as lines instead of shapes.
            let lines = @ui.view_tree().unwrap().drawn().iter().any(fn(d) {
              !d.lines.is_empty() && (d.x + d.w / 2.0 - column).abs() < 0.5 && d.y + d.h / 2.0 >= iy && d.y + d.h / 2.0 <= iy + ih
            })
            assert_true(actual || lines, msg="\{context}: no actual mark on the column: \{Repr(t.shape_boxes())}")
          }
          let (_, ay, _, ah) = t.get(Image, label="Agent").rect
          let agent_drawn = t.shape_boxes().iter().any(fn(s) {
            (s.1 + s.3 / 2.0 - column).abs() < 0.5 && s.2 + s.4 / 2.0 >= ay && s.2 + s.4 / 2.0 <= ay + ah
          })
          assert_true(agent_drawn, msg="\{context}: agent graphic not drawn on the column: \{Repr(t.shape_boxes())}")
          if row.offline is Some(_) && row.station_emoji != "" {
            let away = alignment_center(t.get(Image, label="Offline").rect)
            assert_true(away < mark - kind_slot_w, msg="\{context}: the offline and station marks overlap")
          }
          assert_eq(t.audit(), [], msg=context)
        }
      }
    }
  }
}

///|
/// A drawn station mark is never taken for an undrawn one: an offline chat on a station with its own glyph (the
/// fixture's 迁移数据库的演练 on Maple) shows the unplugged icon and the station's mark both, the station's last, in the
/// end column, the unplugged icon a slot before it.
fn offline_with_glyph_check(t : @ui.Tester, column : Double, context : String) -> Unit raise {
  let station = t.get(Image, label="Station").rect
  let mark = alignment_center(station)
  assert_true((mark - column).abs() < 0.5, msg="\{context}: station \{mark}, column \{column}")
  let (_, sy, _, sh) = station
  let drawn = t.shape_boxes().iter().any(fn(s) {
    (s.1 + s.3 / 2.0 - column).abs() < 0.5 && s.2 + s.4 / 2.0 >= sy && s.2 + s.4 / 2.0 <= sy + sh
  })
  assert_true(drawn, msg="\{context}: the station's glyph is not drawn on the column: \{Repr(t.shape_boxes())}")
  let unplug = alignment_unplug(t)
  // (the slot before the station's: clear of it, and no empty slot between them)
  assert_true(unplug <= mark - kind_slot_w && unplug > mark - 2.0 * kind_slot_w, msg="\{context}: unplug \{unplug}, station \{mark}")
}

///|
test "an offline row on a station with its own glyph shows the unplugged icon and the station's mark, the last in the column" {
  for platform in [0, 2] {
    for at in [@sf.ListAt::Side, Tape, Whole] {
      @sfbase.reset()
      reset()
      @sf.set_words(@sfbase.fill)
      let item = {
        ..sample_chat(0), title: "Offline glyph row", station_name: "Station", station_icon: "glyph:laptop:teal",
        offline: Some("Offline"),
      }
      let t = @ui.Tester::new(fn(c) { @sf.begin(c) |> ignore }, w=320.0, h=200.0, platform~)
      @ui.set_view_app(fn(root) {
        @ui.set_tree_theme(@sf.ui_theme_now)
        let popup = root.box(fn(v) { v.over(Is(true)) |> ignore })
        let tips = @sf.TipLayer::new(fn() { Some(popup) })
        chat_row_node(root, @sfbase.sample_source, tips, fn() { item }, "agents", fn() { false }, at, fn() { 0 }) |> ignore
      })
      t.draw()
      let (x, _, w, _) = t.get(Link, label="Offline glyph row").rect
      let place = match at { Side => "side"; Tape => "tape"; Whole => "whole" }
      offline_with_glyph_check(t, x + w - @sf.row_corner, "platform \{platform}, \{place}")
      assert_eq(t.audit(), [])
    }
  }
}
