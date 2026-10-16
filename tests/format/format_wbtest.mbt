///|
/// Format parity over the fixtures and the corpus, controlled by
/// `GLEAM_FORMAT_MODE`: unset skips; `check` scores and fails below
/// `baseline.json`; `ratchet` scores and writes the counts.
priv enum Mode {
  Check
  Ratchet
}

///|
let fixtures_dir : String = "../tests/fixtures/format"

///|
let lock_path : String = "../tests/corpus/format.lock"

///|
let corpus_dir : String = "../.corpus"

///|
let baseline_path : String = "../tests/format/baseline.json"

///|
let reports_dir : String = "../_build/reports/format"

///|
let max_reported : Int32 = 20

///|
fn format_mode() -> Mode? raise {
  match @env.get_env_var("GLEAM_FORMAT_MODE") {
    None | Some("") => None
    Some("check") => Some(Check)
    Some("ratchet") => Some(Ratchet)
    Some(other) => fail("GLEAM_FORMAT_MODE: unknown mode \{other}")
  }
}

///|
priv struct FileResult {
  key : String
  matched : Bool
  detail : String? // the first difference, or the error
}

///|
fn format_or_error(text : String) -> Result[String, String] {
  Ok(@gleam.format(text)) catch {
    ParseFailed(ds) => Err("ParseFailed: \{ds.length()} error diagnostic(s)")
    OutOfFuel(_) => Err("OutOfFuel")
  }
}

///|
fn score_fixtures() -> Array[FileResult] raise {
  let results = []
  let suites = @fs.read_dir(fixtures_dir).to_owned()
  suites.sort()
  for suite in suites {
    let suite_dir = "\{fixtures_dir}/\{suite}"
    if !@fs.is_dir(suite_dir) {
      continue
    }
    let entries = @fs.read_dir(suite_dir).to_owned()
    entries.sort()
    for e in entries {
      if !e.has_suffix(".gleam") || e.has_suffix(".formatted.gleam") {
        continue
      }
      let stem = e.view(end_offset=e.length() - 6).to_owned()
      let expected_path = "\{suite_dir}/\{stem}.formatted.gleam"
      if !@fs.path_exists(expected_path) {
        continue
      }
      let input = @fs.read_file_to_string("\{suite_dir}/\{e}")
      let expected = @fs.read_file_to_string(expected_path)
      let key = "\{suite}/\{e}"
      results.push(
        match format_or_error(input) {
          Ok(actual) if actual == expected =>
            { key, matched: true, detail: None, }
          Ok(actual) =>
            {
              key,
              matched: false,
              detail: Some(first_difference(expected, actual)),
            }
          Err(e) => { key, matched: false, detail: Some(e), }
        },
      )
    }
  }
  results
}

///|
fn sha256_hex(text : String) -> String {
  @hex.encode(Bytes::from_array(@crypto.sha256(@utf8.encode(text))))
}

///|
/// The lock's entries: key and expected hash (or `FORMAT_ERROR`).
fn read_lock() -> Array[(String, String)] raise {
  let entries = []
  for line in @fs.read_file_to_string(lock_path).split("\n") {
    let l = line.to_owned()
    if l.is_empty() || l.has_prefix("#") {
      continue
    }
    guard l.split_once(" ") is Some((key, value)) else {
      fail("format.lock: bad line \{l}")
    }
    entries.push((key.to_owned(), value.to_owned()))
  }
  entries
}

///|
fn score_corpus() -> Array[FileResult] raise {
  if !@fs.path_exists(lock_path) || !@fs.path_exists(corpus_dir) {
    return []
  }
  let results = []
  for entry in read_lock() {
    let (key, expected) = entry
    let path = "\{corpus_dir}/\{key}"
    if !@fs.path_exists(path) {
      fail("missing corpus file \{path}; run mise run corpus:fetch")
    }
    let text = @fs.read_file_to_string(path)
    results.push(
      match format_or_error(text) {
        Ok(actual) if sha256_hex(actual) == expected =>
          { key, matched: true, detail: None, }
        Ok(_) =>
          {
            key,
            matched: false,
            detail: Some("output hash differs from the lock"),
          }
        Err(e) => { key, matched: false, detail: Some(e), }
      },
    )
  }
  results
}

