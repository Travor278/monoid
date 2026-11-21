// A session's row and what is kept beside it (store.ts `// ── sessions ──`): read, made, set, counted.

///|
pub fn Store::get_session(self : Store, key : String) -> Json raise {
  match self.one("SELECT * FROM sessions WHERE key = ?", [jstr(key)]) {
    Some(r) => to_session(r)
    None => Json::null()
  }
}

///|
/// The sessions of `keys` that there are, read in one statement.
pub fn Store::sessions_of(
  self : Store,
  keys : Array[String],
) -> Array[Json] raise {
  if keys.length() == 0 {
    return []
  }
  self
  .all("SELECT * FROM sessions WHERE key IN (SELECT value FROM json_each(?))", [
    jstr(js(strings(keys))),
  ])
  .map(to_session)
}

///|
/// A session's workspace (null: the home one's), undefined where there is no such session: kept in memory once read,
/// outside a transaction.
pub fn Store::session_ws(self : Store, key : String) -> Json raise {
  if self.ws_of.get(key) is Some(ws) {
    return ws
  }
  match self.one("SELECT ws FROM sessions WHERE key = ?", [jstr(key)]) {
    None => undefined()
    Some(r) => {
      let ws = col(r, "ws")
      if !self.in_tx() {
        self.ws_of[key] = ws
      }
      ws
    }
  }
}

///|
/// The session a tool call's bearer token names: kept in memory once read.
pub fn Store::session_key_by_token(self : Store, token : String) -> Json raise {
  if self.token_key.get(token) is Some(kept) {
    return jstr(kept)
  }
  match self.one("SELECT key FROM sessions WHERE token = ?", [jstr(token)]) {
    None => Json::null()
    Some(r) => {
      if !self.in_tx() && col(r, "key") is String(k) {
        self.token_key[token] = k
      }
      col(r, "key")
    }
  }
}

///|
/// store.ts ARCHIVED_WORKSPACE_BATCH.
let archived_workspace_batch : Int32 = 64

///|
/// A page of archived workspaces, longest archived first (`after`, `through`: null, a time or a row
/// `{key, archivedAt}`).
pub fn Store::archived_sessions(
  self : Store,
  after : Json,
  through : Json,
) -> Json raise {
  let mut sql = "SELECT key, archived_at FROM sessions INDEXED BY sessions_put_away WHERE archived_at IS NOT NULL"
  let args = []
  match through {
    Number(_, ..) => {
      sql = sql + " AND archived_at <= ?"
      args.push(through)
    }
    Null => ()
    t => {
      sql = sql + " AND (archived_at, key) <= (?, ?)"
      args.push(nullish(field(t, "archivedAt")))
      args.push(nullish(field(t, "key")))
    }
  }
  if !(after is Null) {
    sql = sql + " AND (archived_at, key) > (?, ?)"
    args.push(nullish(field(after, "archivedAt")))
    args.push(nullish(field(after, "key")))
  }
  Json::array(
    self
    .all(
      "\{sql} ORDER BY archived_at, key LIMIT \{archived_workspace_batch}",
      args,
    )
    .map(r => { "key": col(r, "key"), "archivedAt": col(r, "archived_at") }),
  )
}

///|
pub fn Store::last_archived_session(self : Store) -> Json raise {
  match
    self.one(
      "SELECT key, archived_at FROM sessions INDEXED BY sessions_put_away WHERE archived_at IS NOT NULL ORDER BY archived_at DESC, key DESC LIMIT 1",
      [],
    ) {
    Some(r) => { "key": col(r, "key"), "archivedAt": col(r, "archived_at") }
    None => Json::null()
  }
}

///|
pub fn Store::next_archived_at(self : Store, after : Json) -> Json raise {
  match
    self.one(
      "SELECT archived_at FROM sessions INDEXED BY sessions_put_away WHERE archived_at > ? ORDER BY archived_at, key LIMIT 1",
      [after],
    ) {
    Some(r) => col(r, "archived_at")
    None => Json::null()
  }
}

///|
/// Bounded page of idle unarchived, non-running sessions with `last_active_at <= through`, oldest activity first,
/// using the `sessions_live` partial index.
pub fn Store::idle_unarchived_sessions(
  self : Store,
  after : Json,
  through : Json,
  limit : Int,
) -> Array[Json] raise {
  let sql = StringBuilder::new()
  sql.write_string(
    "SELECT key, workspace, last_active_at FROM sessions INDEXED BY sessions_live WHERE archived_at IS NULL AND running = 0 AND last_active_at <= ?",
  )
  let args : Array[Json] = [through]
  if !(after is Null) {
    sql.write_string(" AND last_active_at >= ? AND (last_active_at > ? OR key > ?)")
    let at = field(after, "lastActiveAt").unwrap_or(Json::null())
    let k = field(after, "key").unwrap_or(Json::null())
    args.push(at)
    args.push(at)
    args.push(k)
  }
  sql.write_string(" ORDER BY last_active_at ASC, key ASC LIMIT ?")
  args.push(jint(limit.to_int64()))
  self
  .all(sql.to_string(), args)
  .map(r => { "key": col(r, "key"), "workspace": col(r, "workspace"), "lastActiveAt": col(r, "last_active_at") })
}

///|
pub fn Store::list_sessions(self : Store) -> Array[Json] raise {
  self
  .all("SELECT * FROM sessions ORDER BY last_active_at DESC", [])
  .map(to_session)
}

///|
pub fn Store::live_sessions(self : Store) -> Array[Json] raise {
  self.all(live_sessions, []).map(to_session)
}

///|
/// recover-waits.ts `recoverWaitsReady`.
fn Store::recover_waits_ready(self : Store) -> Bool raise {
  match
    self.one("SELECT complete FROM session_recover_wait_meta WHERE id = 1", []) {
    Some(r) => is_n(col(r, "complete"), 1.0)
    None =>
      raise store_error(
        "Cannot read properties of undefined (reading 'complete')",
      )
  }
}

