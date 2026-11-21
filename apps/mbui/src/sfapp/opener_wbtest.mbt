// A chat an agent made (chat_create) and the chat whose agent made it: the way from either to the other, its row's mark
// and menu, the chat's info (…: beside the chat on Medium and Large, its sheet on Small); nothing else of either goes
// by the other.

///|
/// The chat the way back leads to: the one the fixture's chat-opener names (和 Ana 一起看新版的引导页).
fn opener_open(t : @ui.Tester) -> Unit raise {
  ignore(t)
  match app.nav.top() {
    Chat(r) => {
      assert_eq(r.session, "s-c6")
      assert_eq(r.station, "ws1/st1")
      assert_eq(r.title, "和 Ana 一起看新版的引导页")
    }
    _ => fail("no chat open")
  }
}

///|
test "wide: a row another chat's agent made is marked so, that chat named on the mark; its menu's 打开「…」 opens that chat" {
  let calls : Array[Made] = []
  let t = wide_tester(calls, mode="chat-opener")
  t.draw()
  assert_true(t.query(Image, label="由「和 Ana 一起看新版的引导页」创建") is Some(_))
  let (x, y) = t.find("首页的列表改成按天分组").unwrap()
  t.right_click(x, y)
  assert_true(t.query(MenuItem, label="打开「和 Ana 一起看新版的引导页」") is None)
  t.key(@ui.key_escape)
  let (x, y) = t.find("夜里的构建又失败了").unwrap()
  t.right_click(x, y)
  t.click(MenuItem, label="打开「和 Ana 一起看新版的引导页」")
  opener_open(t)
}

///|
test "wide: a chat another chat's agent made has that chat in its info (…); pressed, that chat opens" {
  let calls : Array[Made] = []
  let t = wide_tester(calls, mode="chat-opener")
  t.click(Button, label="对话信息")
  t.run_for(@ui.move_most_ms)
  // (its 发起: that chat, not a person)
  t.click(Link, label="由「和 Ana 一起看新版的引导页」创建")
  opener_open(t)
}

///|
test "wide: a chat whose agent made others has how many in its info (…), each where it stands in the menu that opens left of it as it is pointed at; one chosen opens" {
  let calls : Array[Made] = []
  let t = wide_tester(calls, mode="chat-opened")
  t.click(Button, label="对话信息")
  t.run_for(@ui.move_most_ms)
  // (not each of them in it: one row)
  assert_true(t.query(MenuItem, label="旧版引导页的截图 · 已归档") is None)
  let (x, y, _, _) = t.rect_of("创建了 3 个对话").unwrap()
  let (px, _, _, _) = t.rect_of("发起").unwrap()
  t.move_to(x + 4.0, y + 4.0)
  t.run_for(@ui.move_most_ms)
  // left of the info's panel, not over it
  let (mx, _, mw, _) = t.rect_of("旧版引导页的截图 · 已归档").unwrap()
  ignore(mx)
  assert_true(mx + mw < px)
  t.click(MenuItem, label="夜里的构建又失败了")
  match app.nav.top() {
    Chat(r) => assert_eq(r.session, "s-c3")
    _ => fail("no chat open")
  }
}

///|
test "a chat another chat's agent made has that chat in its own sheet (…); pressed, that chat opens" {
  let calls : Array[Made] = []
  let t = decide_core(calls, "chat-opener")
  t.click(Button, label="对话信息")
  t.run_for(@ui.move_most_ms)
  t.click(Link, label="由「和 Ana 一起看新版的引导页」创建")
  t.run_for(@ui.move_most_ms)
  opener_open(t)
}

///|
test "a chat whose agent made others has how many in its own sheet (…), each in the menu it opens; one chosen opens" {
  let calls : Array[Made] = []
  let t = decide_core(calls, "chat-opened")
  t.click(Button, label="对话信息")
  t.run_for(@ui.move_most_ms)
  t.tap_text("创建了 3 个对话")
  t.run_for(@ui.move_most_ms)
  // (a menu on Small: a sheet from the foot, a button each)
  t.click(Button, label="给设置页加一个深色模式开关")
  t.run_for(@ui.move_most_ms)
  match app.nav.top() {
    Chat(r) => assert_eq(r.session, "s-c4")
    _ => fail("no chat open")
  }
}

