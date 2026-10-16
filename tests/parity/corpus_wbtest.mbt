///|
/// Parity check over the pinned corpus, controlled by `GLEAM_PARITY_MODE`:
///
/// - unset: skip (so `moon test` works without the fetched corpus).
/// - `check`: score gleam-parser against `tests/corpus/goldens.lock`; fail
///   when a count drops below `tests/corpus/baseline.json`.
/// - `ratchet`: score, then write the counts to `tests/corpus/baseline.json`.
/// - `write-lock`: hash the raw oracle output in `.dev/out/goldens/raw` and
///   write `tests/corpus/goldens.lock`.
priv enum Mode {
  Check
  Ratchet
  WriteLock
}

///|
let manifest_path : String = "../tests/corpus/manifest.json"

///|
let lock_path : String = "../tests/corpus/goldens.lock"

///|
let baseline_path : String = "../tests/corpus/baseline.json"

///|
let version_path : String = "../tests/corpus/gleam_version.txt"

///|
let cargo_path : String = "../tools/gleam-ast-oracle/Cargo.toml"

///|
let corpus_dir : String = "../.corpus"

///|
let raw_goldens_dir : String = "../.dev/out/goldens/raw"

///|
fn parity_mode() -> Mode? raise {
  match @env.get_env_var("GLEAM_PARITY_MODE") {
    None | Some("") => None
    Some("check") => Some(Check)
    Some("ratchet") => Some(Ratchet)
    Some("write-lock") => Some(WriteLock)
    Some(other) => fail("unknown GLEAM_PARITY_MODE: \{other}")
  }
}

///|
/// Corpus keys and source SHA-256 from the manifest, in manifest order.
fn manifest_sources() -> Array[(String, String)] raise {
  guard @json.parse(@fs.read_file_to_string(manifest_path)) is Object(root) &&
    root.get("packages") is Some(Array(packages)) else {
    fail("\{manifest_path}: missing packages array")
  }
  let sources = []
  for p in packages {
    guard p is Object(pkg) &&
      pkg.get("name") is Some(String(name)) &&
      pkg.get("version") is Some(String(version)) &&
      pkg.get("files") is Some(Array(files)) else {
      fail("\{manifest_path}: malformed package entry")
    }
    for f in files {
      guard f is Object(file) &&
        file.get("path") is Some(String(path)) &&
        file.get("sha256") is Some(String(sha)) else {
        fail("\{manifest_path}: malformed file entry in \{name}")
      }
      sources.push(("\{name}@\{version}/\{path}", sha))
    }
  }
  sources
}

///|
/// Read a corpus file after checking it against its expected SHA-256.
fn verified_source(key : String, expected_sha256 : String) -> String raise {
  let path = "\{corpus_dir}/\{key}"
  if !@fs.path_exists(path) {
    fail("missing corpus file \{path}; run mise run corpus:fetch")
  }
  let bytes = @fs.read_file_to_bytes(path)
  if sha256_bytes_hex(bytes) != expected_sha256 {
    fail(
      "corpus file \{path} does not match its pinned hash; run rm -rf .corpus && mise run corpus:fetch",
    )
  }
  @fs.read_file_to_string(path)
}

///|
fn write_lock() -> Unit raise {
  let entries = []
  for source in manifest_sources() {
    let (key, source_sha256) = source
    // The oracle parsed this file, so it must be the pinned source.
    ignore(verified_source(key, source_sha256))
    let raw = "\{raw_goldens_dir}/\{key}"
    let golden = if @fs.path_exists("\{raw}.json") {
      Hash(golden_hash(@json.parse(@fs.read_file_to_string("\{raw}.json"))))
    } else if @fs.path_exists("\{raw}.error") {
      guard @gleam.decode_oracle_output(
          @json.parse(@fs.read_file_to_string("\{raw}.error")),
        )
        is Error(kind~, lexical_kind~, location~) else {
        fail("\{raw}.error is not an oracle error")
      }
      ParseError(
        kind,
        lexical_kind,
        location.start.to_int(),
        location.end.to_int(),
      )
    } else {
      fail("missing oracle output for \{key}; run mise run corpus:goldens")
    }
    entries.push({ key, source_sha256, golden, })
  }
  @fs.write_string_to_file(lock_path, format_lock(entries))
  println("parity: wrote \{lock_path} (\{entries.length()} files)")
}

///|
/// The Gleam version the corpus and the oracle are pinned to.
fn pinned_gleam_version() -> String raise {
  @fs.read_file_to_string(version_path).trim().to_owned()
}

///|
test "the oracle's Cargo.toml and gleam_version.txt name the same Gleam tag" {
  let cargo = @fs.read_file_to_string(cargo_path)
  @expect.expect(cargo).to_contain("tag = \"v\{pinned_gleam_version()}\"")
}

///|
let max_reported_mismatches : Int32 = 20

