// What a fixture mode opens over the app (its pages, what is put up over them), over the made-up core of the mode
// (src/sffixture): src/sffix's, the films', the layouts', the replays' and the app's own tests' one way. The app's
// own code calls none of it (detlint's fixture-import: the made-up core is only the tests' and the tools').

///|
/// What the modes of the cards and words set going as the chat opens: chat-answering's option under way, chat-pick's
/// word picked, chat-link-menu's link held, chat-ask's and chat-ask-long's question asked, chat-menu's,
/// chat-menu-choice's and chat-menu-levels' menu presented, chat-confirm's confirm.
pub fn open_cards_fixture(mode : String) -> Unit {
  match mode {
    "chat-answering" => acting.doing["answer/" + seq_key("ws1/st1", 7.0, 8.0) + "/一起换"] = true
    // a question over the chat (the presenters' ask): a short one, its line given; or a long title and a hint taller than
    // a short window leaves it (its body scrolling in the panel)
    "chat-ask" => @sf.ask("重新命名这个对话", "保存", fn(_) {  }, value="周报整理", hint="名字会同步给所有成员。")
    "chat-ask-long" =>
      @sf.ask(
        "重新命名这个对话，新的名字会同步给这个工作区里的所有成员，并出现在他们的对话列表和通知里",
        "保存",
        fn(_) {  },
        value="周报整理",
        hint="改名后，旧的名字仍会出现在通知和历史记录里，直到它们更新；分享出去的链接不受影响，打开时显示新的名字。" +
        "这一段说明故意写得很长，好让它在窄小的窗口里折成很多行，比面板能放下的还高。再多写一些：搜索时新旧两个名字都能找到，" +
        "导出的记录里保留改名的时间。说明到此为止。",
      )
    // a word of the last post picked (its handles and its bar), once laid out (pick.mbt)
    "chat-pick" => {
      pk.ts = "ts11"
      pk.sel.key = "pick/ts11"
      pk.author = "Claude"
      pk.role = "agent"
      pk.sel.a = 4
      pk.sel.b = 6
      @sfbase.pick_told_given()
    }
    // a menu of the presenters' at a point over the chat: a heading, items with icons, a line, one in red, one not to
    // be chosen now; or a menu of choices, one chosen
    "chat-menu" =>
      @sf.menu(
        [
          Some(@sf.menu_item_of("这个对话", fn() {  }, heading=true)),
          Some(@sf.menu_item_of("复制链接", fn() {  }, icon="copy")),
          Some(@sf.menu_item_of("重命名", fn() {  }, icon="edit")),
          Some(@sf.menu_item_of("下载记录", fn() {  }, icon="download", disabled=true)),
          None,
          Some(@sf.menu_item_of("删除", fn() {  }, icon="trash", danger=true)),
        ],
        from=@sf.at_point(700.0, 300.0),
      )
    // a menu whose item opens a menu (分享: on 小屏 a level of the same sheet, back to the first)
    "chat-menu-levels" =>
      @sf.menu(
        [
          Some(@sf.menu_item_of("复制链接", fn() {  }, icon="copy")),
          Some(
            @sf.menu_item_of("分享", fn() {
              @sf.menu(
                [
                  Some(@sf.menu_item_of("发到 Slack", fn() {  }, icon="send")),
                  Some(@sf.menu_item_of("发到飞书", fn() {  }, icon="send")),
                  None,
                  Some(@sf.menu_item_of("生成图片", fn() {  }, icon="photo")),
                ],
                title="分享到",
                from=@sf.at_point(700.0, 300.0),
              )
            }, icon="share", further=true),
          ),
          None,
          Some(
            @sf.menu_item_of("删除", fn() {
              @sf.confirm("删除这个对话？", "对话和它的记录会从这台工作站上删除。", "删除", fn() {  }, danger=true)
            }, icon="trash", danger=true, further=true),
          ),
        ],
        from=@sf.at_point(700.0, 300.0),
      )
    // a confirm over the chat (the presenters'), one that cannot be undone, its warning under its words
    "chat-confirm" =>
      @sf.confirm("删除这个对话？", "对话和它的记录会从这台工作站上删除。", "删除", fn() {  }, danger=true, warning="删除后不能恢复。")
    "chat-menu-choice" =>
      @sf.menu(
        [
          Some(@sf.menu_item_of("按时间", fn() {  }, chosen=true)),
          Some(@sf.menu_item_of("按名称", fn() {  }, chosen=false)),
          Some(@sf.menu_item_of("按大小", fn() {  }, chosen=false)),
        ],
        title="排序",
        from=@sf.at_point(700.0, 300.0),
      )
    // a short pick at a point: its title, the one chosen checked, one with what it is under its words, one with a value at
    // its end, one with its own mark (a station's)
    // a long pick at a point: its search over its list, scrolling past its most
    "chat-pick-long" =>
      @sf.pick(
        "选一个对话",
        Array::makei(14, fn(i) {
          @sf.choice("c\{i}", "对话 \{i + 1}", note=if i == 0 { "刚刚看过" } else { "" }, value=if i == 2 { "3 条新消息" } else { "" })
        }),
        "c1",
        fn(_) {  },
        from=@sf.at_point(700.0, 200.0),
      )
    "chat-pick-short" =>
      @sf.pick(
        "切换工作站",
        [
          @sf.choice("st1", "Willow", note="这台 Mac", mark=OfStation("", "", true, fn() { @sf.theme().p.muted })),
          @sf.choice("st2", "Cedar", value="离线", mark=OfStation("", "", false, fn() { @sf.theme().p.muted })),
          @sf.choice("st3", "Birch", value="2 个任务"),
        ],
        "st1",
        fn(_) {  },
        from=@sf.at_point(700.0, 300.0),
      )
    // the bare address in the long answer held: its menu (link_menu.mbt)
    "chat-link-menu" => {
      // (before the app says its words as it starts: the menu's are said here)
      @sf.set_words(fill)
      link_menu_at("https://example.com/bench/list", 220.0, 360.0, 383.0)
    }
    _ => ()
  }
}

// ── Markdown's tables and code (MBUI_FIXTURE=chat-md) ───────────────────