///|
/// awake-waits.ts `awakeWaitsReady`.
fn Store::awake_waits_ready(self : Store) -> Bool raise {
  match
    self.one("SELECT complete FROM session_awake_wait_meta WHERE id = 1", []) {
    Some(r) => is_n(col(r, "complete"), 1.0)
    None =>
      raise store_error(
        "Cannot read properties of undefined (reading 'complete')",
      )
  }
}

///|
/// Waits needing recovery, or null while an older store is still being prepared.
pub fn Store::recovery_waits(self : Store) -> Json raise {
  if !self.recover_waits_ready() {
    return Json::null()
  }
  Json::array(
    self
    .all(recover_waits, [])
    .map(r => {
      let refill = col(r, "recovery_outcome") is String("failed") &&
        col(r, "recovery_detail") is String(d) &&
        d.has_prefix("rate_limit:")
      { "row": to_session(r), "refill": jbool(refill) }
    }),
  )
}

///|
/// Number.isSafeInteger.
fn safe_integer(n : Double) -> Bool {
  n == n.floor() && n.abs() <= 9007199254740991.0
}

///|
/// awake-waits.ts HALF_SAFE.
let half_safe : Double = 2251799813685247.0

///|
/// Whether a live recorded wait is still within its awake interval; null while an older lookup is being prepared.
pub fn Store::awake_wait(
  self : Store,
  now : Double,
  linger : Double,
) -> Json raise {
  if !self.recover_waits_ready() {
    return Json::null()
  }
  if self.awake_waits_ready() &&
    safe_integer(now) &&
    safe_integer(linger) &&
    now.abs() <= half_safe &&
    linger.abs() <= half_safe {
    let state = self.one(awake_wait_status, [jnum(now - linger)]).unwrap()
    if is_n(col(state, "uncertain"), 0.0) {
      return jbool(is_n(col(state, "awake"), 1.0))
    }
  }
  for r in self.all(recover_awake_waits, []) {
    let ended = num_of(col(r, "ended_at")).unwrap_or(0.0)
    let wait = num_of(col(r, "wait_seconds")).unwrap_or(0.0)
    if now < ended + wait * 1000.0 + linger {
      return jbool(true)
    }
  }
  jbool(false)
}

///|
pub fn Store::running_sessions(self : Store) -> Array[Json] raise {
  self.all(running_sessions, []).map(to_session)
}

///|
/// The sessions in use: shown, or running a turn (one archived while at work too).
pub fn Store::sessions_in_use(self : Store) -> Array[Json] raise {
  let live = self.live_sessions()
  let keys : Map[String, Unit] = Map([])
  for s in live {
    if field(s, "key") is Some(String(k)) {
      keys[k] = ()
    }
  }
  let out = live.copy()
  for s in self.running_sessions() {
    if !(field(s, "key") is Some(String(k)) && keys.contains(k)) {
      out.push(s)
    }
  }
  out
}

///|
/// What `sessions_in_use` gives of a session for its directories: its key, workspace (`""` for none) and cwd (its
/// workspace for none), as `to_session`'s `key`, `workspace` and `cwd` read as strings.
fn place_of_session(r : Map[String, Json]) -> (String, String, String) {
  let ws = str_of(col(r, "workspace")).unwrap_or("")
  (str_of(col(r, "key")).unwrap_or(""), ws, str_of(col(r, "cwd")).unwrap_or(ws))
}

///|
/// The sessions of `sessions_in_use`, each its key, workspace and cwd only (no row made whole): what cold storage asks
/// of each session of an upkeep round.
pub fn Store::in_use_places(self : Store) -> Array[(String, String, String)] raise {
  self.all(in_use_places, []).map(place_of_session)
}

///|
/// session-counts.ts `sessionCountsReady`.
fn Store::session_counts_ready(self : Store) -> Bool raise {
  match
    self.one("SELECT version, complete FROM session_count_meta WHERE id = 1", []) {
    None => raise store_error("session count index version marker is missing")
    Some(meta) => {
      if !is_n(col(meta, "version"), 1.0) {
        raise store_error(
          "session count index version \{js_string(col(meta, "version"))} is incompatible with 1",
        )
      }
      is_n(col(meta, "complete"), 1.0)
    }
  }
}

///|
/// How many sessions each connect has, including archived ones (`viewer`: `{workspace, home?}`, or null for the
/// whole station).
pub fn Store::session_counts(self : Store, viewer : Json) -> Json raise {
  self.savepoint("session_counts", () => {
    if !self.session_counts_ready() {
      raise store_error("session counts are not ready")
    }
    let rows = match viewer {
      Null => self.all(session_counts, [])
      v =>
        self.all(
          if field(v, "home") is Some(False) {
            session_counts_visible
          } else {
            session_counts_home
          },
          [nullish(field(v, "workspace"))],
        )
    }
    Json::array(
      rows.map(r => {
        "connect": col(r, "connect"),
        "ws": col(r, "ws"),
        "n": col(r, "n"),
      }),
    )
  })
}

///|
/// Only the totals an overview will show; null while the counts are prepared.
pub fn Store::overview_session_counts(
  self : Store,
  viewer : Json,
  connects : Array[Json],
) -> Json raise {
  self.savepoint("overview_session_counts", () => {
    if !self.session_counts_ready() {
      return Json::null()
    }
    let scopes : Array[(Json, Json)] = [
      (jnum(1.0), nullish(field(viewer, "workspace"))),
    ]
    if !(field(viewer, "home") is Some(False)) {
      scopes.push((jnum(0.0), jstr("")))
    }
    let count = (sql : String, extra : Array[Json]) => {
      let mut n = 0.0
      for s in scopes {
        let found = self.one(sql, [s.0, s.1] + extra)
        n = n +
          (match found {
            Some(r) => num_of(col(r, "n")).unwrap_or(0.0)
            None => 0.0
          })
      }
      n
    }
    let total = count(session_count_total, [])
    let by : Array[(String, Json)] = []
    let seen : Map[String, Unit] = Map([])
    for c in connects {
      guard c is String(connect) else { continue }
      if seen.contains(connect) {
        continue
      }
      seen[connect] = ()
      by.push((connect, jnum(count(session_count_connect, [c]))))
    }
    { "total": jnum(total), "byConnect": entries(by) }
  })
}