///|
let reports_dir : String = "../_build/reports/parity"

///|
/// Whether gleam-parser's first error is the oracle's: the same kind, lexical
/// kind and location (the rule of `tests/features/parser.feature`).
fn first_error_matches(
  result : @gleam.ParseResult,
  oracle : @gleam.OracleOutput,
) -> Bool {
  guard oracle is Error(kind~, lexical_kind~, location~) else { return false }
  guard result.diagnostics.filter(d => d.is_error()).get(0) is Some(d) else {
    return false
  }
  let (actual_kind, actual_lexical) = if d.code == "GL-SCAN-001" {
    ("LexError", Some(d.kind))
  } else {
    (d.kind, None)
  }
  actual_kind == kind && actual_lexical == lexical_kind && d.span == location
}

///|
/// Whether gleam-parser's result matches a golden: the same canonical JSON
/// hash, or (for a file the oracle rejects) the oracle's first error. A hash
/// match counts even when gleam-parser also reported warnings.
fn golden_matches(
  golden : Golden,
  result : @gleam.ParseResult,
  actual : Json,
) -> Bool {
  match golden {
    Hash(h) => golden_hash(actual) == h
    ParseError(kind, lexical_kind, start, end) =>
      first_error_matches(
        result,
        Error(
          kind~,
          lexical_kind~,
          location=@gleam.SrcSpan::from_compiler(
            @gleam.ByteOffset::from_int(start).unwrap(),
            @gleam.ByteOffset::from_int(end).unwrap(),
          ).unwrap(),
        ),
      )
  }
}

///|
/// Path of the first difference from the raw oracle JSON, when the raw
/// golden exists locally (`mise run corpus:goldens`).
fn difference_path(key : String, actual : Json) -> String? {
  let raw = "\{raw_goldens_dir}/\{key}.json"
  if !@fs.path_exists(raw) {
    return None
  }
  let expected = try @json.parse(@fs.read_file_to_string(raw)) catch {
    _ => return None
  } noraise {
    j => j
  }
  first_difference(expected, actual).map(d => d.path)
}

///|
/// Mismatch details for one file, printed after the scoreboard.
fn mismatch_report(key : String, actual : Json, has_errors : Bool) -> String {
  let raw = "\{raw_goldens_dir}/\{key}.json"
  let detail = if @fs.path_exists(raw) {
    let expected = try @json.parse(@fs.read_file_to_string(raw)) catch {
      _ => Json::null()
    } noraise {
      j => j
    }
    match first_difference(expected, actual) {
      Some(d) =>
        "  first difference at \{d.path}\n    oracle:       \{brief(d.expected)}\n    gleam-parser: \{brief(d.actual)}"
      None => "  JSON equal after decoding; hash differs"
    }
  } else if has_errors {
    "  gleam-parser reports an error; the oracle parses the file"
  } else {
    "  run mise run corpus:goldens locally for the structural diff"
  }
  "mismatch: \{key}\n\{detail}"
}

///|
/// Score every corpus file in the lock; one result per file.
fn score() -> Array[FileReport] raise {
  let entries = parse_lock(@fs.read_file_to_string(lock_path))
  let problems = source_problems(entries, manifest_sources())
  if !problems.is_empty() {
    fail(
      "\{lock_path} does not match \{manifest_path} (run mise run corpus:goldens): " +
      problems.join("; "),
    )
  }
  let files = []
  let mismatches = []
  for entry in entries {
    let text = verified_source(entry.key, entry.source_sha256)
    let stream = @gleam.tokenize_text(text)
    let tokenized = !stream.has_errors()
    let result = @gleam.parse_module(stream)
    let parsed = !result.has_errors()
    let actual = @gleam.encode_parsed(result.parsed())
    let matched = golden_matches(entry.golden, result, actual)
    let source = @gleam.SourceText(text)
    let diagnostic = result.diagnostics
      .get(0)
      .map(d => {
        let position = source.position_of(d.span.start)

        {
          code: d.code,
          kind: d.kind,
          message: d.message,
          line: position.map(p => p.line.to_int()).unwrap_or(0),
          column: position.map(p => p.column.to_int()).unwrap_or(0),
        }
      })
    let difference = if matched {
      None
    } else {
      difference_path(entry.key, actual)
    }
    files.push({
      key: entry.key,
      tokenized,
      parsed,
      matched,
      diagnostic,
      difference,
    })
    if !matched && mismatches.length() < max_reported_mismatches {
      mismatches.push(mismatch_report(entry.key, actual, result.has_errors()))
    }
  }
  let counts = parity_report(files, None).counts
  println(scoreboard(counts))
  for m in mismatches {
    println(m)
  }
  files
}

///|
fn read_baseline() -> Counts? raise {
  if @fs.path_exists(baseline_path) {
    Some(counts_from_json(@json.parse(@fs.read_file_to_string(baseline_path))))
  } else {
    None
  }
}