///|
/// What a fixture mode of this slice opens over Home (sffix's main, as the app starts).
pub fn open_fixture(mode : String) -> Unit {
  let r : ChatRef = { station: "ws1/st1", session: "s-c1", title: "整理发布清单", station_name: "Willow" }
  match mode {
    "history" | "history-reading" | "history-failed" | "history-older" | "history-older-failed" | "history-details" => {
      app.nav.push(Chat(r))
      app.nav.push(History(r, "s-c1", None))
      if mode == "history-details" {
        history_tab.set(1)
        @sfdesk.set_history_shut(false)
      } else {
        @sfpages.history_open(r.station, r.session, ["h2/group", "h2/group/e3", "h4/group", "h4/group/e7"])
      }
    }
    // the wide frame's (wide_panel.mbt): the chat's "…" open, its services' popover, what is opened beside it
    "chat-letters-pop" | "chat-opener-pop" | "chat-opened-pop" => @sfdesk.open_info_pop()
    "chat-subchats-pop" => @sfdesk.open_subchats_pop()
    "chat-jobs-pop" => {
      @sfdesk.open_jobs_pop()
      @sfdesk.open_job_pop("j-ci")
    }
    "home-attention" | "home-attention-login" | "home-shared-bell" => @sfdesk.open_attention()
    // (what is beside it: the made-up core keeps it so, fixture.mbt fixture_chat_tabs)
    "chat-letters-side" => {
      @sfdesk.letters_to_list(r)
      dui.letters_held[r.station + "\u{1}" + r.session] = 7.0
    }
    "chat-model-pop" => @sfpages.open_triple(r.station, "session:s-c1")
    "chat-model-accounts" => @sfpages.open_triple_accounts(r.station, "session:s-c1")
    // (what is typed is looked for as the bar is first drawn)
    "chat-find" => @sfpages.find_preset(side_key(r), "截图")
    // the long chat of two people (outline_fixture.mbt), the list away from its end, at a message of 昨天's; its
    // outline opened from what shows (its rail on a wide page, else its round button), words typed in it
    // (chat-outline-long: one of 240 said by people, its list holding the last forty, its outline open)
    "chat-outline-away" | "chat-outline" | "chat-outline-find" | "chat-outline-bringing" | "chat-outline-long" => {
      let top = if mode == "chat-outline-long" { @sffixture.outline_long_away_seq } else { @sffixture.outline_away_seq }
      @sfbase.kept_places[side_key(r)] = { top, offset: 0.0, bottom: -1.0, piece: -1, piece_offset: 0.0 }
      match mode {
        "chat-outline" | "chat-outline-bringing" | "chat-outline-long" => @sfpages.outline_preset(side_key(r), "")
        "chat-outline-find" => @sfpages.outline_preset(side_key(r), "签名")
        _ => ()
      }
    }
    // the sheet that publishes the chat, what a snapshot would hold read
    "chat-publish" => {
      @sfpages.publish_set(r, 7.0, @sffixture.fix_preview())
    }
    // its station's card, from the agent's
    "chat-peek" => @settings.open_station_peek(r.station, from=Unanchored)
    _ => ()
  }
}

///|
/// What a fixture mode of this slice puts up over the chat once its source is made (open_fixture_src): the chat's
/// sheet, its letters (one opened), an agent's card, its jobs, a job.
fn open_decide_panels(mode : String, src : Source) -> Unit {
  let r : ChatRef = { station: "ws1/st1", session: "s-c1", title: "整理发布清单", station_name: "Willow" }
  match mode {
    "chat-info" | "chat-info-bare" | "chat-letters-info" | "chat-info-pulls" | "chat-opener-info" | "chat-opened-info" =>
      open_info(src, r)
    // what is done with it, from its "…": the menu a row of the list has, the page's own among it
    "chat-actions" => {
      // (before the app says its words as it starts: the menu's are said here)
      @sf.set_words(fill)
      @sfpages.open_chat_menu(
        src,
        "ws1",
        r,
        @sfpages.chat_extra_items(src, r, src.topic("chat", chat_params(r)).get().value),
        from=@sf.at_point(195.0, 800.0),
      )
    }
    "chat-letters" | "chat-letters-many" => open_letters(src, r, 7.0)
    // what was said in it besides words (sfpages things.mbt), from its info
    "chat-things" => open_things(src, r, 7.0)
    "chat-letters-open" => {
      open_letters(src, r, 7.0)
      @sfdesk.letters_open_at(r, @sffixture.fix_letters_link)
    }
    "chat-agent" | "chat-agent-unsaid" | "chat-agent-context" | "chat-agent-compacted" | "chat-agent-screens" => open_agent(src, r, "s-c1")
    "chat-jobs" => open_chat_jobs(src, r)
    "chat-subchats-pop" => open_subchats(src, r)
    "chat-job" => {
      dui.job_tab = 0
      open_job(src, r, "j-ci")
    }
    _ => ()
  }
}

///|
/// The fixture's drive pages opened as MBUI_FIXTURE says (see the top of this file).
pub fn open_drive_fixture(mode : String) -> Unit {
  let docs : DriveAt = { station: "ws1/st1", root: Some(@sffixture.fix_docs), path: "" }
  match mode {
    "files" => app.nav.push(Files)
    // a station's folders pinned, as a member sees them (its drive's page with no folder asked; chat_fixture.mbt)
    "drive-roots" => {
      app.nav.push(Files)
      app.nav.push(Drive({ ..docs, root: None }))
    }
    "drive" | "drive-loading" | "drive-upload" | "drive-download" | "drive-motion" => {
      app.nav.push(Files)
      app.nav.push(Drive(docs))
      // a file being downloaded, a folder being zipped for it (the core's downloads, downloads_fixture.mbt): their rows'
      // progress (keep.mbt)
      if mode == "drive-download" {
        @sffixture.fix_drive_downloads("ws1/st1", @sffixture.fix_docs)
      }
      if mode == "drive-upload" {
        let up = fn(name : String, size : Int, sent : Int, state : String, error : String) {
          ups.serial += 1
          ups.uploads.push({
            serial: ups.serial,
            station: "ws1/st1",
            root: @sffixture.fix_docs,
            dir: "",
            name: @signals.signal(name),
            bytes: Bytes::make(size, b'\x00'),
            sent: @signals.signal(sent),
            state: @signals.signal(state),
            error: @signals.signal(error),
            replace: false,
            id: "",
          })
        }
        up("旅行照片.zip", 6291456, 2621440, "going", "")
        up("长篇小说.txt", 2048, 0, "taken", "")
        up("会议录音.m4a", 3145728, 0, "failed", "station 已离线")
        ups.pumping.set(true)
      }
    }
    "drive-sub" => {
      app.nav.push(Files)
      app.nav.push(Drive(docs))
      app.nav.push(Drive({ ..docs, path: "设计稿" }))
    }
    "drive-empty" => {
      app.nav.push(Files)
      app.nav.push(Drive({ ..docs, path: "空文件夹" }))
    }
    "reader" | "reader-bars" | "reader-contents" | "reader-layout" | "reader-md" => {
      let path = if mode == "reader-md" { "发布清单.md" } else { "长篇小说.txt" }
      let at = { ..docs, path }
      app.nav.push(Files)
      app.nav.push(Drive(docs))
      app.nav.push(DriveRead(at))
      let r = @sf.reading_for(reader_key(at))
      if mode != "reader" && mode != "reader-md" {
        r.chrome.set(true)
      }
      if mode == "reader-contents" {
        r.panel.set(@sf.ReaderPanel::Contents)
      }
      if mode == "reader-layout" {
        // (the layout's panel, nodes of the window's tree, told it is open)
        @sf.reader_panel_set(r, @sf.ReaderPanel::Layout)
      }
    }
    // (chat-station-files: ＋'s Station 文件 put up as the app's source is made, fixture_station_files)
    // (chat-attach-row: put in before the draft's kept files are read, so it is the first of the files' row)
    "chat-station-ref" | "chat-attach-row" =>
      @sffixture.fix_draft_ref("ws1/st1:s-c1", "发布清单.md", false, 4210.0, "path", true)
    // one sent as a file (up at the chat's station), a folder as a zip still going; a card's sheet open
    // (open_fixture_src)
    "chat-station-file" | "chat-station-sheet" => {
      @sffixture.fix_draft_ref("ws1/st1:s-c1", "发布清单.md", false, 4210.0, "file", true)
      @sffixture.fix_draft_ref("ws1/st1:s-c1", "设计稿", true, 0.0, "file", false)
    }
    // the player (play_fixture.mbt), a service's page (service_fixture.mbt)
    _ => {
      open_play_fixture(mode)
      open_service_fixture(mode)
      open_share_fixture(mode)
    }
  }
}