///|
pub fn Store::any_running(self : Store) -> Bool raise {
  self.one(any_running, []) is Some(_)
}

///|
/// usage-15m.ts `moveUsage15m`.
fn Store::move_usage_15m(
  self : Store,
  from : String,
  to : String,
) -> Unit raise {
  if from == to || !self.table("usage_15m_meta") {
    return
  }
  ignore(
    self.run("UPDATE usage_15m SET scope = ? WHERE scope = ?", [
      jstr(to),
      jstr(from),
    ]),
  )
}

///|
/// Says the sessions of workspace `from` (null: those that say none) are `to`'s (null: the home one's).
pub fn Store::set_sessions_ws(
  self : Store,
  from : Json,
  to : Json,
) -> Unit raise {
  self.with_changes(changes => {
    let keys = (match from {
      Null => self.all("SELECT key FROM sessions WHERE ws IS NULL", [])
      f => self.all("SELECT key FROM sessions WHERE ws = ?", [f])
    }).map(r => col(r, "key"))
    match from {
      Null =>
        ignore(self.run("UPDATE sessions SET ws = ? WHERE ws IS NULL", [to]))
      f => ignore(self.run("UPDATE sessions SET ws = ? WHERE ws = ?", [to, f]))
    }
    self.ws_of.clear()
    self.move_usage_15m(str_of(from).unwrap_or(""), str_of(to).unwrap_or(""))
    for key in keys {
      changes.push(session_change(key))
    }
    if keys.length() > 0 && from != to {
      self.session_workspace_changed()
    }
  })
}

///|
/// The profiles a session is kept to: `profiles` as given (undefined: by `pinned`), none for an empty list.
fn profile_list(profiles : Json?, pinned : Bool, profile : Json) -> Json {
  match profiles {
    Some(p) =>
      match p {
        Array(items) if items.length() > 0 => p
        _ => Json::null()
      }
    None => if pinned { Json::array([profile]) } else { Json::null() }
  }
}

///|
/// A list as kept (`JSON.stringify`), null for none.
fn list_text(list : Json) -> Json {
  match list {
    Null => Json::null()
    l => jstr(js(l))
  }
}

