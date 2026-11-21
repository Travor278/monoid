// An agent reads or changes a session's runtime configuration (station/src/sessions/chat-configure.ts),
// here or on another station of its workspace.

///|
pub let configure_method = "session.configure"

///|
let configure_model_change_keys : Array[String] = [
  "runtime", "model", "effort", "speed", "fast", "context", "preset", "repick",
]

///|
let max_ancestor_hops : Int = 16

///|
priv enum LeadAction {
  Person
  Me(String, String, String?, Array[(String, String)])
}

///|
let configure_runtime_kinds : Array[String] = [
  "claude", "codex", "dsh", "grok", "cursor", "devin", "hermes", "agy", "pi",
]

///|
fn cfg_trimmed(v : Json?) -> String? {
  match v {
    None | Some(Null) => None
    Some(x) => {
      let s = js_trim(js_string(x))
      if s == "" { None } else { Some(s) }
    }
  }
}

///|
fn cfg_parse_for(args : Json) -> String? raise Thrown {
  match get(args, "for") {
    None => None
    Some(String("me")) => Some("me")
    Some(String("person")) => Some("person")
    _ => raise failed("for must be \"me\" or \"person\"")
  }
}

///|
fn cfg_speed(v : Json) -> String? {
  match v {
    String(s) =>
      match js_trim(s).to_lower() {
        "standard" => Some("standard")
        "fast" => Some("fast")
        "ultrafast" => Some("ultrafast")
        _ => None
      }
    _ => None
  }
}

///|
fn Storage::describe_session(self : Storage, row : Json) -> Json raise {
  let key = str(row, "key").unwrap_or("")
  let link = match (self.st.hub.world.link)(key) {
    Some(l) if l != "" => js(l)
    _ => Json::null()
  }
  let running = match get(row, "running") {
    Some(True) => true
    Some(Number(n, ..)) => n != 0.0
    _ => false
  }
  let opener = self.st.store.opener_of(js(key))
  let led = get(opener, "led") is Some(True)
  let leader = if led {
    let ps = str(opener, "parentStation").unwrap_or("")
    let p = str(opener, "parent").unwrap_or("")
    if ps != "" {
      js("\{ps}/\{p}")
    } else {
      js(p)
    }
  } else {
    Json::null()
  }
  jo([
    ("session", js(key)),
    ("link", link),
    ("runtime", get(row, "runtime").unwrap_or(Json::null())),
    ("model", get(row, "model").unwrap_or(Json::null())),
    ("effort", get(row, "effort").unwrap_or(Json::null())),
    ("speed", get(row, "speed").unwrap_or(Json::null())),
    ("fast", get(row, "fast").unwrap_or(Json::null())),
    ("context", get(row, "context").unwrap_or(Json::null())),
    ("profile", get(row, "profile").unwrap_or(Json::null())),
    ("running", jb(running)),
    ("archived", jb(!nullish(get(row, "archivedAt")))),
    ("created_by", get(row, "createdBy").unwrap_or(Json::null())),
    ("led", jb(led)),
    ("leader", leader),
  ])
}

///|
fn Storage::local_ancestors(self : Storage, start : String) -> Array[(String, String)] raise {
  let out : Array[(String, String)] = []
  let seen : Array[String] = [start]
  let mut cur = start
  for _ in 0..<max_ancestor_hops {
    let op = self.st.store.opener_of(js(cur))
    if nullish(Some(op)) || get(op, "led") is Some(False) {
      break
    }
    let ps = str(op, "parentStation").unwrap_or("")
    let p = str(op, "parent").unwrap_or("")
    out.push((ps, p))
    if ps != "" || seen.contains(p) {
      break
    }
    seen.push(p)
    cur = p
  }
  out
}

///|
fn Storage::own_title(self : Storage, key : String) -> String? {
  let row = self.session(key) catch { _ => None }
  match row {
    Some(r) => cfg_trimmed(get(r, "title"))
    None => None
  }
}

///|
fn Storage::chat_title_of(self : Storage, key : String) -> String {
  self.own_title(key).unwrap_or(key)
}

