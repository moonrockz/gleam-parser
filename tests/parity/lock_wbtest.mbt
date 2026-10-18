///|
/// Golden result for one corpus file.
priv enum Golden {
  Hash(String)
  ParseError(String, String?, Int32, Int32)
}

///|
/// One line of `tests/corpus/goldens.lock`.
priv struct LockEntry {
  key : String
  source_sha256 : String
  golden : Golden
}

///|
let parse_error_marker : String = "PARSE_ERROR"

///|
let lock_header : String = "# <corpus key> <source sha256> <canonical oracle JSON sha256 | PARSE_ERROR:<kind>:<lexical kind or ->:<start>:<end>>"

///|
/// The lock form of a golden: the hash, or
/// `PARSE_ERROR:<kind>:<lexical kind or ->:<start>:<end>`.
fn format_golden(golden : Golden) -> String {
  match golden {
    Hash(h) => h
    ParseError(kind, lexical, start, end) =>
      "\{parse_error_marker}:\{kind}:\{lexical.unwrap_or("-")}:\{start}:\{end}"
  }
}

///|
/// Read a golden from its lock form; a bare `PARSE_ERROR` is malformed.
fn parse_golden(text : String) -> Golden raise {
  if !text.has_prefix(parse_error_marker) {
    return Hash(text)
  }
  let parts = text.split(":").map(p => p.to_owned()).collect()
  guard parts is [_, kind, lexical, start, end] && kind != "" && lexical != "" else {
    fail("goldens.lock: malformed PARSE_ERROR golden: \{text}")
  }
  let lexical_kind = if lexical == "-" { None } else { Some(lexical) }
  ParseError(
    kind,
    lexical_kind,
    @string.parse_int(start),
    @string.parse_int(end),
  )
}

///|
/// Parse the lock text: one `<key> <source-sha256> <golden-sha256|PARSE_ERROR>` per line.
fn parse_lock(text : String) -> Array[LockEntry] raise {
  let entries = []
  for raw in text.split("\n") {
    let line = raw.trim().to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    let fields = line
      .split(" ")
      .filter(f => f != "")
      .map(f => f.to_owned())
      .collect()
    guard fields is [key, source_sha256, golden] else {
      fail("goldens.lock: malformed line: \{line}")
    }
    entries.push({ key, source_sha256, golden: parse_golden(golden), })
  }
  entries
}

///|
/// Format lock entries sorted by key, one per line.
fn format_lock(entries : Array[LockEntry]) -> String {
  let sorted = entries.copy()
  sorted.sort_by((a, b) => @tooling.compare_lexical(a.key, b.key))
  let sb = StringBuilder()
  sb.write_string(lock_header + "\n")
  for e in sorted {
    sb.write_string("\{e.key} \{e.source_sha256} \{format_golden(e.golden)}\n")
  }
  sb.to_string()
}