///|
test "a chat whose agent made others: in its sheet (…) the card of 创建了 N 个对话 stands as far from the card under it as its agents' from it" {
  let calls : Array[Made] = []
  let t = decide_core(calls, "chat-opened")
  t.click(Button, label="对话信息")
  t.run_for(@ui.move_most_ms)
  // (the user's phone, 2026-11-02: its card and the pull requests' under it touching, 0 between them)
  // (its rows, a pull request's a link: it opens in the browser)
  let rows = t.semantics().filter(fn(s) { (s.role == @ui.Role::Button || s.role == @ui.Role::Link) && s.rect.2 > 200.0 })
  let labels = rows.map(fn(s) { s.label }).join(" / ")
  let mut i = -1
  for k, s in rows {
    if s.label.contains("创建了 3 个对话") {
      i = k
    }
  }
  assert_true(i > 0 && i + 1 < rows.length(), msg="a row over it and under it: \{labels}")
  let gap = fn(a : @ui.SemNode, b : @ui.SemNode) { b.rect.1 - (a.rect.1 + a.rect.3) }
  let over = gap(rows[i - 1], rows[i])
  let under = gap(rows[i], rows[i + 1])
  assert_true(over >= 10.0, msg="\{over} over it")
  assert_eq(under, over)
}

///|
test "wide: non-led chat-opener shows no top-bar breadcrumb, while led chat-lineage shows multi-level breadcrumb and navigates" {
  let calls : Array[Made] = []
  let t = wide_tester(calls, mode="chat-opener")
  t.draw()
  // chat-opener is opened for a person (led == false): no breadcrumb link in the chat top bar
  let bar_crumb = t.semantics().filter(fn(s) { s.role == Link && s.label == "和 Ana 一起看新版的引导页" && s.rect.0 > 260.0 && s.rect.1 < 56.0 })
  assert_eq(bar_crumb.length(), 0)

  let calls2 : Array[Made] = []
  let t2 = wide_tester(calls2, mode="chat-lineage")
  t2.draw()
  assert_eq(t2.audit().filter(fn(f) { !f.contains("edge_node.mbt") }), [])
  // 3-level chain: root and direct parent visible, middle collapsed under 更多上级对话
  assert_true(t2.query(Link, label="根规划") is Some(_))
  assert_true(t2.query(Link, label="任务拆分") is Some(_))
  assert_true(t2.query(Button, label="更多上级对话") is Some(_))
  assert_true(t2.query(Link, label="接口重构") is None)
  t2.click(Button, label="更多上级对话")
  t2.run_for(@ui.move_most_ms)
  t2.click(MenuItem, label="接口重构")
  match app.nav.top() {
    Chat(r) => assert_eq(r.session, "s-c5")
    _ => fail("expected middle ancestor chat open")
  }
  // History back returns to the child chat
  assert_true(@sfbase.go_back())
  match app.nav.top() {
    Chat(r) => assert_eq(r.session, "s-c1")
    _ => fail("expected back to s-c1")
  }
  // Clicking root navigates directly
  t2.draw()
  t2.click(Link, label="根规划")
  match app.nav.top() {
    Chat(r) => assert_eq(r.session, "s-c6")
    _ => fail("expected root ancestor chat open")
  }
}