///|
async fn Storage::say_lead_notice(self : Storage, target_key : String, i18n_key : String, from : String) -> Unit {
  let latest = self.st.threads.latest_thread(js(target_key)) catch { _ => Json::null() }
  if nullish(Some(latest)) {
    return
  }
  let thread = get(latest, "thread").unwrap_or(Json::null())
  let connect = str(latest, "connect").unwrap_or("")
  let lang = self.ask("fn.stationLang", []) catch { _ => js("en") }
  let text = as_str(Some(self.ask("fn.tr", [lang, js(i18n_key), jo([("from", js(from))])]) catch { _ => js(i18n_key) })).unwrap_or(i18n_key)
  try {
    let ts = self.ask("hub.chatPost", [
      js(connect),
      jo([
        ("channel", get(thread, "channel").unwrap_or(Json::null())),
        ("threadTs", get(thread, "threadTs").unwrap_or(Json::null())),
      ]),
      js(mark_notice(text)),
      ja([]),
    ])
    ignore(
      self.with_threads(th => th.insert_message(
        @jsjson.JValue::of_json(jo([
          ("thread", get(thread, "id").unwrap_or(Json::null())),
          ("ts", ts),
          ("authorKind", js(station_author)),
          ("author", js(station_author)),
          ("text", js(text)),
          ("attachments", ja([])),
        ])),
      )),
    )
  } catch {
    e => self.log("warn", "hub", "a lead change was not said in the chat", jo([("session", js(target_key)), ("error", js(message_of(e)))]))
  }
}

///|
async fn Storage::validate_lead_here(self : Storage, target_key : String, lead : LeadAction) -> Unit {
  guard lead is Me(parent_station, parent, _, parent_ancestors) else { return }
  if parent_station == "" && target_key == parent {
    raise failed("cannot lead your own chat")
  }
  let thread = try thread_of(self.session_thread_of(target_key)) catch {
    _ => raise failed("only still.fail chats can be led as sub-chats")
  }
  if str(thread, "surface") != Some(stillfail_surface) {
    raise failed("only still.fail chats can be led as sub-chats")
  }
  if parent_station == "" {
    if self.local_ancestors(parent).iter().any(a => a.0 == "" && a.1 == target_key) {
      raise failed("cannot lead a chat that already leads this one")
    }
    return
  }
  let here = (self.st.hub.world.link)(target_key).bind(linked_station).unwrap_or("")
  for a in parent_ancestors {
    if here != "" && a.0 == here {
      if a.1 == target_key {
        raise failed("cannot lead a chat that already leads this one")
      }
      if self.local_ancestors(a.1).iter().any(b => b.0 == "" && b.1 == target_key) {
        raise failed("cannot lead a chat that already leads this one")
      }
    }
  }
}

///|
async fn Storage::clear_remote_mirror(self : Storage, caller_key : String, remote_station : String, child_key : String) -> Unit {
  guard self.peers_of(caller_key) is Some(call) else { return }
  let here = (self.st.hub.world.link)(child_key).bind(linked_station).unwrap_or("")
  try {
    ignore(call(remote_station, jo([
      ("method", js(configure_method)),
      ("session", js(caller_key)),
      ("leadMirror", jo([("childStation", js(here)), ("child", js(child_key)), ("led", jb(false))])),
    ])))
  } catch {
    e => self.log("warn", "hub", "could not clear remote opened_chats mirror", jo([("station", js(remote_station)), ("child", js(child_key)), ("error", js(message_of(e)))]))
  }
}

///|
async fn Storage::resolve_configure_here(
  self : Storage,
  chat : String,
  ws : String?,
  caller : String?,
) -> String {
  if chat == "" || chat.to_lower() == "self" {
    guard caller is Some(c) else { raise failed("chat is required") }
    return c
  }
  let reference = if chat.contains("/o/") || chat.contains("/chats/") {
    match chat.find("?") {
      Some(at) => cut(chat, 0, end=at)
      None => chat
    }
  } else {
    chat
  }
  match self.named(reference, ws) {
    Session(k, _) => {
      if ws is Some(w) && !self.in_workspace(k, w) {
        raise failed("that chat is in another workspace: only this workspace's chats can be configured")
      }
      k
    }
    Thread(t) => {
      if !self.thread_in(t, ws) {
        raise failed("that chat is in another workspace: only this workspace's chats can be configured")
      }
      if str(t, "home") is Some(h) {
        return h
      }
      let agents = sessions_of(self.st.threads.thread_sessions(get(t, "id").unwrap_or(Json::null())))
      if agents.length() == 0 {
        raise failed("\{reference} has no agent session to configure")
      }
      if agents.length() > 1 {
        raise failed("\{reference} has several agents; pass one session key as chat: \{agents.join(", ")}")
      }
      agents[0]
    }
  }
}