///|
/// Records a new session (rows.ts NewSession, as JSON).
pub fn Store::insert_session(self : Store, s : Json) -> Unit raise {
  let get = (k : String) => field(s, k)
  let profile = nullish(get("profile"))
  let profile_pinned = get("profilePinned")
  let list = match get("profiles") {
    Some(p) =>
      profile_list(
        Some(if truthy(p) { p } else { Json::null() }),
        false,
        profile,
      )
    None => profile_list(None, truthy(nullish(profile_pinned)), profile)
  }
  let pinned = match list {
    Array(items) => items.length() == 1
    _ =>
      match profile_pinned {
        None | Some(Null) => false
        Some(p) => truthy(p)
      }
  }
  self.with_changes(changes => {
    ignore(
      self.run(
        (
          #|INSERT INTO sessions (key, connect, scope, title, created_by, runtime, profile, profile_pinned, profiles, model, effort, workspace, cwd, runtime_session_id, token, created_at, last_active_at, told_notes, fast, ws, context, speed, tui)
          #|         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ),
        [
          nullish(get("key")),
          match nullish(get("connect")) {
            String("ember" | "stillfail") => Json::string(internal_connect)
            v => v
          },
          or_else(nullish(get("scope")), jstr("thread")),
          nullish(get("title")),
          nullish(get("createdBy")),
          nullish(get("runtime")),
          profile,
          flag(pinned),
          list_text(list),
          nullish(get("model")),
          nullish(get("effort")),
          nullish(get("workspace")),
          nullish(get("cwd")),
          nullish(get("runtimeSessionId")),
          nullish(get("token")),
          nullish(get("createdAt")),
          nullish(get("lastActiveAt")),
          jint(self.latest_note),
          opt_flag(get("fast")),
          nullish(get("ws")),
          nullish(get("context")),
          nullish(get("speed")),
          flag(get("tui") == Some(Json::boolean(true))),
        ],
      ),
    )
    changes.push(session_change(nullish(get("key"))))
    self.session_workspace_changed()
  })
}

///|
/// Moves a session to another profile; `pinned` keeps it to one, `profiles` (undefined: by `pinned`) to a set.
pub fn Store::set_session_profile(
  self : Store,
  key : String,
  profile : Json,
  pinned : Bool,
  profiles : Json?,
) -> Unit raise {
  let list = match profiles {
    Some(p) =>
      profile_list(
        Some(if truthy(p) { p } else { Json::null() }),
        pinned,
        profile,
      )
    None => profile_list(None, pinned, profile)
  }
  self.update_session(
    key,
    "UPDATE sessions SET profile = ?1, profile_pinned = ?2, profiles = ?3 WHERE key = ?4",
    [profile, flag(pinned), list_text(list), jstr(key)],
  )
}

///|
/// A runtime change is one setting: readers never see a runtime paired with another's profile or model.
pub fn Store::set_session_runtime(
  self : Store,
  key : String,
  runtime : Json,
  profile : Json,
  pinned : Bool,
  model : Json,
  effort : Json,
  fast : Json?,
  context : Json,
  profiles : Json?,
) -> Unit raise {
  let list = match profiles {
    Some(p) =>
      profile_list(
        Some(if truthy(p) { p } else { Json::null() }),
        pinned,
        profile,
      )
    None => profile_list(None, pinned, profile)
  }
  let first = if self.one(
      "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = 'runtime_sessions_ordered'",
      [],
    )
    is Some(_) {
    "(SELECT runtime FROM runtime_sessions INDEXED BY runtime_sessions_ordered WHERE session_key = ?9 ORDER BY at, rowid LIMIT 1), "
  } else {
    ""
  }
  self.update_session(
    key,
    "UPDATE sessions SET original_runtime = COALESCE(original_runtime, \{first}runtime), runtime = ?1, profile = ?2, profile_pinned = ?3, profiles = ?4, model = ?5, effort = ?6, fast = ?7, speed = NULL, tui = NULL, context = ?8 WHERE key = ?9",
    [
      runtime,
      profile,
      flag(pinned),
      list_text(list),
      model,
      effort,
      opt_flag(fast),
      context,
      jstr(key),
    ],
  )
}

///|
pub fn Store::set_session_model(
  self : Store,
  key : String,
  model : Json,
  effort : Json,
) -> Unit raise {
  self.update_session(
    key,
    "UPDATE sessions SET model = ?1, effort = ?2 WHERE key = ?3",
    [model, effort, jstr(key)],
  )
}

///|
pub fn Store::set_session_fast(
  self : Store,
  key : String,
  fast : Json?,
) -> Unit raise {
  self.update_session(
    key,
    "UPDATE sessions SET fast = ?1, speed = NULL WHERE key = ?2",
    [opt_flag(fast), jstr(key)],
  )
}

///|
pub fn Store::set_session_context(
  self : Store,
  key : String,
  context : Json,
) -> Unit raise {
  self.update_session(key, "UPDATE sessions SET context = ?1 WHERE key = ?2", [
    context,
    jstr(key),
  ])
}

///|
pub fn Store::set_session_context_before(
  self : Store,
  key : String,
  before : Json,
) -> Unit raise {
  self.update_session(
    key,
    "UPDATE sessions SET context_before = ?1 WHERE key = ?2",
    [before, jstr(key)],
  )
}

///|
/// store.ts `noteCompacted`: its runtime session compacted its context once more.
pub fn Store::note_compacted(self : Store, key : String) -> Unit raise {
  self.update_session(
    key,
    "UPDATE sessions SET compactions = COALESCE(compactions, 0) + 1 WHERE key = ?1",
    [jstr(key)],
  )
}

///|
pub fn Store::set_session_afresh(
  self : Store,
  key : String,
  afresh : Json?,
) -> Unit raise {
  self.update_session(key, "UPDATE sessions SET afresh = ?1 WHERE key = ?2", [
    opt_flag(afresh),
    jstr(key),
  ])
}

///|
pub fn Store::set_session_tui(self : Store, key : String, tui : Bool) -> Unit raise {
  self.update_session(key, "UPDATE sessions SET tui = ?1 WHERE key = ?2", [flag(tui), jstr(key)])
}

///|
pub fn Store::set_session_speed(
  self : Store,
  key : String,
  speed : Json,
) -> Unit raise {
  self.update_session(
    key,
    "UPDATE sessions SET speed = ?1, fast = CASE WHEN ?1 IS NULL THEN NULL WHEN ?1 = 'standard' THEN 0 ELSE 1 END WHERE key = ?2",
    [speed, jstr(key)],
  )
}

///|
/// model-speed.ts `modelSpeed`.
fn model_speed(v : Json) -> Json {
  match v {
    String("standard") | String("fast") | String("ultrafast") => v
    _ => Json::null()
  }
}

///|
pub fn Store::codex_session_speed(self : Store, thread : String) -> Json raise {
  match
    self.one(
      "SELECT speed FROM sessions WHERE runtime = 'codex' AND runtime_session_id = ?",
      [jstr(thread)],
    ) {
    Some(r) => model_speed(col(r, "speed"))
    None => Json::null()
  }
}

///|
pub fn Store::codex_session_fast(self : Store, thread : String) -> Json raise {
  match
    self.one(
      "SELECT fast FROM sessions WHERE runtime = 'codex' AND runtime_session_id = ?",
      [jstr(thread)],
    ) {
    None => Json::null()
    Some(r) =>
      match col(r, "fast") {
        Null => Json::null()
        f => jbool(!is_n(f, 0.0))
      }
  }
}

///|
pub fn Store::set_title(self : Store, key : String, title : Json) -> Unit raise {
  self.update_session(key, "UPDATE sessions SET title = ?1 WHERE key = ?2", [
    title,
    jstr(key),
  ])
}

///|
pub fn Store::set_runtime_session_id(
  self : Store,
  key : String,
  id : Json,
) -> Unit raise {
  self.with_changes(changes => {
    ignore(
      self.run("UPDATE sessions SET compactions = CASE WHEN runtime_session_id IS ?1 THEN compactions ELSE NULL END, runtime_session_id = ?1 WHERE key = ?2", [
        id,
        jstr(key),
      ]),
    )
    changes.push(session_change(jstr(key)))
    changes.push({ "type": "conversation", "key": jstr(key) })
  })
}

///|
pub fn Store::conversation_since(self : Store, key : String) -> Json raise {
  match
    self.one(
      "SELECT s.runtime_session_id AS id, r.at AS at FROM sessions s LEFT JOIN runtime_sessions r ON r.session_key = s.key AND r.id = s.runtime_session_id WHERE s.key = ?",
      [jstr(key)],
    ) {
    None => Json::null()
    Some(r) =>
      if col(r, "id") is Null {
        Json::null()
      } else {
        or_else(col(r, "at"), jnum(0.0))
      }
  }
}

///|
pub fn Store::set_transcript_lengths(
  self : Store,
  lengths : Array[(String, Json)],
) -> Unit raise {
  if lengths.length() == 0 {
    return
  }
  self.tx(() => {
    for l in lengths {
      ignore(
        self.run(
          "INSERT INTO transcript_lengths (session, n) VALUES (?1, ?2) ON CONFLICT (session) DO UPDATE SET n = excluded.n",
          [jstr(l.0), l.1],
        ),
      )
    }
  })
}

///|
pub fn Store::set_session_usage(
  self : Store,
  key : String,
  usage : Json,
  quiet : Bool,
) -> Unit raise {
  let text = js(usage)
  if self.one("SELECT usage FROM session_usage WHERE session = ?", [jstr(key)])
    is Some(r) &&
    col(r, "usage") is String(u) &&
    u == text {
    return
  }
  let session = self.get_session(key)
  if session is Null {
    return
  }
  self.with_changes(changes => {
    ignore(
      self.run(
        "INSERT INTO session_usage (session, usage) VALUES (?1, ?2) ON CONFLICT (session) DO UPDATE SET usage = excluded.usage",
        [jstr(key), jstr(text)],
      ),
    )
    if !quiet && !(field(session, "running") is Some(True)) {
      changes.push(session_change(jstr(key)))
    }
  })
}

///|
pub fn Store::device_builds(self : Store) -> Array[Json] raise {
  self
  .all("SELECT id, build, at FROM device_builds", [])
  .map(r => {
    "id": jstr(js_string(col(r, "id"))),
    "build": js_number(col(r, "build")),
    "at": js_number(col(r, "at")),
  })
}

///|
/// `Number(v)` of a column.
fn js_number(v : Json) -> Json {
  match v {
    Number(_, ..) => v
    Null => jnum(0.0)
    True => jnum(1.0)
    False => jnum(0.0)
    String(s) => {
      let t = s.trim().to_string()
      if t == "" {
        jnum(0.0)
      } else {
        match (Some(@json.parse(t)) catch { _ => None }) {
          Some(Number(_, ..) as n) => n
          _ => Json::null()
        }
      }
    }
    _ => Json::null()
  }
}

///|
pub fn Store::put_device_build(
  self : Store,
  id : Json,
  build : Json,
  at : Json,
) -> Unit raise {
  ignore(
    self.run(
      "INSERT INTO device_builds (id, build, at) VALUES (?1, ?2, ?3) ON CONFLICT (id) DO UPDATE SET build = excluded.build, at = excluded.at",
      [id, build, at],
    ),
  )
}

///|
pub fn Store::model_stars(self : Store, ws : Json, sub : Json) -> Json raise {
  match
    self.one("SELECT stars FROM model_stars WHERE ws = ?1 AND sub = ?2", [
      ws, sub,
    ]) {
    None => Json::null()
    Some(r) => jstr(js_string(col(r, "stars")))
  }
}

///|
pub fn Store::put_model_stars(
  self : Store,
  ws : Json,
  sub : Json,
  stars : Json,
) -> Unit raise {
  ignore(
    self.run(
      "INSERT INTO model_stars (ws, sub, stars) VALUES (?1, ?2, ?3) ON CONFLICT (ws, sub) DO UPDATE SET stars = excluded.stars",
      [ws, sub, stars],
    ),
  )
}

///|
pub fn Store::board_drafts(self : Store, ws : Json, sub : Json) -> Json raise {
  match
    self.one("SELECT drafts FROM board_drafts WHERE ws = ?1 AND sub = ?2", [
      ws, sub,
    ]) {
    None => Json::null()
    Some(r) => jstr(js_string(col(r, "drafts")))
  }
}

///|
pub fn Store::put_board_drafts(
  self : Store,
  ws : Json,
  sub : Json,
  drafts : Json,
) -> Unit raise {
  ignore(
    self.run(
      "INSERT INTO board_drafts (ws, sub, drafts) VALUES (?1, ?2, ?3) ON CONFLICT (ws, sub) DO UPDATE SET drafts = excluded.drafts",
      [ws, sub, drafts],
    ),
  )
}

///|
/// Since when this station keeps the devices' builds: `now` the first time it is asked, the same ever after. Read
/// without the write lock where it is kept; the first write waits for no other writer (store.ts `#tryNow`: the mesh
/// tries again after a failed start), refused "device builds write is busy" where one holds the lock.
pub fn Store::device_builds_since(self : Store, now : Json) -> Json raise {
  match self.one("SELECT at FROM device_builds_since WHERE one = 1", []) {
    Some(r) => return js_number(or_else(col(r, "at"), now))
    None => ()
  }
  let timeout = match self.one("PRAGMA busy_timeout", []) {
    Some(r) => num_of(col(r, "timeout")).unwrap_or(0.0).to_int()
    None => 0
  }
  self.db.exec("PRAGMA busy_timeout=0")
  let made : Result[Json, Error] = try {
    ignore(self.run("INSERT OR IGNORE INTO device_builds_since (one, at) VALUES (1, ?1)", [now]))
    match self.one("SELECT at FROM device_builds_since WHERE one = 1", []) {
      Some(r) => Ok(js_number(or_else(col(r, "at"), now)))
      None => Ok(js_number(now))
    }
  } catch {
    e => Err(e)
  }
  self.db.exec("PRAGMA busy_timeout=\{timeout}")
  match made {
    Ok(at) => at
    Err(e) if @sql.busy(e) => raise store_error("device builds write is busy")
    Err(e) => raise e
  }
}

///|
/// usage-totals-source.ts `usageTotalsComplete`.
fn Store::usage_totals_complete(self : Store, session : String) -> Bool raise {
  let incremental = match self.incremental {
    Some(known) => known
    None => {
      let known = self.table("usage_totals_incremental")
      self.incremental = Some(known)
      known
    }
  }
  if !incremental {
    return true
  }
  match
    self.one(
      "SELECT done FROM usage_totals_source_sessions WHERE session = ?",
      [jstr(session)],
    ) {
    Some(r) => is_n(col(r, "done"), 1.0)
    None => false
  }
}

///|
pub fn Store::session_usage(self : Store, key : String) -> Json raise {
  if !self.usage_totals_complete(key) {
    return Json::null()
  }
  match
    self.one("SELECT usage FROM session_usage WHERE session = ?", [jstr(key)]) {
    None => Json::null()
    Some(r) => js_parse(js_string(col(r, "usage")))
  }
}

///|
/// Keys of sessions whose kept usage summary still has calls of an unpriced model, so a catalog update can price them.
pub fn Store::unpriced_usage_sessions(self : Store) -> Array[String] raise {
  self
  .all("SELECT session FROM session_usage WHERE json_extract(usage, '$.unpricedCalls') > 0", [])
  .map(r => js_string(col(r, "session")))
}

///|
pub fn Store::ran_in(
  self : Store,
  key : String,
  id : Json,
  profile : Json,
) -> Unit raise {
  ignore(
    self.run(
      (
        #|INSERT INTO runtime_sessions (session_key, id, profile, at, runtime) VALUES (?1, ?2, ?3, ?4, (SELECT runtime FROM sessions WHERE key = ?1))
        #|       ON CONFLICT (session_key, id) DO UPDATE SET profile = COALESCE(excluded.profile, profile)
      ),
      [jstr(key), id, profile, self.now_json()],
    ),
  )
}

///|
/// Session `key`'s accounts said anew by `map` (by the id it had, to the id it has). Whether its own changed.
pub fn Store::follow_profiles(
  self : Store,
  key : String,
  map : Map[String, String],
) -> Bool raise {
  let row = self.get_session(key)
  if row is Null {
    return false
  }
  for
    r in self.all(
      "SELECT id, profile FROM runtime_sessions WHERE session_key = ?",
      [jstr(key)],
    ) {
    if col(r, "profile") is String(p) && map.get(p) is Some(to) {
      ignore(
        self.run(
          "UPDATE runtime_sessions SET profile = ? WHERE session_key = ? AND id = ?",
          [jstr(to), jstr(key), col(r, "id")],
        ),
      )
    }
  }
  let own = nullish(field(row, "profile"))
  let to = match own {
    String(p) => map.get(p)
    _ => None
  }
  let kept = nullish(field(row, "profiles"))
  let list = match kept {
    Array(items) =>
      Json::array(
        items.map(p => {
          match p {
            String(s) =>
              match map.get(s) {
                Some(t) => jstr(t)
                None => p
              }
            _ => p
          }
        }),
      )
    _ => Json::null()
  }
  if to is None && (kept is Null || list == kept) {
    return false
  }
  self.set_session_profile(
    key,
    match to {
      Some(t) => jstr(t)
      None => own
    },
    field(row, "profilePinned") is Some(True),
    Some(list),
  )
  to is Some(_)
}

///|
pub fn Store::ran_on(self : Store, key : String, id : Json) -> Json raise {
  match
    self.one(
      "SELECT profile FROM runtime_sessions WHERE session_key = ? AND id = ?",
      [jstr(key), id],
    ) {
    Some(r) => col(r, "profile")
    None => Json::null()
  }
}

// ── chats agents opened (opened_chats) ──

///|
/// Records a chat opened for a session (rows.ts Opened, without its state and time).
pub fn Store::insert_opened(self : Store, o : Json) -> Unit raise {
  let get = (k : String) => nullish(field(o, k))
  self.with_changes(changes => {
    let at = self.now_json()
    ignore(
      self.run(
        "INSERT INTO opened_chats (child_station, child, parent_station, parent, key, title, link, opener_title, led, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          get("childStation"),
          get("child"),
          get("parentStation"),
          get("parent"),
          get("key"),
          get("title"),
          get("link"),
          get("openerTitle"),
          match get("led") {
            Null => Json::null()
            l => flag(truthy(l))
          },
          at,
        ],
      ),
    )
    if get("parentStation") is String("") {
      let opened = {
        "childStation": get("childStation"),
        "child": get("child"),
        "parent": get("parent"),
        "title": get("title"),
        "openerTitle": get("openerTitle"),
        "createdAt": at,
      }
      changes.push({
        "type": "chatMark",
        "thread": Json::null(),
        "session": get("parent"),
        "opened": opened,
      })
    }
  })
}

