///|
/// Rejection parity: gleam-parser's verdict and first error per fixture
/// against the verdicts recorded from the Gleam compiler
/// (`tests/rejection/verdicts.json`, written by `mise run rejection:record`).
///
/// Mismatches must be listed in `tests/rejection/pending.json`; the list only
/// shrinks. `GLEAM_REJECTION_MODE=write-pending` rewrites it from the current
/// mismatches (use it only when adding fixtures); `approve` writes the
/// message snapshots.

///|
let fixtures_dir : String = "../tests/rejection"

///|
let verdicts_path : String = "../tests/rejection/verdicts.json"

///|
let pending_path : String = "../tests/rejection/pending.json"

///|
let version_path : String = "../tests/corpus/gleam_version.txt"

///|
/// A fixture whose check does not match the oracle yet.
priv struct Pending {
  fixture : String
  /// `verdict` (accept against reject) or `error` (both reject; the first
  /// error's kind, lexical kind or location differs).
  check : String
} derive(Eq, Debug)

///|
fn sha256_bytes_hex(bytes : Bytes) -> String {
  @hex.encode(Bytes::from_array(@crypto.sha256(bytes)))
}

///|
/// Compare strings by code unit (`String::compare` compares length first).
fn compare_lexical(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = a.code_unit_at(i).compare(b.code_unit_at(i))
    if c != 0 {
      return c
    }
  }
  a.length().compare(b.length())
}

///|
fn compare_pending(a : Pending, b : Pending) -> Int32 {
  let by_fixture = compare_lexical(a.fixture, b.fixture)
  if by_fixture != 0 {
    return by_fixture
  }
  compare_lexical(a.check, b.check)
}

///|
/// The verdict key, `gleam-<version>` from `tests/corpus/gleam_version.txt`.
fn verdict_key() -> String raise {
  "gleam-" + @fs.read_file_to_string(version_path).trim().to_owned()
}

///|
/// gleam-parser's first error for `text`, if it rejects it (warnings do not
/// count).
fn first_error(text : String) -> @gleam.Diagnostic? {
  @gleam.parse_text(text).diagnostics.iter().find_first(d => d.is_error())
}

///|
/// The oracle's kind, lexical kind and location of a rejecting verdict.
fn oracle_error(v : Map[String, Json]) -> (String, String?, @gleam.SrcSpan)? {
  guard v.get("accepted") is Some(False) &&
    v.get("kind") is Some(String(kind)) &&
    v.get("location") is Some(Object(loc)) &&
    loc.get("start") is Some(Number(start, ..)) &&
    loc.get("end") is Some(Number(end, ..)) else {
    return None
  }
  let lexical_kind = match v.get("lexical_kind") {
    Some(String(s)) => Some(s)
    _ => None
  }
  Some(
    (
      kind,
      lexical_kind,
      @gleam.SrcSpan::from_compiler(
        @gleam.ByteOffset::from_int(start.to_int()).unwrap(),
        @gleam.ByteOffset::from_int(end.to_int()).unwrap(),
      ).unwrap(),
    ),
  )
}

///|
/// gleam-parser's first error as the oracle writes it: `LexError` with the
/// lexical kind for a scanner error, else the parse error kind.
fn error_identity(d : @gleam.Diagnostic) -> (String, String?, @gleam.SrcSpan) {
  if d.code == "GL-SCAN-001" {
    ("LexError", Some(d.kind), d.span)
  } else {
    (d.kind, None, d.span)
  }
}

///|
/// The checks of one fixture that do not match the oracle's verdict.
fn fixture_mismatches(
  fixture : String,
  text : String,
  v : Map[String, Json],
) -> Array[Pending] {
  let found = []
  let oracle_accepts = v.get("accepted") is Some(True)
  let error = first_error(text)
  if (error is None) != oracle_accepts {
    found.push({ fixture, check: "verdict", })
  } else if error is Some(d) && oracle_error(v) is Some(expected) {
    if error_identity(d) != expected {
      found.push({ fixture, check: "error", })
    }
  }
  found
}