///|
async fn Storage::parse_configure_change(self : Storage, ws : String?, args : Json) -> Json? {
  let obj = match args {
    Object(m) => m
    _ => return None
  }
  if !configure_model_change_keys.iter().any(k => obj.contains(k)) {
    return None
  }
  if cfg_trimmed(obj.get("preset")) is Some(preset_name) {
    for k in ["runtime", "model", "effort", "speed", "fast", "context"] {
      if obj.contains(k) {
        raise failed("preset cannot be combined with runtime, model, effort, speed, fast or context")
      }
    }
    let scope = match ws {
      Some(w) => Some(w)
      None => self.st.hub.workspaces().get(0)
    }
    let all = items(Some(self.ask("presets.list", [jopt(scope)])))
    let lower = preset_name.to_lower()
    let found = match all.iter().find_first(p => str(p, "id") == Some(preset_name)) {
      Some(p) => Some(p)
      None => all.iter().find_first(p => str(p, "name").unwrap_or("").to_lower() == lower)
    }
    guard found is Some(preset) else {
      if all.is_empty() {
        raise failed("no preset \{preset_name}: this station has none")
      }
      let names = all.map(p => str(p, "name").unwrap_or("")).join(", ")
      raise failed("no preset \{preset_name} on this station; its presets: \{names}")
    }
    let pname = str(preset, "name").unwrap_or(preset_name)
    guard get(preset, "model") is Some(Object(_) as pm) else {
      raise failed("the preset \{pname} does not configure a model")
    }
    let out : Map[String, Json] = {}
    if str(pm, "runtime") is Some(rt) && rt != "" {
      out["runtime"] = js(rt)
    }
    out["model"] = get(pm, "model").unwrap_or(Json::null())
    out["effort"] = get(pm, "effort").unwrap_or(Json::null())
    out["fast"] = get(pm, "fast").unwrap_or(Json::null())
    out["speed"] = get(pm, "speed").unwrap_or(Json::null())
    out["context"] = get(pm, "context").unwrap_or(Json::null())
    match get(pm, "profiles") {
      Some(ps) => out["profiles"] = ps
      None =>
        match get(pm, "profile") {
          Some(p) => out["profile"] = p
          None => out["profile"] = Json::null()
        }
    }
    if obj.get("repick") is Some(rep) {
      match rep {
        True => out["repick"] = jb(true)
        False => ()
        _ => raise failed("repick must be true or false")
      }
    }
    return Some(Json::object(out))
  }
  let out : Map[String, Json] = {}
  if obj.get("runtime") is Some(v) {
    match cfg_trimmed(Some(v)) {
      Some(rt) if configure_runtime_kinds.contains(rt) => out["runtime"] = js(rt)
      _ => raise failed("runtime must be one of \{configure_runtime_kinds.join(", ")}")
    }
  }
  if obj.get("model") is Some(v) {
    out["model"] = match v {
      Null => Json::null()
      _ => jopt(cfg_trimmed(Some(v)))
    }
  }
  if obj.get("effort") is Some(v) {
    out["effort"] = match v {
      Null => Json::null()
      _ => jopt(cfg_trimmed(Some(v)))
    }
  }
  if obj.get("speed") is Some(v) {
    if v is Null || cfg_trimmed(Some(v)) is None {
      out["speed"] = Json::null()
    } else {
      match cfg_speed(v) {
        Some(sp) => out["speed"] = js(sp)
        None => raise failed("speed must be standard, fast or ultrafast")
      }
    }
  }
  if obj.get("fast") is Some(v) {
    match v {
      Null | True | False => out["fast"] = v
      _ => raise failed("fast must be true, false or null")
    }
  }
  if obj.get("context") is Some(v) {
    out["context"] = match v {
      Null => Json::null()
      Number(0.0, ..) => Json::null()
      _ =>
        match @session_hub.context_asked(self.st.hub.words, Some(v), "en") {
          Some(Some(n)) => jn(n)
          _ => Json::null()
        }
    }
  }
  if obj.get("repick") is Some(v) {
    match v {
      True => out["repick"] = jb(true)
      False => ()
      _ => raise failed("repick must be true or false")
    }
  }
  Some(Json::object(out))
}