///|
/// What a fixture mode opens over Home before the first frame, as src/sffix (the screenshots' app) opens it: the
/// first row's chat (opened at a message from a notification for chat-flash…), its cards' states; the drive's pages;
/// a history, a chat's sheets; a new chat, the bar's panel, a place; a page of the settings.
pub fn open_fixture_mode(mode : String) -> Unit {
  let rich : ChatRef = {
    station: "ws1/st1",
    session: "s-c1",
    title: "整理发布清单",
    station_name: "Willow",
  }
  if mode == "chat-flash" || mode == "chat-flash-mine" || mode == "chat-flash-notice" {
    // opened from a notification at a message (Ana's, yours, or still.fail's notice), its flash held at its peak
    // (slice 10's)
    let seq = match mode {
      "chat-flash" => 4.0
      "chat-flash-mine" => 6.0
      _ => 1.0
    }
    open_chat_at(rich, seq, held=true)
  } else if mode.has_prefix("chat") {
    open_chat(rich)
    // the cards' states (chat_fixture.mbt): chat-cards, chat-answering
    open_cards_fixture(mode)
  }
  // what comes and goes, every kind of it (downloads_fixture.mbt fix_transfers): over Home its card on a small screen,
  // its chip in the sidebar's foot on a wide one, their list open (transfers.mbt); 本机缓存 with what is being brought
  if mode == "transfers" || mode == "home-transfers" || mode == "home-transfers-update" || mode == "settings-kept-fill" {
    @sffixture.fix_every_transfer("ws1/st1", "s-c1", @sffixture.fix_docs)
  }
  // a newer build ready that waits for the leave to install apps: its card over Home (home-update), over what comes
  // too (home-transfers-update, home-update-list)
  if mode == "home-transfers-update" || mode == "home-update" || mode == "home-update-list" {
    @sffixture.fixture_update("0.1.5640")
    @sffixture.fixture_update_goes("0.1.5640", "allow")
  }
  // a newer build ready where it is put in place at the person's word or as the app quits (a desktop's): 重启更新 in
  // the sidebar
  if mode == "home-update-ready" {
    @sffixture.fixture_update("0.1.5640")
    @sffixture.fixture_update_goes("0.1.5640", "ready", away=false)
  }
  // the same build's first two stages there: offered (有新版本), coming (40%)
  // (and the stations' newer releases beside it: one key, the dialog of both, sfpages station_updates.mbt)
  if mode == "home-update-offered" || mode == "home-station-updates-app" || mode == "station-updates-app" {
    @sffixture.fixture_update("0.1.5640")
  }
  if mode == "home-stale-build" {
    @sffixture.fixture_updates()
  }
  if mode == "home-update-coming" {
    @sffixture.fixture_update("0.1.5640")
    @sffixture.fixture_update_goes("0.1.5640", "downloading", percent=40)
  }
  if mode == "home-transfers" || mode == "home-transfers-update" || mode == "home-update-list" {
    @sfdesk.open_transfers()
  }
  if mode == "chat-keeping" {
    @sffixture.fix_keeping_message("ws1/st1", "s-c1")
  }
  // the drive's pages (src/sfapp/drive_fixture.mbt): files, drive…, reader…
  open_drive_fixture(mode)
  // slice 8's (src/sfapp/decide_fixture.mbt): a history, a chat's sheets
  open_fixture(mode)
  // a new chat (with its sheets), the bar's panel, a place: newchat_fixture.mbt
  open_mode(mode)
  // a station's screen (screen_fixture.mbt)
  @sfpages.open_screen_fixture(mode)
  if mode.has_prefix("settings") {
    let page = @settings.fixture_page(mode)
    open_setting(page)
    // (a page of theirs pictured: on the tape the page in use, brought over; the shell says its own only as it is first
    // drawn, so asked of the frame itself. Their list alone, the gear's: the list)
    if page != "home" {
      @sfdesk.bring_page()
    }
  }
  // 关于 as an update goes, as the host would say it (a film's: scripts/motion/update-flow.drive): offered; the
  // person's check (its bar sweeping); downloaded from 0 to whole; ready
  if mode == "settings-about-flow" {
    @sffixture.fixture_update("0.1.5283")
    let v = "0.1.5283"
    @sffixture.fix_later(1200.0, fn() { update.checking.set(true) })
    @sffixture.fix_later(2200.0, fn() {
      update.checking.set(false)
      @sffixture.fixture_update_goes(v, "downloading", percent=0)
    })
    for i in 1..=20 {
      @sffixture.fix_later(2200.0 + i.to_double() * 160.0, fn() {
        @sffixture.fixture_update_goes(v, "downloading", percent=i * 5)
      })
    }
    @sffixture.fix_later(5800.0, fn() { @sffixture.fixture_update_goes(v, "ready") })
  }
  // 关于 with a newer build on its way, on a device that sends usage statistics and error reports: its rows at their
  // fullest
  if mode == "settings-about" {
    @sffixture.fixture_update("0.1.5283")
    @sffixture.fixture_update_goes("0.1.5283", "downloading", percent=40)
    reporting_host.set(Some({ get: fn() { true }, set: fn(_) {  } }))
  }
  // the search open over Home, words typed (search_fixture.mbt)
  @sfpages.open_search_mode(mode)
  // a device not yet confirmed in the workspace's safe mode: lock-waiting, lock-finding, lock-code and lock-wrong
  // (its waiting page in the chats' place), lock-confirming (the trusted device asks for verification),
  // lock-security (its security page), lock-upgrade (in the lock without its key: the code typed on its security page);
  // lock-needs-app (a web page nobody can approve: its waiting page saying so),
  // lock-needs-app-security (its security page); lock-out-security (its person taken out: its security page)
  // lock-restart-security, lock-rebound-security, lock-replaced-security (its person's own lock: its security page)
  if mode == "lock-security" || mode == "lock-upgrade" || mode == "lock-needs-app-security" || mode == "lock-out-security" || mode == "lock-restart-security" || mode == "lock-rebound-security" || mode == "lock-replaced-security" {
    open_setting(@settings.fixture_page("settings-security"))
  }
  // the board with its first card's chat (整理发布清单) open beside it, at rest, its edge untouched (board-side:
  // 大屏's and 中屏's where there is the room, the chat's page over the board where there is none)
  if mode == "board-side" {
    @sfbase.board_pick.set(Some(rich))
  }
  // ⌘/'s shortcuts at a glance
  if mode == "keys-dialog" {
    @sfdesk.wide.keys_open.set(true)
  }
  // a station login link (/w/<ws>/s/<station>/login/<id>) opened in its standalone sheet
  if mode == "login-link" {
    open_login("ws1/st1", "login-1")
  }
}

///|
/// The app as src/sffix starts it for `mode`, for a Tester made next (screens_wbtest.mbt): a run begun (new_run: the run
/// before let go of, then the app as at the start, whatever ran before in the process), the made-up source of the mode
/// and what it opens before the first frame (open_fixture_mode). The Tester keeps it as it starts (reset by hand).
/// The run before let go of first: its window's tree, still there till the next Tester is made, followed what this one
/// opens (⌘/'s `keys_open`) and put up a panel of its own in this run's presenters, closed (open said false) as that
/// tree was let go (switches_still_wbtest's keys-dialog, on 中屏 and 大屏 after 小屏; run_begins_wbtest).
pub fn fixture_app(mode : String) -> Source {
  new_run()
  let src = @sffixture.fixture(mode)
  open_fixture_over(mode, src)
  src
}

///|
/// What `mode` opens over the app, over `src` (its own, or a test's made of it): its pages (open_fixture_mode), then
/// what is put up reading through `src` (open_fixture_src). The one way a mode is opened: sffix's, the films', the
/// screens' and the tests' alike.
pub fn open_fixture_over(mode : String, src : Source) -> Unit {
  open_fixture_mode(mode)
  open_fixture_src(mode, src)
}