///|
pub fn Store::opened_with(
  self : Store,
  parent_station : Json,
  parent : Json,
  key : Json,
  child_station : Json,
) -> Json raise {
  match
    self.one(
      "SELECT * FROM opened_chats WHERE parent_station = ? AND parent = ? AND key = ? AND child_station = ?",
      [parent_station, parent, key, child_station],
    ) {
    Some(r) => to_opened(r)
    None => Json::null()
  }
}

///|
pub fn Store::efforts_used_by(
  self : Store,
  created_by : Json,
  runtime : Json,
  model : Json,
  since : Json,
) -> Array[Json] raise {
  self
  .all(
    if self.efforts_index {
      efforts_used_by
    } else {
      efforts_used_by_before_index
    },
    [created_by, runtime, model, since],
  )
  .map(r => { "effort": col(r, "effort"), "n": js_number(col(r, "n")) })
}

///|
pub fn Store::opener_of(self : Store, child : Json) -> Json raise {
  match
    self.one(
      "SELECT * FROM opened_chats WHERE child_station = '' AND child = ?",
      [child],
    ) {
    Some(r) => to_opened(r)
    None => Json::null()
  }
}

///|
pub fn Store::opened_record(
  self : Store,
  child_station : Json,
  child : Json,
) -> Json raise {
  match
    self.one(
      "SELECT * FROM opened_chats WHERE child_station = ? AND child = ?",
      [child_station, child],
    ) {
    Some(r) => to_opened(r)
    None => Json::null()
  }
}