///|
fn Storage::infer_runtime(self : Storage, ws : String?, cur : String, model : String) -> String? raise Thrown {
  let available = self.st.hub.profiles_in(ws)
  let rts_of = (p : Json) =>
    match get(p, "runtimes") {
      Some(Array(xs)) => xs.filter_map(x => match x { String(s) => Some(s); _ => None })
      _ => []
    }
  let fits_cur = available.iter().any(p => rts_of(p).contains(cur) && @session_hub.runs(p, model))
  if fits_cur {
    None
  } else {
    let matched : Array[String] = []
    for p in available {
      if @session_hub.runs(p, model) {
        for r in rts_of(p) {
          if !matched.contains(r) {
            matched.push(r)
          }
        }
      }
    }
    if matched.length() == 1 {
      Some(matched[0])
    } else if matched.length() > 1 {
      raise failed("model \{model} runs on multiple runtimes (\{matched.join(", ")}): pass runtime")
    } else {
      None
    }
  }
}

///|
fn parse_peer_lead(raw : Json?, peer : String) -> LeadAction? raise Thrown {
  match raw {
    None | Some(Null) => None
    Some(Object(m)) =>
      match m.get("mode") {
        Some(String("person")) => Some(Person)
        Some(String("me")) => {
          let parent = match m.get("parent") {
            Some(String(s)) => js_trim(s)
            _ => ""
          }
          if parent == "" {
            raise failed("lead.parent is required")
          }
          if peer == "" {
            raise failed("caller station is required for cross-station lead")
          }
          let parent_title = match m.get("parentTitle") {
            Some(String(s)) if js_trim(s) != "" => Some(js_trim(s))
            _ => None
          }
          let ancestors : Array[(String, String)] = []
          match m.get("parentAncestors") {
            Some(Array(xs)) =>
              for item in xs {
                if ancestors.length() >= max_ancestor_hops {
                  break
                }
                if str(item, "station") is Some(st) && str(item, "session") is Some(sess) {
                  ancestors.push((st, sess))
                }
              }
            _ => ()
          }
          Some(Me(peer, parent, parent_title, ancestors))
        }
        _ => raise failed("for must be \"me\" or \"person\"")
      }
    _ => raise failed("lead must be an object")
  }
}