///|
/// Create `path` and its parents (like `mkdir -p`).
fn ensure_dir(path : String) -> Unit raise {
  let mut prefix = ""
  for part in path.split("/") {
    prefix = if prefix == "" { part.to_owned() } else { "\{prefix}/\{part}" }
    if !@fs.path_exists(prefix) {
      @fs.create_dir(prefix)
    }
  }
}

///|
/// Write `parity.json`, `parity.xml` (JUnit), `parity.html` and `summary.md`.
fn write_reports(report : ParityReport) -> Unit raise {
  ensure_dir(reports_dir)
  @fs.write_string_to_file(
    "\{reports_dir}/parity.json",
    report_json(report).stringify(indent=2) + "\n",
  )
  @fs.write_string_to_file("\{reports_dir}/parity.xml", report_junit(report))
  @fs.write_string_to_file("\{reports_dir}/parity.html", report_html(report))
  @fs.write_string_to_file("\{reports_dir}/summary.md", report_markdown(report))
  println("parity: wrote reports to \{reports_dir}")
}

///|
test "parity corpus" {
  match parity_mode() {
    None =>
      println(
        "parity: skipped (set GLEAM_PARITY_MODE or run mise run test:parity)",
      )
    Some(WriteLock) => write_lock()
    Some(mode) => {
      let baseline = read_baseline()
      let files = score()
      let report = parity_report(
        files,
        baseline,
        commit=@env.get_env_var("GITHUB_SHA"),
        gleam_version=pinned_gleam_version(),
      )
      // Reports are written first, so CI keeps them when this fails.
      write_reports(report)
      match mode {
        Check => {
          if baseline is None {
            fail("missing \{baseline_path}; run mise run parity:ratchet")
          }
          if !report.regressions.is_empty() {
            fail("parity regressed: " + report.regressions.join("; "))
          }
        }
        _ => {
          if baseline is Some(b) && ratchet(report.counts, b) is Err(message) {
            fail("parity ratchet refused to lower the baseline: " + message)
          }
          @fs.write_string_to_file(
            baseline_path,
            counts_to_json(report.counts).stringify(indent=2) + "\n",
          )
          println("parity: wrote \{baseline_path}")
        }
      }
    }
  }
}

///|
test "first_error_matches compares kind, lexical kind and location" {
  let text = "pub fn f() {\n  1 +\n}\n"
  let result = @gleam.parse_text(text)
  guard result.diagnostics.filter(d => d.is_error()).get(0) is Some(d) else {
    fail("expected an error")
  }
  @expect.expect_all(s => {
    s
    .expect(
      first_error_matches(
        result,
        Error(kind=d.kind, lexical_kind=None, location=d.span),
      ),
    )
    .to_be_true()
    s
    .expect(
      first_error_matches(
        result,
        Error(kind="UnexpectedEof", lexical_kind=None, location=d.span),
      ),
    )
    .to_be_false()
    s
    .expect(
      first_error_matches(
        result,
        Error(
          kind=d.kind,
          lexical_kind=None,
          location=@gleam.SrcSpan::from_ints(0, 0).unwrap(),
        ),
      ),
    )
    .to_be_false()
    s
    .expect(
      first_error_matches(
        @gleam.parse_text("pub fn f() { 1 }\n"),
        Error(kind=d.kind, lexical_kind=None, location=d.span),
      ),
    )
    .to_be_false()
  })
}

///|
test "a PARSE_ERROR golden matches only the oracle's first error" {
  let text = "pub fn f() {\n  1 +\n}\n"
  let result = @gleam.parse_text(text)
  guard result.diagnostics.filter(d => d.is_error()).get(0) is Some(d) else {
    fail("expected an error")
  }
  let actual = @gleam.encode_parsed(result.parsed())
  @expect.expect_all(s => {
    s
    .expect(
      golden_matches(
        ParseError(d.kind, None, d.span.start.to_int(), d.span.end.to_int()),
        result,
        actual,
      ),
    )
    .to_be_true()
    s
    .expect(
      golden_matches(ParseError("UnexpectedEof", None, 0, 0), result, actual),
    )
    .to_be_false()
    s
    .expect(
      golden_matches(
        ParseError(
          d.kind,
          Some("X"),
          d.span.start.to_int(),
          d.span.end.to_int(),
        ),
        result,
        actual,
      ),
    )
    .to_be_false()
    s
    .expect(golden_matches(Hash(golden_hash(actual)), result, actual))
    .to_be_true()
    s.expect(golden_matches(Hash("00"), result, actual)).to_be_false()
    let ok = @gleam.parse_text("pub fn f() {\n  1\n}\n")
    s
    .expect(
      golden_matches(
        ParseError(d.kind, None, 0, 1),
        ok,
        @gleam.encode_parsed(ok.parsed()),
      ),
    )
    .to_be_false()
  })
}