///|
/// Fixtures whose verdict or first error differs from the oracle's, sorted.
/// `read` returns a fixture's bytes by its path relative to `tests/rejection`.
fn mismatches(
  verdicts : Json,
  key : String,
  read : (String) -> Bytes raise,
) -> Array[Pending] raise {
  guard verdicts is Object(entries) else {
    fail("\{verdicts_path}: expected an object")
  }
  let found = []
  for fixture, entry in entries {
    guard entry is Object(e) &&
      e.get("sha256") is Some(String(sha256)) &&
      e.get(key) is Some(Object(v)) else {
      fail("\{verdicts_path}: malformed entry \{fixture} (no \{key} verdict)")
    }
    let bytes = read(fixture)
    if sha256_bytes_hex(bytes) != sha256 {
      fail("\{fixture} changed: run `mise run rejection:record`")
    }
    found.append(fixture_mismatches(fixture, @utf8.decode(bytes), v))
  }
  found.sort_by(compare_pending)
  found
}

///|
/// Differences between the fixture files on disk and the recorded verdicts.
fn unrecorded(verdicts : Json, files : Array[String]) -> Array[String] {
  let recorded = match verdicts {
    Object(entries) => entries.keys().collect()
    _ => []
  }
  let problems = []
  for file in files {
    if !recorded.contains(file) {
      problems.push("\{file} not recorded: run `mise run rejection:record`")
    }
  }
  for key in recorded {
    if !files.contains(key) {
      problems.push("\{key} removed: run `mise run rejection:record`")
    }
  }
  problems
}

///|
/// `.gleam` files under `dir`, as paths relative to it, sorted.
fn gleam_files(dir : String) -> Array[String] raise {
  let found = []
  fn go(rel : String) raise {
    let full = if rel == "" { dir } else { "\{dir}/\{rel}" }
    for entry in @fs.read_dir(full) {
      let child = if rel == "" { entry } else { "\{rel}/\{entry}" }
      if @fs.is_dir("\{dir}/\{child}") {
        go(child)
      } else if child.has_suffix(".gleam") {
        found.push(child)
      }
    }
  }

  go("")
  found.sort_by(compare_lexical)
  found
}

///|
fn format_pending(entries : Array[Pending]) -> String {
  let sorted = entries.copy()
  sorted.sort_by(compare_pending)
  let items : Array[Json] = sorted.map(p => {
    "fixture": p.fixture,
    "check": p.check,
  })
  Json::array(items).stringify(indent=2) + "\n"
}

///|
fn parse_pending(text : String) -> Array[Pending] raise {
  guard @json.parse(text) is Array(items) else {
    fail("\{pending_path}: expected an array")
  }
  let entries = []
  for item in items {
    guard item is Object(o) &&
      o.get("fixture") is Some(String(fixture)) &&
      o.get("check") is Some(String(check)) else {
      fail("\{pending_path}: malformed entry")
    }
    entries.push({ fixture, check, })
  }
  entries.sort_by(compare_pending)
  entries
}

///|
fn describe(p : Pending) -> String {
  "\{p.fixture} \{p.check}"
}

///|
fn read_fixture(fixture : String) -> Bytes raise {
  @fs.read_file_to_bytes("\{fixtures_dir}/\{fixture}")
}

///|
test "rejection fixtures" {
  let verdicts = @json.parse(@fs.read_file_to_string(verdicts_path))
  let key = verdict_key()
  let missing = unrecorded(verdicts, gleam_files(fixtures_dir))
  if !missing.is_empty() {
    fail(missing.join("\n"))
  }
  let current = mismatches(verdicts, key, read_fixture)
  let fixture_count = match verdicts {
    Object(o) => o.length()
    _ => 0
  }
  let mode = @env.get_env_var("GLEAM_REJECTION_MODE")
  let (rows, messages) = report_rows(verdicts, key, read_fixture)
  ensure_dir(reports_dir)
  @fs.write_string_to_file("\{reports_dir}/index.html", report_html(rows))
  let snapshot_problems = check_snapshots(messages, mode is Some("approve"))
  if mode is Some("write-pending") {
    @fs.write_string_to_file(pending_path, format_pending(current))
    println("rejection: wrote \{current.length()} entries to \{pending_path}")
    return
  }
  let pending = if @fs.path_exists(pending_path) {
    parse_pending(@fs.read_file_to_string(pending_path))
  } else {
    []
  }
  println("rejection: \{fixture_count} fixtures | \{current.length()} pending")
  let unexpected = current.filter(p => !pending.contains(p))
  let fixed = pending.filter(p => !current.contains(p))
  let problems = []
  for p in unexpected {
    problems.push("new mismatch: \{describe(p)}")
  }
  for p in fixed {
    problems.push("now matches, remove from \{pending_path}: \{describe(p)}")
  }
  problems.append(snapshot_problems)
  if !problems.is_empty() {
    fail(problems.join("\n"))
  }
}