///|
/// What the mode opens over the app once its source is made (what is put up reading through it), as open_fixture_mode
/// opens its pages: ＋'s Station 文件 (chat-station-files); a station's file's card pressed, its panel (chat-station-sheet);
/// the files' favorite picker with no one station in view, which station first (files-add-folder: its rows' grounds under the
/// pointer, the last in the dialog's foot corners); the card to share of the agents at work (share-card); a new
/// workspace, empty and with an invite code found wrong (new-workspace, new-workspace-code).
pub fn open_fixture_src(mode : String, src : Source) -> Unit {
  // slice 8's panels over the chat (decide_fixture.mbt)
  open_decide_panels(mode, src)
  if mode == "files-add-folder" {
    @sfpages.add_favorite_folder(src, "ws1", @sfpages.favorite_stations(src, "ws1"))
  }
  // (share-card-dark: over the dark theme; share-card-<key>: in that look, share_looks.mbt)
  if mode == "share-card" || mode.has_prefix("share-card-") {
    @sfpages.share_card_open(src, { id: "ws1", name: "星火工作室", emoji: "", icon: "", email: "lin@example.com" })
  }
  // (the subscriptions' allowances to share, and the overview's pool to share, of the four kinds' accounts:
  // share_quota.mbt)
  if mode == "share-accounts" || mode == "share-pool" {
    @settings.fixture_page("settings-profiles-sum-a") |> ignore
    let ws : Workspace = { id: "ws1", name: "星火工作室", emoji: "", icon: "", email: "lin@example.com" }
    if mode == "share-accounts" {
      @sfpages.accounts_share_open(settings_core(src, ws), fn() { "ws1" })
    } else {
      @sfpages.pool_share_open(settings_core(src, ws), fn() { "ws1" })
    }
  }
  if mode == "chat-station-files" {
    fixture_station_files(src)
  }
  // the sessions Willow's machine kept, their list open over the new chat
  if mode == "newchat-machine" {
    @settings.fixture_machine_sessions(settings_core(src, { id: "ws1", name: "星火工作室", emoji: "", icon: "", email: "lin@example.com" }))
  }
  if mode == "chat-station-sheet" {
    @sfpages.ref_panel_put(src, "ws1/st1:s-c1", "ws1/st1", "ref-发布清单.md", "发布清单.md")
  }
  // a new workspace over Home: nothing typed yet; and named, an invite code typed that still.fail cloud found wrong
  // (what is wrong with it under its field)
  // the stations' newer releases waiting for this person: their key over Home (home-station-updates); their dialog open
  // over it (station-updates)
  if mode == "station-updates" || mode == "station-updates-app" || mode == "station-updates-stale" {
    @sfpages.station_updates_dialog(src, settings_core(src, { id: "ws1", name: "星火工作室", emoji: "", icon: "", email: "lin@example.com" }), "ws1")
  }
  if mode == "new-workspace" {
    @sfpages.new_workspace_put(src, name="", code="", error_code="")
  }
  if mode == "new-workspace-code" {
    @sfpages.new_workspace_put(src, name="产品团队", code="ABCD-1234-EFGH", error_code="invite_code_invalid")
  }
  if mode.has_prefix("place-remote") {
    @settings.fixture_place_remote()
    // (远程 is the first of the second bar: reached by sliding up to it, so that bar is the one in view, its ball on 远程;
    // place-remote-home stays on Home, the first bar in view, for a finger to slide up to 远程 from there)
    if mode != "place-remote-home" {
      let (sets, _) = @sfbase.bars_in(src, "ws1")
      @sfbase.bars_picked.set(Some((sets, 1)))
    }
  }
  if mode == "place-remote-tabs" {
    @sfbase.remote_tab_open(src, "ws1", Screen({ station: "ws1/st1", screen: "desktop", title: "Willow 的桌面", until_gone: false })) |> ignore
    @sfbase.remote_tab_open(src, "ws1", Screen({ station: "ws1/st1", screen: "browser:T1", title: "发布清单 - localhost:5173", until_gone: false })) |> ignore
    @sfbase.remote_tab_open(src, "ws1", Terminal({ station: "ws1/st1", terminal: "term-2", watch: false, cwd: "~/still.fail" })) |> ignore
  }
}

///|
/// The first row's chat (opened by sffix for chat… modes): ＋'s Station 文件 in 文档, a file ticked.
fn fixture_station_files(src : Source) -> Unit {
  @sfpages.station_files_pick(src, "ws1/st1:s-c1")
  @sfpages.station_pick_set({ station: "ws1/st1", station_name: "Willow", root: @sffixture.fix_docs, root_name: "文档", path: "" }, [
    {
      station: "ws1/st1",
      station_name: "Willow",
      root: @sffixture.fix_docs,
      path: "发布清单.md",
      abs: @sffixture.fix_docs + "/发布清单.md",
      name: "发布清单.md",
      size: 4210.0,
      dir: false,
    },
  ])
}

///|
/// The screen's file read (`json`, its text): its topics and calls as a source over the made-up one's other parts
/// (pictures, files), and its pages opened over Home.
pub fn fixture_json(json : String) -> Source {
  let screen = @json.parse(json) catch { _ => @halt.saying("the screen's JSON does not parse") }
  let topics : Array[(Json, Json)] = []
  for t in items(Some(screen), "topics") {
    match (field(Some(t), "topic"), field(Some(t), "value")) {
      (Some(k), Some(v)) => topics.push((k, v))
      _ => ()
    }
  }
  let calls = items(Some(screen), "calls")
  let fallback = flag(Some(screen), "fallback")
  let base = @sffixture.fixture("")
  let src : Source = {
    ..base,
    topic_read: fn(name, params) {
      let key : Map[String, Json] = { "topic": Json::string(name) }
      for k, v in params {
        key[k] = v
      }
      let want = Json::object(key)
      match topics.iter().find_first(fn(t) { t.0 == want }) {
        Some((_, v)) => { value: Some(v), error: None, version: 1 }
        None => if fallback { (base.topic_read)(name, params) } else { { value: None, error: None, version: 0 } }
      }
    },
    call: fn(name, params, done) {
      let said = match
        calls.iter().find_first(fn(c) { text(Some(c), "call") == name && field(Some(c), "params") == Some(params) }) {
        Some(c) => Some(c)
        None => calls.iter().find_first(fn(c) { text(Some(c), "call") == name })
      }
      match said {
        Some(c) => {
          // answered as the core's answer comes: an event from outside (its ticket ended: a frame for what it changed),
          // here at once
          let rt = @ui.runtime()
          let ticket = rt.outside_start("core: " + name)
          defer rt.outside_end(ticket)
          done(Ok(field(Some(c), "ok").unwrap_or(Json::null())))
        }
        None if fallback => (base.call)(name, params, done)
        None => {
          let rt = @ui.runtime()
          let ticket = rt.outside_start("core: " + name)
          defer rt.outside_end(ticket)
          done(Err({ "code": "unknown_call", "message": Json::string("the screen's JSON has no " + name) }))
        }
      }
    },
  }
  for p in items(Some(screen), "open") {
    let station = text(Some(p), "station")
    let session = text(Some(p), "session")
    let r : ChatRef = { station, session, title: "", station_name: "" }
    match text(Some(p), "page") {
      "chat" => open_chat(r)
      "history" => app.nav.push(History(r, text(Some(p), "key"), None))
      "settings" => open_setting(match text(Some(p), "key") { "" => "home"; k => k })
      "mode" => open_mode(text(Some(p), "key"))
      _ => ()
    }
  }
  src
}