///|
async fn Storage::apply_configure_here(
  self : Storage,
  target_key : String,
  change : Json?,
  lead : LeadAction?,
  mirror_caller : String,
  skip_mirror_station? : String = "",
) -> Json {
  guard self.session(target_key) is Some(row) else {
    raise failed("unknown session \{target_key}")
  }
  let target_link = (self.st.hub.world.link)(target_key)
  if change is None && lead is None {
    return jo([
      ("text", js(self.describe_session(row).stringify(indent=2))),
      ("target", js(target_key)),
      ("title", jopt(cfg_trimmed(get(row, "title")))),
      ("link", jopt(target_link)),
      ("leadChanged", jb(false)),
    ])
  }
  if lead is Some(l) {
    self.validate_lead_here(target_key, l)
  }
  let before = self.describe_session(row)
  if change is Some(ch) {
    let next = match ch {
      Object(m) => {
        let copy = m.copy()
        if !copy.contains("runtime") {
          if copy.get("model") is Some(String(model)) && model != "" {
            let inferred = self.infer_runtime(str(row, "ws"), str(row, "runtime").unwrap_or(""), model)
            if inferred is Some(rt) && rt != "" {
              copy["runtime"] = js(rt)
            }
          }
        }
        Json::object(copy)
      }
      other => other
    }
    self.st.hub.configure(target_key, next, lang="en")
  }
  let mut lead_changed = false
  match lead {
    Some(Person) => {
      let res = self.st.store.set_opened_led(js(""), js(target_key), false)
      lead_changed = get(res, "changed") is Some(True)
      let prev = get(res, "prev").unwrap_or(Json::null())
      if lead_changed && !nullish(Some(prev)) {
        let prev_ps = str(prev, "parentStation").unwrap_or("")
        let prev_parent = str(prev, "parent").unwrap_or("")
        let from = if prev_ps == "" {
          self.chat_title_of(prev_parent)
        } else {
          str(prev, "openerTitle").unwrap_or(prev_parent)
        }
        self.say_lead_notice(target_key, "station.session.handedToPerson", from)
        if prev_ps != "" && prev_ps != skip_mirror_station {
          self.clear_remote_mirror(mirror_caller, prev_ps, target_key)
        }
      }
    }
    Some(Me(parent_station, parent, parent_title, _)) => {
      let stored_opener_title = if parent_station == "" { None } else { parent_title }
      let res = self.st.store.adopt_opened(jo([
        ("childStation", js("")),
        ("child", js(target_key)),
        ("parentStation", js(parent_station)),
        ("parent", js(parent)),
        ("title", Json::null()),
        ("link", jopt(target_link)),
        ("openerTitle", jopt(stored_opener_title)),
      ]))
      lead_changed = get(res, "changed") is Some(True)
      if lead_changed {
        let from = if parent_station == "" {
          self.chat_title_of(parent)
        } else {
          parent_title.unwrap_or(parent)
        }
        self.say_lead_notice(target_key, "station.session.adoptedByAgent", from)
        let prev = get(res, "prev").unwrap_or(Json::null())
        if !nullish(Some(prev)) {
          let prev_ps = str(prev, "parentStation").unwrap_or("")
          let prev_parent = str(prev, "parent").unwrap_or("")
          if prev_ps != "" && prev_ps != skip_mirror_station && (prev_ps != parent_station || prev_parent != parent) {
            self.clear_remote_mirror(mirror_caller, prev_ps, target_key)
          }
        }
      }
    }
    None => ()
  }
  let after_row = self.session(target_key).unwrap_or(row)
  let after = self.describe_session(after_row)
  let updated = change is Some(_) || lead_changed
  jo([
    ("text", js(jo([("updated", jb(updated)), ("before", before), ("after", after)]).stringify(indent=2))),
    ("target", js(target_key)),
    ("title", jopt(cfg_trimmed(get(after_row, "title")))),
    ("link", jopt(target_link)),
    ("leadChanged", jb(lead_changed)),
  ])
}