///|
pub fn Store::models_used_by(
  self : Store,
  created_by : Json,
  since : Json,
) -> Array[Json] raise {
  self
  .all(models_used_by, [created_by, since])
  .map(r => {
    "runtime": col(r, "runtime"),
    "model": if col(r, "model") is String(_) {
      col(r, "model")
    } else {
      Json::null()
    },
    "n": js_number(col(r, "n")),
  })
}

///|
pub fn Store::opened_by(self : Store, parent : Json) -> Array[Json] raise {
  self
  .all(
    "SELECT * FROM opened_chats WHERE parent_station = '' AND parent = ? ORDER BY created_at, rowid",
    [parent],
  )
  .map(to_opened)
}

///|
pub fn Store::set_opened_state(
  self : Store,
  child_station : Json,
  child : Json,
  state : Json,
) -> Unit raise {
  self.with_changes(changes => {
    for
      r in self.all(
        "UPDATE opened_chats SET state = ? WHERE child_station = ? AND child = ? RETURNING parent, parent_station",
        [state, child_station, child],
      ) {
      if col(r, "parent_station") is String("") {
        changes.push(session_change(col(r, "parent")))
      }
    }
  })
}

///|
pub fn Store::set_opened_led(
  self : Store,
  child_station : Json,
  child : Json,
  led : Bool,
) -> Json raise {
  let mut changed = false
  let mut prev : Json = Json::null()
  self.with_changes(changes => {
    match
      self.one(
        "SELECT * FROM opened_chats WHERE child_station = ? AND child = ?",
        [child_station, child],
      ) {
      None => ()
      Some(existing) => {
        let p = to_opened(existing)
        prev = p
        let cur_led = match p {
          Object(m) => m.get("led")
          _ => None
        }
        let already = match cur_led {
          Some(True) => led
          Some(False) => !led
          _ => false
        }
        if !already {
          ignore(
            self.run(
              "UPDATE opened_chats SET led = ? WHERE child_station = ? AND child = ?",
              [flag(led), child_station, child],
            ),
          )
          changed = true
          if child_station is String("") {
            changes.push({
              "type": "chatMark",
              "thread": Json::null(),
              "session": child,
            })
            changes.push(session_change(child))
          }
          let prev_ps = col(existing, "parent_station")
          let prev_parent = col(existing, "parent")
          if prev_ps is String("") {
            changes.push({
              "type": "chatMark",
              "thread": Json::null(),
              "session": prev_parent,
            })
            changes.push(session_change(prev_parent))
          }
        }
      }
    }
  })
  { "changed": Json::boolean(changed), "prev": prev }
}