///|
/// Reset the app and open a JSON screen (`fixture_json`), as `fixture_app` does for named modes.
pub fn fixture_json_app(json : String) -> Source {
  reset()
  fixture_json(json)
}

///|
/// What a fixture mode opens over Home at the start (src/sffix): a new chat, with one of its sheets; the bar's panel;
/// a place.
pub fn open_mode(mode : String) -> Unit {
  // (a connect's page whose model is drafted another station's: 借用 at its panel's foot)
  if mode == "settings-connect-borrow" {
    @sffixture.new_fix.borrow = true
  }
  // (someone else's preset picked: so before its page asks its new chat)
  if mode == "newchat-preset-theirs" || mode == "newchat-preset-theirs-long" {
    @sffixture.new_fix.preset = "p-ops"
  }
  if mode == "newchat-preset-many" {
    @sffixture.new_fix.presets.clear()
    @sffixture.new_fix.presets.push_iter(@sffixture.fix_preset_many().iter())
    @sffixture.new_fix.preset = "p-arch"
  }
  // (as long a name as a person gives one: its 复制「X」为我的预设 cut as 编辑「X」 is)
  if mode == "newchat-preset-theirs-long" {
    @sffixture.fix_other_rename("p-ops", "线上排障：告警、回滚与值班交接的完整手册")
  }
  if mode.has_prefix("newchat") {
    // (newchat-station-models-many: more of this station's than the panel shows without its search)
    if mode == "newchat-station-models" || mode == "newchat-station-empty" || mode == "newchat-station-models-many" {
      @sffixture.new_fix.station_models = true
      @sffixture.new_fix.crowded = mode == "newchat-station-models-many"
      @sffixture.new_fix.station_empty = mode == "newchat-station-empty"
    }
    if mode.has_prefix("newchat-crowded") || mode.has_prefix("newchat-providers") || mode == "newchat-tall-model" {
      // (it starts on the model that runs on three runtimes, on the one of them its combination names)
      let n = @sffixture.new_fix
      n.crowded = true
      n.tall = mode == "newchat-tall-model"
      n.unmarked = mode == "newchat-crowded-unmarked"
      n.providers = mode.has_prefix("newchat-providers")
      n.model = "deepseek-v4-1-flash"
      n.runtime = "dsh"
      n.d_model = n.model
      n.d_runtime = n.runtime
    }
    if mode == "newchat-tui-model" { @sffixture.new_fix.claude_mode = true }
    if mode == "newchat-ultrafast-model" {
      let n = @sffixture.new_fix
      n.crowded = true
      n.ultrafast = true
      n.model = "gpt-6.2-sol"
      n.runtime = "codex"
      n.d_model = n.model
      n.d_runtime = n.runtime
    }
    // (with models starred: under 喜欢 in its model's panel)
    if mode.has_suffix("-liked") {
      @sffixture.new_fix.liked.push_iter(["claude-sonnet-5", "kimi-for-coding"].iter())
    }
    // (with many models starred: more of them than the levels beside them)
    if mode.has_suffix("-many") {
      @sffixture.new_fix.liked.push_iter(["claude-sonnet-5", "kimi-for-coding"].iter())
      @sffixture.new_fix.liked.push_iter(@sffixture.fix_providers[:8].iter().map(fn(p) { p.0 }))
    }
    // (as many starred, the one picked the first of them: in a sheet risen from the foot the lowest, past what it
    // shows at first)
    if mode == "newchat-providers-model-far" {
      let n = @sffixture.new_fix
      n.liked.push_iter(["claude-sonnet-5", "kimi-for-coding"].iter())
      n.liked.push_iter(@sffixture.fix_providers[:8].iter().map(fn(p) { p.0 }))
      n.model = "claude-sonnet-5"
      n.d_model = n.model
    }
    match mode {
      "newchat-station" => @sfpages.new_chat_ask("station")
      "newchat-preset" | "newchat-preset-many" => @sfpages.new_chat_ask("preset")
      "newchat-preset-new" => @sfpages.new_chat_ask("preset-new")
      "newchat-preset-edit" => @sfpages.new_chat_ask("preset-edit")
      "newchat-preset-add" => @sfpages.new_chat_ask("preset-add")
      "newchat-preset-new-add" => @sfpages.new_chat_ask("preset-new-add")
      "newchat-preset-new-browse" => @sfpages.new_chat_ask("preset-new-browse")
      // (the picker in a folder of repositories; 从 Git 克隆; a new one's dialog with a clone under way and one failed)
      "newchat-preset-new-browse-repos" => @sfpages.new_chat_ask("preset-new-browse-repos")
      "newchat-preset-new-clone" => @sfpages.new_chat_ask("preset-new-clone")
      "newchat-preset-new-clones" => {
        let clones : Array[Json] = [
            {
              "id": "c-bad",
              "url": "acme/private",
              "repo": "github.com/acme/private",
              "name": "private",
              "state": "failed",
              "error": "仓库不存在或没有权限",
              "by": "me@example.com",
              "startedAt": 1793500000000.0,
            },
            {
              "id": "c-web",
              "url": "acme/shop",
              "repo": "github.com/acme/shop",
              "name": "shop",
              "state": "cloning",
              "error": "",
              "by": "me@example.com",
              "startedAt": 1793500000000.0,
            },
          ]
        @sffixture.new_fix.clones.push_iter(clones.iter())
        @sfpages.new_chat_ask("preset-new-clones")
      }
      "newchat-preset-picked" => @sffixture.new_fix.preset = "p-sf"
      // (the other members' presets, a level further in from the menu; none of them yet; the menu with someone
      // else's picked, whose it is after its name and 复制「X」为我的预设 in place of 编辑)
      "newchat-preset-others" => @sfpages.new_chat_ask("preset-others")
      "newchat-preset-others-none" => {
        @sffixture.new_fix.others.clear()
        @sfpages.new_chat_ask("preset-others")
      }
      "newchat-preset-theirs" | "newchat-preset-theirs-long" => @sfpages.new_chat_ask("preset")
      // (its preset names a model Maple does not run: the stations offered; on Maple, said so)
      "newchat-preset-model-station" => {
        @sffixture.new_fix.preset = "p-sf"
        @sffixture.new_fix.model_bound = true
        @sfpages.new_chat_ask("station")
      }
      "newchat-preset-model-missing" => {
        @sffixture.new_fix.preset = "p-sf"
        @sffixture.new_fix.model_bound = true
        @sffixture.new_fix.station = "st2"
      }
      "newchat-preset-bound" => {
        @sffixture.new_fix.preset = "p-sf"
        @sffixture.new_fix.bound = true
      }
      "newchat-station-models" | "newchat-station-empty" | "newchat-station-models-many" | "newchat-tui-model" | "newchat-ultrafast-model" | "newchat-model" | "newchat-crowded-model" | "newchat-tall-model" | "newchat-crowded-model-liked" | "newchat-providers-model" | "newchat-providers-model-liked" | "newchat-providers-model-many" | "newchat-providers-model-far" =>
        @sfpages.new_chat_ask("model")
      _ => ()
    }
    // (risen once what it is over is said: the core's newChat it asks as it comes on top (page_opens_node) the
    // mode's, a page made once as nodes reading it then)
    app.nav.rise(NewChat)
  } else if mode == "home-bars" {
    bar.open_panel(true, at=0.0)
  } else if mode == "place" {
    app.nav.replace(Files)
  } else if mode == "archived" {
    // 已归档: on the wide frame the sidebar's list of them, the newest beside it (lists.mbt archive_pane); laid out
    // Small its page
    app.nav.push(Archived)
  } else if mode == "place-stations-tasks" {
    // the stations' place with those that only run tasks in its list (the settings' rigs_fixture.mbt), the first of
    // them picked: its page beside the list
    app.nav.replace(Place("stations"))
    @sfdesk.place_pick_station("ws1", "ws1/aa11")
  } else if mode == "place-stations-devices" {
    // the stations' place with the workspace's devices under its stations (the settings' devices_fixture.mbt)
    app.nav.replace(Place("stations"))
  } else if mode == "place-profiles-offer" {
    // the profiles' place with Willow's own Codex login offered with its allowance (settings-profiles-offer's)
    @settings.fixture_page("settings-profiles-offer") |> ignore
    app.nav.replace(Place("profiles"))
  } else if mode == "place-profiles-sum-a" {
    @settings.fixture_page("settings-profiles-sum-a") |> ignore
    @settings.profiles_narrow_overview.set(false)
    app.nav.replace(Place("profiles"))
  } else if mode == "place-profiles-sum-overview" {
    // (the bottom bar's Profile switched to 概览, its own: profiles_place_overview)
    @settings.fixture_page("settings-profiles-sum-a") |> ignore
    @settings.profiles_narrow_overview.set(false)
    @settings.profiles_place_overview.set(true)
    app.nav.replace(Place("profiles"))
  } else if mode == "terminal" || mode.has_prefix("terminal-") {
    // one of its terminals: typed into here (terminal, terminal-kb, terminal-keys, terminal-center), by someone else
    // with 接管 over it (terminal-taken), or ended with 重新打开 (terminal-ended)
    match mode {
      "terminal-kb" => @sfpages.terminal_fixture_ask("kb")
      "terminal-keys" => @sfpages.terminal_fixture_ask("keys")
      "terminal-center" => @sfpages.terminal_fixture_ask("center")
      "terminal-scrolled" => @sfpages.terminal_fixture_ask("scrolled")
      _ => ()
    }
    let tid = match mode {
      "terminal-taken" => "term-1"
      "terminal-ended" => "term-ended"
      _ => "term-2"
    }
    open_setting("station:ws1/st1")
    app.nav.push(Terminal({ station: "ws1/st1", terminal: tid, watch: false, cwd: "" }))
  } else if mode == "place-remote-tabs" {
    app.nav.replace(Place("remote"))
  } else if mode == "place-remote-home" {
    // (Home, as the app starts, over 远程's stations: Maple online beside Willow)
    ()
  } else if mode.has_prefix("place-") {
    // a place of the rail's in the wide frame: place-stations, place-profiles, place-connects,
    // place-usage
    app.nav.replace(Place(mode.exact_view(start=6).to_owned()))
  } else if mode.has_prefix("files-") {
    // the files' page in the wide frame at Willow's 文档: files-columns (设计稿 open beside it, chosen),
    // files-tree (设计稿 opened in place), files-list, files-preview (发布清单.md previewed beside it), files-split (two
    // tabs, the one shown split)
    let docs : DriveAt = { station: "ws1/st1", root: Some(@sffixture.fix_docs), path: "" }
    app.nav.push(Files)
    // (in columns, 设计稿 open beside 文档: the page at it, chosen in the column before as coming to it chooses)
    app.nav.push(Drive(if mode == "files-columns" { { ..docs, path: "设计稿" } } else { docs }))
    // what the made-up core is told before the first frame: the way shown, a tree's folder open, what is chosen
    let browse = fn(params : Map[String, Json]) {
      let o : Map[String, Json] = {
        "owner": "page",
        "station": "ws1/st1",
        "root": Json::string(@sffixture.fix_docs),
        "path": "",
        "place": Json::string(@sfpages.place_name("page/0")),
      }
      for k, v in params {
        o[k] = v
      }
      @sffixture.fix_browse_do(None, mode, "drive.browse", Json::object(o)) |> ignore
    }
    match mode {
      "files-columns" => @sffixture.fix_browse_prefs_set({ "driveViews": { "page": "columns" } }) |> ignore
      "files-favorite" | "files-favorite-dark" => {
        // A saved favorite and an old pinned root name the same folder, for a before/after comparison.
        let saved : Json = [{ "station": "ws1/st1", "root": Json::string(@sffixture.fix_docs), "path": "", "name": "文档" }]
        @sffixture.fix_browse_prefs_set({ "driveFavorites": { "ws1": Json::string(saved.stringify()) } }) |> ignore
      }
      "files-tree" => {
        @sffixture.fix_browse_prefs_set({ "driveViews": { "page": "tree" } }) |> ignore
        browse({ "act": "tree", "folder": "设计稿", "view": "tree" })
        @sfpages.nav_open("ws1/st1")
      }
      "files-list" => @sffixture.fix_browse_prefs_set({ "driveViews": { "page": "list" } }) |> ignore
      // a copy asked about a name there: 说明.txt into 会议记录, which has one
      "files-clash" =>
        @sfpages.drag_ask({
          into: { station: "ws1/st1", root: Some(@sffixture.fix_docs), path: "会议记录" },
          into_name: "会议记录",
          total: 1,
          clashes: [
            {
              name: "说明.txt",
              dir: false,
              size: 2048.0,
              station: "Maple",
              there: dv_entry(@sffixture.fix_entry("说明.txt", false, 320, "10/01")),
            },
          ],
          answers: {},
          all: false,
          done: fn(_) {  },
        })
      // what comes and goes open (the rail's key, transfers.mbt): a copy to Maple going (as the core says it)
      "files-transfers" => {
        @sffixture.fix_transfer({
          "from": { "station": "ws1/st1", "root": Json::string(@sffixture.fix_docs), "path": "", "names": ["演示录屏.mp4"] },
          "to": { "station": "ws1/st2", "root": "/Users/lin/照片", "path": "" },
          "move": false,
        })
        @sfdesk.transfers_open()
      }
      // the preview beside the list, 发布清单.md chosen
      "files-preview" => {
        @sffixture.fix_browse_prefs_set({ "driveViews": { "preview": "shown" } }) |> ignore
        browse({ "act": "choose", "view": "columns", "folder": "", "name": "发布清单.md" })
      }
      // two tabs, the one shown split: 文档 in front, the home beside it
      "files-split" =>
        @sffixture.fix_browse_prefs_set({ "filesTabs": { "ws1": Json::string(@sffixture.fix_split_tabs().stringify()) } }) |> ignore
      _ => ()
    }
  } else if mode == "rail-menu" {
    // the rail's menu, as a right click on 对话 opens it (rail.mbt rail_menu: the places not in it, each its ＋)
    @sfdesk.open_rail_menu("chats")
  } else if mode == "switcher" || mode == "switcher-found" {
    // ⌘K in the wide frame (sfdesk/switcher.mbt): with nothing typed, and with 签名 typed (what the search finds)
    @sfdesk.switcher_open_with(if mode == "switcher-found" { "签名" } else { "" })
  } else if mode == "home-sheet" || mode == "home-accounts" {
    // (home-accounts: two accounts signed in, what a new workspace asks which of)
    home_sheet_at_start.val = true
  }
}

