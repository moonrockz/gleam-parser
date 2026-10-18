///|
/// Parity counts over the corpus.
priv struct Counts {
  files : Int32
  tokenized : Int32
  parsed : Int32
  matched : Int32
}

///|
fn counts_to_json(c : Counts) -> Json {
  {
    "files": Json(c.files),
    "tokenized": Json(c.tokenized),
    "parsed": Json(c.parsed),
    "matched": Json(c.matched),
  }
}

///|
fn counts_from_json(json : Json) -> Counts raise {
  guard json is Object(o) &&
    o.get("files") is Some(Number(files, ..)) &&
    o.get("tokenized") is Some(Number(tokenized, ..)) &&
    o.get("parsed") is Some(Number(parsed, ..)) &&
    o.get("matched") is Some(Number(matched, ..)) else {
    fail("baseline: expected files, tokenized, parsed and matched counts")
  }
  {
    files: files.to_int(),
    tokenized: tokenized.to_int(),
    parsed: parsed.to_int(),
    matched: matched.to_int(),
  }
}

///|
fn counts_text(c : Counts) -> String {
  "\{c.files} files, \{c.tokenized} tokenized, \{c.parsed} parsed, \{c.matched} matched"
}

///|
/// Names of the counts that are below the baseline, with both values.
fn regressions(current : Counts, baseline : Counts) -> Array[String] {
  let found = []
  let pairs = [
    ("files", current.files, baseline.files),
    ("tokenized", current.tokenized, baseline.tokenized),
    ("parsed", current.parsed, baseline.parsed),
    ("matched", current.matched, baseline.matched),
  ]
  for p in pairs {
    let (name, now, min) = p
    if now < min {
      found.push("\{name}: \{now} < baseline \{min}")
    }
  }
  found
}

///|
/// One-line scoreboard, for example `parity: 232 files | tokenized 232 | parsed 230 | matched 228`.
fn scoreboard(c : Counts) -> String {
  "parity: \{c.files} files | tokenized \{c.tokenized} | parsed \{c.parsed} | matched \{c.matched}"
}

///|
/// The new baseline for a ratchet: the current counts, or an error when any
/// count is below the baseline (a ratchet never lowers it).
fn ratchet(current : Counts, baseline : Counts) -> Result[Counts, String] {
  let found = regressions(current, baseline)
  if found.is_empty() {
    Ok(current)
  } else {
    Err(found.join("; "))
  }
}

///|
/// Differences between the lock and the manifest: lock entries whose source
/// hash differs or that the manifest does not list, then manifest files the
/// lock does not list. The lock must be regenerated when this is not empty.
fn source_problems(
  lock : Array[LockEntry],
  manifest : Array[(String, String)],
) -> Array[String] {
  let expected : Map[String, String] = Map::from_array(manifest)
  let problems = []
  let locked : Map[String, Bool] = Map([])
  for entry in lock {
    if locked.contains(entry.key) {
      problems.push("duplicate lock key: \{entry.key}")
    }
    locked[entry.key] = true
    match expected.get(entry.key) {
      None => problems.push("not in the manifest: \{entry.key}")
      Some(sha) =>
        if sha != entry.source_sha256 {
          problems.push("source hash differs from the manifest: \{entry.key}")
        }
    }
  }
  for m in manifest {
    if !locked.contains(m.0) {
      problems.push("not in the lock: \{m.0}")
    }
  }
  problems
}