///|
fn counts_of(
  fixtures : Array[FileResult],
  corpus : Array[FileResult],
) -> Counts {
  {
    fixtures: fixtures.length(),
    fixtures_matched: fixtures.filter(r => r.matched).length(),
    corpus: corpus.length(),
    corpus_matched: corpus.filter(r => r.matched).length(),
  }
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn escape_html(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
}

///|
fn write_reports(
  counts : Counts,
  baseline : Counts?,
  fixtures : Array[FileResult],
  corpus : Array[FileResult],
) -> Unit raise {
  ensure_dir("../_build")
  ensure_dir("../_build/reports")
  ensure_dir(reports_dir)
  let all = fixtures + corpus
  let unmatched = all.filter(r => !r.matched)
  let md = StringBuilder()
  md.write_string("## Format parity\n\n\{scoreboard(counts)}")
  match baseline {
    Some(b) =>
      md.write_string(
        " (baseline \{b.fixtures_matched}/\{b.fixtures}, \{b.corpus_matched}/\{b.corpus})\n",
      )
    None => md.write_string("\n")
  }
  md.write_string("\n\{unmatched.length()} unmatched.\n")
  let shown = if unmatched.length() < max_reported {
    unmatched.length()
  } else {
    max_reported
  }
  for i in 0..<shown {
    let r = unmatched[i]
    md.write_string("\n- `\{r.key}`: \{r.detail.unwrap_or("")}\n")
  }
  @fs.write_string_to_file("\{reports_dir}/summary.md", md.to_string())
  let files : Array[Json] = []
  for r in all {
    files.push({
      "key": Json(r.key),
      "matched": Json(r.matched),
      "detail": match r.detail {
        Some(d) => Json(d)
        None => Json::null()
      },
    })
  }
  let json : Json = { "counts": counts_to_json(counts), "files": Json(files) }
  @fs.write_string_to_file(
    "\{reports_dir}/format.json",
    json.stringify(indent=2) + "\n",
  )
  let html = StringBuilder()
  html.write_string(
    "<!doctype html><meta charset=utf-8><title>Format parity</title><style>body{font-family:sans-serif}pre{background:#f4f4f4;padding:4px}.ok{color:green}.no{color:#b00}</style><h1>\{escape_html(scoreboard(counts))}</h1><p><label><input type=checkbox id=f onchange=\"document.querySelectorAll('.ok').forEach(e=>e.style.display=this.checked?'none':'')\"> unmatched only</label></p><ul>",
  )
  for r in all {
    let cls = if r.matched { "ok" } else { "no" }
    html.write_string("<li class=\{cls}><code>\{escape_html(r.key)}</code>")
    if r.detail is Some(d) {
      html.write_string("<pre>\{escape_html(d)}</pre>")
    }
    html.write_string("</li>")
  }
  html.write_string("</ul>")
  @fs.write_string_to_file("\{reports_dir}/format.html", html.to_string())
}

///|
fn read_baseline() -> Counts? raise {
  if !@fs.path_exists(baseline_path) {
    return None
  }
  Some(counts_from_json(@json.parse(@fs.read_file_to_string(baseline_path))))
}

///|
test "format parity" {
  guard format_mode() is Some(mode) else { return }
  let fixtures = score_fixtures()
  let corpus = score_corpus()
  let counts = counts_of(fixtures, corpus)
  let baseline = read_baseline()
  write_reports(counts, baseline, fixtures, corpus)
  println(scoreboard(counts))
  match mode {
    Check =>
      match baseline {
        Some(b) => {
          let found = regressions(counts, b)
          if !found.is_empty() {
            fail("format parity regressed: " + found.join("; "))
          }
        }
        None =>
          fail(
            "no baseline at \{baseline_path}; run mise run formatter:ratchet",
          )
      }
    Ratchet => {
      let next = match baseline {
        Some(b) =>
          {
            fixtures: counts.fixtures,
            corpus: counts.corpus,
            fixtures_matched: if counts.fixtures_matched > b.fixtures_matched {
              counts.fixtures_matched
            } else {
              b.fixtures_matched
            },
            corpus_matched: if counts.corpus_matched > b.corpus_matched {
              counts.corpus_matched
            } else {
              b.corpus_matched
            },
          }
        None => counts
      }
      @fs.write_string_to_file(
        baseline_path,
        counts_to_json(next).stringify(indent=2) + "\n",
      )
      println("baseline written: \{scoreboard(next)}")
    }
  }
}