///|
/// MBUI_FIXTURE=player-…: the made-up drive's film (the made-up core's: play_fixture) played over its folder's pages,
/// where its player stands.
fn open_play_fixture(mode : String) -> Unit {
  guard @sffixture.play_fixture(mode) is Some((at, pin)) else { return }
  let docs : DriveAt = { ..at, path: "" }
  app.nav.push(Files)
  app.nav.push(Drive(docs))
  app.nav.push(Drive({ ..docs, path: @sffixture.fix_films }))
  app.nav.push(DrivePlay(at))
  match pin {
    Some(s) => @sf.playing_for(reader_key(at)).media.pin(s)
    None => ()
  }
}

///|
/// MBUI_FIXTURE=service…: the first row's chat, its service's page over it.
fn open_service_fixture(mode : String) -> Unit {
  match mode {
    "service" | "service-sized" | "service-restart" | "service-stopped" | "service-marks" | "service-marks-dark" => {
      app.nav.push(Chat({ station: "ws1/st1", session: "s-c1", title: "整理发布清单", station_name: "Willow" }))
      app.nav.push(Service("ws1/st1", "j-web"))
      if mode == "service-sized" {
        svc_viewports[service_key("ws1/st1", "j-web")] = Some({ width: 390, height: Some(844) })
      }
      // (`-marks`: two marks picked on the page, the first said beside its pin, the second's note open; on either
      // theme)
      if mode.has_prefix("service-marks") {
        let m = @sfbase.service_page_for("ws1/st1", "j-web").marks
        let mark = fn(n : Int, kind : String, label : String, words : String, rect : (Double, Double, Double, Double), comment : String) -> @sfbase.PageMark {
          { n, path: "/", vw: 390, vh: 600, label, kind, selector: "main > " + label, text: words, rect, component: "", comment }
        }
        m.marks.push(mark(1, "按钮", "button.go", "构建", (20.0, 120.0, 100.0, 30.0), "把按钮换成主色"))
        m.marks.push(mark(2, "标题", "h1", "本周发布", (40.0, 320.0, 200.0, 40.0), ""))
        m.at[1] = (20.0, 120.0, 100.0, 30.0)
        m.at[2] = (40.0, 320.0, 200.0, 40.0)
        m.css_w = 390.0
        m.css_h = 600.0
        m.editing = Some(2)
      }
    }
    _ => ()
  }
}