///|
pub async fn Storage::chat_configure(self : Storage, key : String, args : Json) -> String {
  let ws = self.scope_of(key)
  let chat = match get(args, "chat") {
    Some(String(s)) => js_trim(s)
    _ => ""
  }
  let for_mode = cfg_parse_for(args)
  let change = self.parse_configure_change(ws, args)
  let is_self = chat == "" || chat.to_lower() == "self"
  let mut station = if is_self { None } else { self.elsewhere(key, chat) }
  let mut target_chat = chat
  if !is_self && station is None {
    let ref_key = match linked_session(chat) {
      Some((k, _)) => k
      None => chat
    }
    let moved = self.st.store.handed_to(ref_key)
    if str(moved, "station") is Some(st) && st != "" {
      station = Some(st)
      target_chat = ref_key
    }
  }
  guard station is Some(st) else {
    let target_key = self.resolve_configure_here(target_chat, ws, Some(key))
    let lead : LeadAction? = match for_mode {
      Some("person") => Some(Person)
      Some("me") => Some(Me("", key, None, []))
      _ => None
    }
    let res = self.apply_configure_here(target_key, change, lead, key)
    return str(res, "text").unwrap_or("")
  }
  guard self.peers_of(key) is Some(call) else {
    raise failed("other stations cannot be reached from this one yet")
  }
  let req_fields : Array[(String, Json)] = [
    ("method", js(configure_method)),
    ("session", js(key)),
    ("chat", js(target_chat)),
  ]
  if change is Some(ch) {
    req_fields.push(("change", ch))
  }
  match for_mode {
    Some("person") => req_fields.push(("lead", jo([("mode", js("person"))])))
    Some("me") => {
      let ancestors = self.local_ancestors(key)
      let target_ref = match linked_session(target_chat) {
        Some((k, _)) => k
        None => target_chat
      }
      if ancestors.iter().any(a => a.0 == st && a.1 == target_ref) {
        raise failed("cannot lead a chat that already leads this one")
      }
      req_fields.push(("lead", jo([
        ("mode", js("me")),
        ("parent", js(key)),
        ("parentTitle", jopt(self.own_title(key))),
        ("parentAncestors", ja(ancestors.map(a => jo([("station", js(a.0)), ("session", js(a.1))])))),
      ])))
    }
    _ => ()
  }
  let answer = call(st, jo(req_fields)) catch {
    e => {
      let why = message_of(e)
      if is_kind(e, "Refused") && from_before(why) {
        raise failed("station \{st} is not updated yet: its chats cannot be configured from here")
      }
      raise failed("configure request to station \{st} failed: \{why}")
    }
  }
  guard str(answer, "text") is Some(text) else {
    raise failed("station \{st} answered without a configure result")
  }
  match for_mode {
    Some(mode) => {
      let target = match str(answer, "target") {
        Some(t) => js_trim(t)
        None => ""
      }
      if target == "" {
        raise failed("station \{st} is not updated yet: ownership cannot be changed there")
      }
      if mode == "person" {
        ignore(self.st.store.set_opened_led(js(st), js(target), false))
      } else {
        ignore(self.st.store.adopt_opened(jo([
          ("childStation", js(st)),
          ("child", js(target)),
          ("parentStation", js("")),
          ("parent", js(key)),
          ("title", jopt(cfg_trimmed(get(answer, "title")))),
          ("link", jopt(cfg_trimmed(get(answer, "link")))),
          ("openerTitle", Json::null()),
        ])))
      }
    }
    None => ()
  }
  text
}

///|
pub async fn Storage::configure_for_peer(self : Storage, request : Json, ws : String?, peer? : String = "") -> Json {
  match get(request, "leadMirror") {
    Some(Object(m)) => {
      if ws is Some(_) && peer == "" {
        raise failed("caller station is required for cross-station lead")
      }
      let child = match m.get("child") {
        Some(String(s)) => js_trim(s)
        _ => ""
      }
      let child_station = if peer != "" {
        peer
      } else if ws is None {
        match m.get("childStation") {
          Some(String(s)) => js_trim(s)
          _ => ""
        }
      } else {
        ""
      }
      if child != "" && child_station != "" {
        let record = self.st.store.opened_record(js(child_station), js(child))
        if !nullish(Some(record)) {
          if ws is Some(w) {
            let ps = str(record, "parentStation").unwrap_or("")
            let parent = str(record, "parent").unwrap_or("")
            if ps != "" || !self.in_workspace(parent, w) {
              raise failed("that chat is in another workspace: only this workspace's chats can be configured")
            }
          }
          ignore(self.st.store.set_opened_led(js(child_station), js(child), false))
        }
      }
      return jo([("text", js(jo([("updated", jb(true))]).stringify()))])
    }
    _ => ()
  }
  let chat = match get(request, "chat") {
    Some(String(s)) => js_trim(s)
    _ => ""
  }
  if chat == "" {
    raise failed("chat is required")
  }
  let target_key = self.resolve_configure_here(chat, ws, None)
  let change = match get(request, "change") {
    None | Some(Null) => None
    Some(Object(m)) if m.is_empty() => None
    Some(Object(_) as ch) => Some(ch)
    _ => raise failed("change must be an object")
  }
  let lead = parse_peer_lead(get(request, "lead"), peer)
  self.apply_configure_here(target_key, change, lead, target_key, skip_mirror_station=peer)
}