///|
pub fn Store::adopt_opened(self : Store, o : Json) -> Json raise {
  let get = (k : String) => match o {
    Object(m) => m.get(k).unwrap_or(Json::null())
    _ => Json::null()
  }
  let child_station = get("childStation")
  let child = get("child")
  let parent_station = get("parentStation")
  let parent = get("parent")
  let title = get("title")
  let link = get("link")
  let opener_title = get("openerTitle")
  let mut changed = false
  let mut prev : Json = Json::null()
  self.with_changes(changes => {
    match
      self.one(
        "SELECT * FROM opened_chats WHERE child_station = ? AND child = ?",
        [child_station, child],
      ) {
      Some(existing) => {
        let p = to_opened(existing)
        prev = p
        let prev_ps = col(existing, "parent_station")
        let prev_parent = col(existing, "parent")
        let already = match p {
          Object(m) =>
            m.get("led") is Some(True) &&
            prev_ps == parent_station &&
            prev_parent == parent
          _ => false
        }
        if already {
          let title_changed = !(title is Null) && title != col(existing, "title")
          let link_changed = !(link is Null) && link != col(existing, "link")
          if title_changed || link_changed {
            ignore(
              self.run(
                "UPDATE opened_chats SET title = COALESCE(?, title), link = COALESCE(?, link) WHERE child_station = ? AND child = ?",
                [title, link, child_station, child],
              ),
            )
            if child_station is String("") {
              changes.push({
                "type": "chatMark",
                "thread": Json::null(),
                "session": child,
              })
              changes.push(session_change(child))
            }
            if parent_station is String("") {
              changes.push({
                "type": "chatMark",
                "thread": Json::null(),
                "session": parent,
              })
              changes.push(session_change(parent))
            }
          }
        } else {
          ignore(
            self.run(
              "UPDATE opened_chats SET parent_station = ?, parent = ?, title = COALESCE(?, title), link = COALESCE(?, link), opener_title = ?, led = 1 WHERE child_station = ? AND child = ?",
              [
                parent_station, parent, title, link, opener_title, child_station,
                child,
              ],
            ),
          )
          changed = true
          if child_station is String("") {
            changes.push({
              "type": "chatMark",
              "thread": Json::null(),
              "session": child,
            })
            changes.push(session_change(child))
          }
          if parent_station is String("") {
            changes.push({
              "type": "chatMark",
              "thread": Json::null(),
              "session": parent,
            })
            changes.push(session_change(parent))
          }
          if prev_ps is String("") &&
            (prev_parent != parent || prev_ps != parent_station) {
            changes.push({
              "type": "chatMark",
              "thread": Json::null(),
              "session": prev_parent,
            })
            changes.push(session_change(prev_parent))
          }
        }
      }
      None => {
        let at = self.now()
        let key = Json::string("adopt:" + js_string(child))
        ignore(
          self.run(
            "INSERT INTO opened_chats (child_station, child, parent_station, parent, key, title, link, opener_title, led, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)",
            [
              child_station, child, parent_station, parent, key, title, link, opener_title,
              at,
            ],
          ),
        )
        changed = true
        if child_station is String("") {
          changes.push({
            "type": "chatMark",
            "thread": Json::null(),
            "session": child,
          })
          changes.push(session_change(child))
        }
        if parent_station is String("") {
          changes.push({
            "type": "chatMark",
            "thread": Json::null(),
            "session": parent,
          })
          changes.push(session_change(parent))
        }
      }
    }
  })
  { "changed": Json::boolean(changed), "prev": prev }
}

// ── runtime sessions ──

///|
pub fn Store::session_of_runtime(
  self : Store,
  runtime : Json,
  id : Json,
) -> Json raise {
  match self.one(session_of_runtime, [runtime, id]) {
    None => Json::null()
    Some(r) => self.get_session(js_string(col(r, "key")))
  }
}