///|
/// MBUI_FIXTURE=share-in…: the sheet raised over Home.
fn open_share_fixture(mode : String) -> Unit {
  match mode {
    // (`-over`: over another app, as the browser extension's window and Android's share sheet show it)
    "share-in" | "share-in-stations" | "share-in-over" => {
      share_over.set(mode == "share-in-over")
      share_in.shared.set(Some(@sffixture.fix_shared))
      // (put up by the first frame, in a sheet or the wide panel as the window is: share_in_frame)
      share_in.env_taken.set(true)
      share_in.choosing.set(mode == "share-in-stations")
    }
    // files from another app's share sheet (ACTION_SEND_MULTIPLE): two pictures (the chat fixture's) and a document
    "share-in-files" => {
      share_in.shared.set(Some(("", None)))
      share_in.files.set([
        { name: "home-after.png", bytes: Bytes::make(182345, b'\x00'), image: @sffixture.fixture_file("home-after.png") },
        { name: "compare.png", bytes: Bytes::make(96512, b'\x00'), image: @sffixture.fixture_file("compare.png") },
        { name: "季度数据.csv", bytes: Bytes::make(23110, b'\x00'), image: "" },
      ])
      share_in.env_taken.set(true)
    }
    _ => ()
  }
}

///|
/// The screens: every mode sffix opens (fixture_open.mbt open_fixture_mode, settings/fixture.mbt fixture_page).
/// Built on demand so shipping builds strip it out completely with zero startup cost.
pub fn fixture_corner_modes() -> Array[String] {
  let modes = [
    // (webdemo: the web's demo workspace, its chats' rows with people's faces, which chat's fixture has none)
    "webdemo", "home", "board", "home-bars", "home-jobs", "home-shared-bell", "home-sheet", "home-news", "new-workspace", "new-workspace-code", "rail-menu", "landing", "landing-invited", "blocked", "place",
    "switcher", "switcher-found", "keys-dialog", "search", "search-jobs", "search-results", "chat", "chat-agent",
    "chat-agent-unsaid", "chat-answering", "chat-attach", "chat-attach-row", "chat-cards", "chat-compose", "chat-download", "chat-failed", "chat-feedback", "chat-image-coming",
    "chat-file-links", "chat-find", "chat-flash", "chat-flash-mine", "chat-flash-notice", "chat-history-side",
    // (its agent at work: what the history's head shows only then, #6246's stop among its keys)
    "chat-history-side-working", "chat-info", "chat-info-bare", "chat-job",
    "chat-jobs", "chat-jobs-pop", "chat-jobs-side", "chat-letters", "chat-letters-info", "chat-letters-open",
    "chat-letters-pop", "chat-letters-side", "chat-things", "chat-things-side", "chat-info-pulls", "chat-link-menu", "chat-loading", "chat-login", "chat-long", "chat-md",
    "chat-model-pop", "chat-model-accounts", "chat-need", "chat-peek", "chat-pick", "chat-preview-apk", "chat-preview-audio",
    "chat-preview-code", "chat-preview-csv", "chat-preview-html", "chat-preview-image", "chat-preview-md",
    "chat-preview-none", "chat-preview-pdf", "chat-preview-step", "chat-preview-swipe", "chat-preview-video",
    "chat-publish", "chat-quote", "chat-screens", "chat-sending", "chat-service-side", "chat-station-file", "chat-station-files",
    "chat-station-ref", "chat-station-sheet", "chat-tabs-side", "chat-view-side", "chat-view-side-image", "chat-view-side-video", "chat-view-side-audio", "chat-update", "chat-vault-typed", "chat-viz", "chat-working", "chat-rig",
    // (对话目录: the long chat away from its end, its rail or round button; its outline open; words found in it)
    "chat-outline-away", "chat-outline", "chat-outline-find", "archived",
    "history", "history-details", "drive", "drive-roots", "drive-download", "drive-empty", "drive-loading", "drive-sub", "drive-upload",
    "files", "files-add-folder", "files-clash", "files-columns", "files-list", "files-preview", "files-split", "files-transfers",
    "files-tree", "place-stations", "place-profiles", "place-remote", "place-remote-tabs", "chat-remote", "chat-terminal-side", "reader", "reader-bars", "reader-contents", "reader-layout", "reader-md", "newchat", "newchat-files", "newchat-lend", "share-card", "share-card-dark",
    "newchat-model", "newchat-profiles", "newchat-reading", "newchat-station",
    "newchat-station-models", "newchat-station-empty",
    // (a preset's dialog and its steps further in: 添加目录, the folder picker at a station's home and in a folder of
    // repositories, 从 Git 克隆, a clone under way and one failed among its folders)
    "newchat-preset-new", "newchat-preset-new-add", "newchat-preset-new-browse", "newchat-preset-new-browse-repos",
    "newchat-preset-new-clone", "newchat-preset-new-clones",
    // (the presets' menu: one's own; many with search; the other members', a level further in, and none of them; someone else's picked)
    "newchat-preset", "newchat-preset-many", "newchat-preset-others", "newchat-preset-others-none", "newchat-preset-theirs",
    "newchat-preset-theirs-long", "player-audio", "player-audio-failed", "player-ended",
    "player-failed", "player-opening", "player-video", "service", "service-restart", "service-sized", "service-stopped", "share-in",
    "share-in-files", "share-in-stations", "lock-checking", "lock-confirming", "lock-code", "lock-failed", "lock-finding", "lock-nocode",
    "lock-none", "lock-security", "lock-upgrade", "lock-waiting", "lock-wrong",
    // (a web page left out of an upgraded workspace that nobody can approve there: its waiting page, its 安全)
    "lock-needs-app", "lock-needs-app-security", "lock-out", "lock-out-security",
    // (its person's own lock: none of their devices answering, 我的其它设备都不在了 offered; made their only trusted
    // device, whom to ask; begun anew on another device, 是我做的，继续; each its waiting page and its 安全)
    "lock-restart", "lock-restart-security", "lock-rebound", "lock-rebound-security", "lock-replaced",
    "lock-replaced-security", "screen-agent-driving",
    "screen-agent-paused", "screen-clipboard-driving", "screen-clipboard-old-station", "screen-connecting",
    "screen-denied", "screen-ended", "screen-failed", "screen-files-done", "screen-files-going", "screen-full",
    "screen-full-tools", "screen-gone", "screen-keys", "screen-live", "screen-login-fill", "screen-login-pick", "screen-not-drivable", "screen-outdated", "screen-pages", "screen-read-only",
    "screen-reconnecting", "screen-trackpad", "screen-trackpad-command", "screen-user-pages", "screen-user-tabs", "screen-windows", "screen-window", "settings-home", "settings-appearance", "settings-experimental",
    "settings-me", "settings-me-reading", "settings-workspace", "settings-security", "settings-vault",
    "settings-vault-items", "settings-vault-item", "settings-stations", "settings-stations-unprotected", "settings-station", "settings-station-unprotected", "settings-station-terminals", "settings-station-offline", "settings-station-env", "settings-station-processes",
    "settings-station-mark", "settings-station-lower", "settings-station-versions", "settings-station-updated", "settings-station-network", "settings-station-copies", "settings-station-copies-alone",
    "settings-station-restore", "settings-station-restore-offer", "settings-station-restore-confirm", "settings-station-restore-confirm-long",
    "settings-station-restored",
    // (a station retired: its panel, Maple chosen, two up and none chosen, none up, a joined workspace's, a long name;
    // then 迁移's steps as it goes, sending, all sent waiting for the hand-over, back there after one failed, paused,
    // failed, its accounts moving, done, done with accounts left; and a
    // station taking retired ones' chats in)
    "settings-station-retire-panel", "settings-station-retire-panel-pick", "settings-station-retire-panel-none", "settings-station-retire-panel-joined", "settings-station-retire-panel-long", "settings-station-retire-sending", "settings-station-retire-sent", "settings-station-retire-sent-failed", "settings-station-retire-quiet", "settings-station-retire-failed", "settings-station-retire-accounts", "settings-station-retire-done", "settings-station-retire-done-left", "settings-station-taking", "settings-station-move", "settings-station-move-chats", "settings-station-move-ended", "settings-station-move-empty", "settings-station-move-none", "settings-station-move-all", "settings-station-move-section", "settings-station-move-offered", "settings-profile-move", "settings-profile-move-key",
    "settings-stations-add",
    "settings-stations-existing", "settings-stations-command", "settings-first-station", "settings-adb", "settings-adb-unpaired", "settings-adb-pairing", "settings-adb-connected", "settings-adb-failed", "settings-adb-chats", "settings-adb-chats-long", "settings-adb-lock-two", "settings-adb-idle", "settings-adb-desk",
    // (a request for the phone waiting on a phone that lacks something; granted, the card under it for each kind of step
    // left: the switch off, Developer options, Wi-Fi, Wireless debugging (refused the app), the pairing dialog, the code,
    // the phone's own prompt; and connected)
    "chat-phone-lacks", "chat-phone-step-off", "chat-phone-step-developer", "chat-phone-step-wifi", "chat-phone-step-wireless",
    "chat-phone-step-refused", "chat-phone-step-code", "chat-phone-linked-unpaired", "chat-phone-linked-unauthorized",
    "chat-phone-linked-connected",
    "settings-profiles", "settings-profiles-monthly", "settings-profiles-fable", "settings-profiles-own3", "settings-profiles-week-fable", "settings-profiles-several",
    "settings-profile-account", "settings-profiles-station",
    "settings-profile", "settings-profile-fable", "settings-profile-own3", "settings-profile-week-fable", "settings-profile-quota", "settings-profile-quota-kinds",
    "settings-profile-lower", "settings-profile-unshareable", "settings-profile-login", "settings-profile-login-failed", "settings-profile-quota-failed", "settings-profile-verify", "settings-profile-copy",
    "settings-profile-blocked", "settings-profile-signin", "settings-profile-key", "settings-new-profile",
    // (添加账号 with three stations up to choose from, #6030; a key's form with a region and a protocol to choose)
    "settings-new-profile-stations", "settings-new-profile-key",
    "settings-connects", "settings-connect", "settings-connect-menu", "settings-connect-mode", "settings-connect-run",
    "settings-new-connect", "settings-new-connect-platform", "settings-new-connect-scan", "settings-new-connect-app",
    // (a Comma connect's model step, and the pages of a Comma and a Feishu connect, none of their sessions yet)
    "settings-new-connect-comma", "settings-connect-comma", "settings-connect-feishu",
    // (Group offered and picked, a new group connect's server filled in, and a group connect's page)
    "settings-new-connect-platform-group", "settings-new-connect-group", "settings-connect-group",
    "settings-slack-app", "settings-memory", "settings-memory-doc", "settings-usage", "settings-archive", "settings-kept",
    "settings-kept-many", "settings-vault-off", "settings-vault-plain", "settings-vault-waits", "settings-vault-confirm", "settings-vault-syncing", "settings-vault-words", "settings-vault-add",
    "settings-vault-editor", "settings-vault-recover", "settings-lock-prompt", "settings-lock-prompt-role", "settings-add-people",
    "settings-workspace-mark", "settings-local-fonts", "settings-policy", "settings-policy-text",
    "settings-policy-option", "settings-security-join", "settings-security-off", "settings-security-open", "settings-security-pending", "settings-security-confirm", "settings-security-root", "settings-security-root-off", "settings-security-again", "settings-security-upgrade-station", "settings-security-upgrade-station-not", "settings-security-upgrade-member", "settings-security-upgrade-device", "settings-security-upgrade-many", "settings-security-upgrade-other", "settings-security-upgrade-updating", "settings-stations-tasks", "place-stations-tasks", "settings-station-tasks", "settings-station-tasks-other", "settings-station-tasks-locked", "settings-stations-devices", "place-stations-devices", "settings-station-devices",
    "settings-fonts", "settings-fonts-code",
    "settings-decisions", "settings-completion", "settings-bars", "settings-about", "settings-changelog", "settings-prices",
    "settings-notify-off", "settings-notify-denied",
    // (the stations' newer releases waiting: their key over Home, their dialog open: sfpages station_updates.mbt)
    "home-station-updates", "station-updates", "home-station-updates-app", "station-updates-app",
    // (a terminal's page, typed into here and by someone else: terminal_wbtest.mbt; its station's list is settings-station-terminals, beside settings-station)
    "terminal", "terminal-taken",
    // (the board with a card's chat open beside it, its edge at rest: last, so the real size's sweep gives the shell's
    // ways a chat reads (chatRow) to chat's screen first, as before it came: sfapp_realsize real_size_test.mbt real_size_given_here)
    "board-side",
  ]
  // (and the card to share in each of its other looks: share_looks.mbt)
  for k in @sfpages.share_look_keys()[1:] {
    modes.push("share-card-" + k)
  }
  modes
}