///|
test "wide: sub-chats bar entry excludes non-led chats, opens popover, navigates, and pins to side panel" {
  let calls : Array[Made] = []
  let t = wide_tester(calls, mode="chat")
  t.draw()
  // Ordinary chat has no sub-chats bar button
  assert_true(t.query(Button, label="子会话") is None)

  let calls2 : Array[Made] = []
  let t2 = wide_tester(calls2, mode="chat-subchats-pop")
  t2.draw()
  guard t2.query(Button, label="子会话") is Some(sub_btn) else { fail("expected subchats button") }
  assert_true(sub_btn.rect.1 > 400.0, msg="wide subchats pill must sit above composer: \{Repr(sub_btn.rect)}")
  t2.click(Button, label="子会话")
  t2.run_for(@ui.move_most_ms)
  let dialogs = t2.all(Dialog)
  assert_true(dialogs.length() > 0, msg="expected subchats popover dialog")
  let d = dialogs[dialogs.length() - 1].rect
  assert_true(d.1 + d.3 <= sub_btn.rect.1 + 1.0, msg="wide subchats popover must open above composer pill: \{Repr(d)} vs \{Repr(sub_btn.rect)}")
  assert_eq(t2.audit().filter(fn(f) { !f.contains("edge_node.mbt") }), [])
  // 4 led sub-chats shown (running, waiting, done, archived), non-led chat excluded!
  assert_true(t2.query(Button, label="安卓构建与冒烟测试") is Some(_))
  assert_true(t2.query(Button, label="夜里的构建又失败了") is Some(_))
  assert_true(t2.query(Button, label="给设置页加一个深色模式开关") is Some(_))
  assert_true(t2.query(Button, label="旧版引导页的截图") is Some(_))
  assert_true(t2.query(Button, label="给产品评审建的独立讨论") is None)
  assert_true(t2.find("1 进行中") is Some(_))
  assert_true(t2.find("1 待处理") is Some(_))
  // Open in side panel sends chat.tabs.open with tab: "subchats"
  t2.click(Button, label="在侧栏查看")
  t2.run_for(@ui.move_most_ms)
  assert_true(
    calls2.iter().any(fn(c) { c.name == "chat.tabs.open" && text(Some(c.params), "tab") == "subchats" }),
    msg="expected chat.tabs.open subchats",
  )

  // Clicking a sub-chat opens it
  let calls3 : Array[Made] = []
  let t3 = wide_tester(calls3, mode="chat-subchats-pop")
  t3.draw()
  t3.click(Button, label="子会话")
  t3.run_for(@ui.move_most_ms)
  t3.click(Button, label="安卓构建与冒烟测试")
  match app.nav.top() {
    Chat(r) => assert_eq(r.session, "s-c2")
    _ => fail("expected sub-chat s-c2 open")
  }
}

///|
test "wide: side panel subchats tab renders led sub-chats and excludes non-led" {
  let calls : Array[Made] = []
  let t = wide_tester(calls, mode="chat-subchats-panel")
  t.draw()
  assert_eq(t.audit().filter(fn(f) { !f.contains("edge_node.mbt") }), [])
  assert_true(t.query(Button, label="安卓构建与冒烟测试") is Some(_))
  assert_true(t.query(Button, label="给产品评审建的独立讨论") is None)
}

///|
test "small: chat-lineage breadcrumb navigates and chat-subchats-pop sheet excludes non-led" {
  let calls : Array[Made] = []
  let t = decide_core(calls, "chat-lineage")
  t.draw()
  assert_eq(t.audit(), [])
  assert_true(t.query(Link, label="根规划") is Some(_))
  assert_true(t.query(Link, label="任务拆分") is Some(_))
  guard t.query(Button, label="子会话") is Some(sub_sm) else { fail("expected small subchats pill") }
  assert_true(sub_sm.rect.1 > 400.0, msg="small subchats pill must sit above composer: \{Repr(sub_sm.rect)}")
  t.click(Link, label="任务拆分")
  t.run_for(@ui.move_most_ms)
  match app.nav.top() {
    Chat(r) => assert_eq(r.session, "s-c4")
    _ => fail("expected parent chat s-c4 open")
  }

  let calls2 : Array[Made] = []
  let t2 = decide_core(calls2, "chat-subchats-pop")
  t2.run_for(@ui.move_most_ms)
  assert_eq(t2.audit(), [])
  assert_true(t2.query(Button, label="安卓构建与冒烟测试") is Some(_))
  assert_true(t2.query(Button, label="给产品评审建的独立讨论") is None)
}