///|
pub fn Store::runtime_sessions(self : Store, key : String) -> Array[Json] raise {
  let current = match self.get_session(key) {
    Null => Json::null()
    s => nullish(field(s, "runtimeSessionId"))
  }
  let ids = self
    .all(
      "SELECT id FROM runtime_sessions WHERE session_key = ? ORDER BY at, rowid",
      [jstr(key)],
    )
    .map(r => col(r, "id"))
  match current {
    Null => ids
    c => {
      let out = ids.filter(id => id != c)
      out.push(c)
      out
    }
  }
}

///|
/// Each recorded transcript's runtime and profile, in conversation order (`known`: its row, where the caller has it).
pub fn Store::runtime_session_sources(
  self : Store,
  key : String,
  known : Json?,
) -> Array[Json] raise {
  let row = match known {
    Some(k) => k
    None => self.get_session(key)
  }
  if row is Null {
    return []
  }
  let sources : Array[Json] = self
    .all(
      (
        #|SELECT r.id, COALESCE(r.runtime, s.original_runtime, s.runtime) AS runtime, r.profile
        #|      FROM sessions s CROSS JOIN runtime_sessions r ON r.session_key = s.key WHERE s.key = ? ORDER BY r.at, r.rowid
      ),
      [jstr(key)],
    )
    .map(r => {
      "id": col(r, "id"),
      "runtime": col(r, "runtime"),
      "profile": col(r, "profile"),
    })
  let current = nullish(field(row, "runtimeSessionId"))
  if current is Null {
    return sources
  }
  let mut entry : Json? = None
  for s in sources {
    if entry is None && field(s, "id") == Some(current) {
      entry = Some(s)
    }
  }
  let out = sources.filter(s => field(s, "id") != Some(current))
  out.push(
    match entry {
      Some(e) => e
      None =>
        {
          "id": current,
          "runtime": nullish(field(row, "runtime")),
          "profile": nullish(field(row, "profile")),
        }
    },
  )
  out
}

///|
/// runtime-source.ts `safe`: a string with no NUL, no U+FFFD and no lone surrogate.
fn safe_id(v : Json) -> Bool {
  guard v is String(s) else { return false }
  if s.contains("\u{0}") || s.contains("\u{fffd}") {
    return false
  }
  @utf8.decode_lossy(@utf8.encode(s)) == s
}

///|
/// One transcript's source, with the same identity and fallback rules as the ordered list (runtime-source.ts).
pub fn Store::runtime_session_source(
  self : Store,
  key : String,
  id : String,
) -> Json raise {
  let original = () => {
    let mut found = Json::null()
    for s in self.runtime_session_sources(key, None) {
      if found is Null && field(s, "id") == Some(jstr(id)) {
        found = s
      }
    }
    found
  }
  if !safe_id(jstr(id)) {
    return original()
  }
  let prefix = @utf8.encode(id)
  let bytes = (last : Int32) => {
    let out = []
    for b in prefix {
      out.push(jnum(b.to_int().to_double()))
    }
    out.push(jnum(last.to_double()))
    Json::array(out)
  }
  let row = self.one(
    (
      #|SELECT s.runtime_session_id AS current_id, s.runtime AS session_runtime, s.profile AS session_profile,
      #|      r.id AS source_id, COALESCE(r.runtime, s.original_runtime, s.runtime) AS source_runtime, r.profile AS source_profile,
      #|      EXISTS (SELECT 1 FROM runtime_sessions x WHERE x.session_key = s.key
      #|        AND x.id >= CAST(?3 AS TEXT) AND x.id < CAST(?4 AS TEXT)) AS ambiguous
      #|      FROM sessions s LEFT JOIN runtime_sessions r ON r.session_key = s.key AND r.id = ?2 WHERE s.key = ?1
    ),
    [jstr(key), jstr(id), bytes(0), bytes(1)],
  ) catch {
    _ => return original()
  }
  guard row is Some(row) else { return Json::null() }
  if truthy(col(row, "ambiguous")) ||
    (!(col(row, "current_id") is Null) && !safe_id(col(row, "current_id"))) {
    return original()
  }
  if !(col(row, "source_id") is Null) {
    if col(row, "source_id") != jstr(id) {
      return original()
    }
    return {
      "id": col(row, "source_id"),
      "runtime": col(row, "source_runtime"),
      "profile": col(row, "source_profile"),
    }
  }
  if col(row, "current_id") == jstr(id) {
    {
      "id": jstr(id),
      "runtime": col(row, "session_runtime"),
      "profile": col(row, "session_profile"),
    }
  } else {
    Json::null()
  }
}

///|
pub fn Store::transcript_in_use(
  self : Store,
  runtime : Json,
  id : Json,
  except : Json,
) -> Bool raise {
  self.one(transcript_in_use, [id, runtime, except]) is Some(_)
}

///|
pub fn Store::transcript_referenced(
  self : Store,
  runtime : Json,
  id : Json,
  except : Json,
) -> Bool raise {
  self.one(transcript_referenced, [id, runtime, except]) is Some(_)
}

///|
pub fn Store::session_paths_page(
  self : Store,
  after : Json,
  limit : Int,
) -> Array[Json] raise {
  self
  .all(session_paths_page, [after, jint(limit.to_int64())])
  .map(r => { "key": col(r, "key"), "workspace": col(r, "workspace"), "cwd": col(r, "cwd"), "archivedAt": col(r, "archived_at") })
}

///|
pub fn Store::set_running(
  self : Store,
  key : String,
  running : Bool,
) -> Unit raise {
  self.update_session(
    key,
    "UPDATE sessions SET running = ?1, last_active_at = ?2 WHERE key = ?3",
    [flag(running), self.now_json(), jstr(key)],
  )
}

///|
pub fn Store::touch(self : Store, key : String) -> Unit raise {
  ignore(
    self.run("UPDATE sessions SET last_active_at = ? WHERE key = ?", [
      self.now_json(),
      jstr(key),
    ]),
  )
}
