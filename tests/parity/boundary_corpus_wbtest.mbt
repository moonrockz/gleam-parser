///|
test "crlf_text turns every line break into CRLF once" {
  @expect.expect_all(s => {
    s.expect(crlf_text("a\nb\r\nc\n")).to_equal("a\r\nb\r\nc\r\n")
    s.expect(crlf_text("")).to_equal("")
    s.expect(crlf_text("no break")).to_equal("no break")
  })
}

///|
test "token boundaries include token ends, a cut inside each token and the end" {
  // `pub fn f() { 1 }` in bytes: pub 0..3, fn 4..6, f 7..8, ( 8..9, ) 9..10,
  // { 11..12, 1 13..14, } 15..16; the text ends at 16.
  let text = "pub fn f() { 1 }"
  @expect.expect_all(s => {
    s
    .expect(token_boundaries(text))
    .to_equal([0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
    // A cut one byte into a multi-byte character is not a boundary.
    s.expect(token_boundaries("é")).to_equal([0, 2])
    s.expect(prefix_cuts([0, 5, 9])).to_equal([0, 5, 9])
    let many = Array::makei(101, i => i)
    let cuts = prefix_cuts(many)
    s.expect((cuts.length(), cuts[0], cuts[49])).to_equal((50, 0, 100))
  })
}

///|
test "prefix_problems is empty for a valid module and for a cut module" {
  @expect.expect_all(s => {
    s.expect(prefix_problems("ok", "pub fn f() {\n  1\n}\n")).to_equal([])
    s.expect(prefix_problems("cut", "pub fn f() {\n  1 +")).to_equal([])
    s.expect(prefix_problems("hole", "pub fn f() {\n  \"abc")).to_equal([])
  })
}

///|
test "round_trip_problems is empty for a parsed module" {
  @expect.expect(
    round_trip_problems(
      "k", "import gleam/io\n\npub fn main() {\n  io.println(\"hi\")\n}\n",
    ),
  ).to_equal([])
}

///|
/// At most this many prefixes are cut from one corpus file.
let max_prefixes : Int32 = 50

///|
/// `text` with every line break as `\r\n` (an existing `\r\n` stays one break).
fn crlf_text(text : String) -> String {
  text.replace_all(old="\r\n", new="\n").replace_all(old="\n", new="\r\n")
}

///|
/// Whether the span of `d` lies inside `source` and both ends are code point
/// boundaries. The compiler marks the end of the text with `end: 0`:
/// `UnexpectedEof` is `0..0`, and `InvalidModuleTypePattern` at the end of
/// a file is `start..0` (`parse.rs` takes the end of the inner
/// `UnexpectedEof`). The parser keeps those spans, so only that kind may
/// have an end before its start.
fn span_in_bounds(source : @gleam.SourceText, d : @gleam.Diagnostic) -> Bool {
  let s = d.span
  let ordered = s.start <= s.end ||
    (s.end.to_int() == 0 && d.kind == "InvalidModuleTypePattern")
  ordered &&
  s.end <= source.end_offset() &&
  source.position_of(s.start) is Some(_) &&
  source.position_of(s.end) is Some(_)
}

///|
/// The never-crash laws on one text: the scanner and the parser report every
/// diagnostic inside the source on code point boundaries; the CST rebuilds
/// the text; every diagnostic renders (plain and terminal) with the path in
/// its header; the JSON report decodes.
fn prefix_problems(label : String, text : String) -> Array[String] {
  let problems = []
  let source = @gleam.SourceText(text)
  let stream = @gleam.tokenize_text(text)
  if stream.to_source() != text {
    problems.push("\{label}: the token stream does not rebuild the text")
  }
  if !stream.diagnostics.iter().all(d => span_in_bounds(source, d)) {
    problems.push("\{label}: a scanner diagnostic outside the source")
  }
  let result = @gleam.parse_module(stream)
  if result.cst.to_source() != text {
    problems.push("\{label}: the CST does not rebuild the text")
  }
  if !result.diagnostics.iter().all(d => span_in_bounds(source, d)) {
    problems.push("\{label}: a parser diagnostic outside the source")
  }
  for d in result.diagnostics {
    let plain = @gleam.render_plain(d, source, "src/m.gleam")
    let terminal = @gleam.render_terminal(d, source, "src/m.gleam")
    if !plain.contains("src/m.gleam") || !terminal.contains("src/m.gleam") {
      problems.push("\{label}: a rendered diagnostic does not name the path")
      break
    }
  }
  let json = @gleam.encode_diagnostics(result.diagnostics)
  guard json is Array(items) && items.length() == result.diagnostics.length() else {
    problems.push("\{label}: the JSON report does not list every diagnostic")
    return problems
  }
  problems
}

///|
/// The byte offsets where `text` can be cut: 0, each token's start and end,
/// one byte into each token longer than one byte when that is a code point
/// boundary, and the end of the text; sorted, without duplicates.
fn token_boundaries(text : String) -> Array[Int32] {
  let source = @gleam.SourceText(text)
  let found = [0, source.byte_length().to_int()]
  for t in @gleam.tokenize_text(text).tokens {
    found.push(t.span.start.to_int())
    found.push(t.span.end.to_int())
    let inside = t.span.start.to_int() + 1
    if t.span.end.to_int() - t.span.start.to_int() > 1 &&
      source.position_of(@gleam.ByteOffset::new(inside).unwrap()) is Some(_) {
      found.push(inside)
    }
  }
  found.sort()
  found.dedup()
  found
}

///|
/// The offsets where `text`'s prefixes are cut: every token boundary, or at
/// most `max_prefixes` of them, evenly spaced (the first and the last
/// included).
fn prefix_cuts(boundaries : Array[Int32]) -> Array[Int32] {
  if boundaries.length() <= max_prefixes {
    return boundaries
  }
  Array::makei(max_prefixes, i => {
    boundaries[i * (boundaries.length() - 1) / (max_prefixes - 1)]
  })
}

///|
/// The text up to byte offset `cut`, or `None` when `cut` is not a code
/// point boundary (a token span that is not on a boundary is a scanner bug).
fn prefix(source : @gleam.SourceText, cut : Int32) -> String? {
  source
  .utf16_offset_of(@gleam.ByteOffset::new(cut).unwrap())
  .map(units => source.text().view(end_offset=units.to_int()).to_owned())
}

///|
/// The JSON laws on a corpus file: decoding the canonical JSON of the parse
/// result gives it back, and encoding that again gives the same text.
fn round_trip_problems(key : String, text : String) -> Array[String] {
  let result = @gleam.parse_text(text)
  if result.has_errors() {
    return ["\{key}: does not parse"]
  }
  let parsed = result.parsed()
  let canonical = @gleam.canonical(@gleam.encode_parsed(parsed))
  let same = try @gleam.decode_parsed(@json.parse(canonical)) catch {
    _ => false
  } noraise {
    back =>
      back == parsed &&
      @gleam.canonical(@gleam.encode_parsed(back)) == canonical
  }
  if same {
    []
  } else {
    ["\{key}: decoding the encoded AST does not give it back"]
  }
}

///|
/// Boundary laws over the corpus: the lossless scan and parse with LF and
/// with CRLF line breaks, the JSON round trip on every parsed file, and the
/// never-crash laws on prefixes cut at token boundaries. Runs in the parity
/// modes that score.
test "boundary laws over the corpus" {
  match parity_mode() {
    None | Some(WriteLock) => ()
    Some(_) => {
      let problems = []
      let mut files = 0
      let mut prefixes = 0
      for source in manifest_sources() {
        let (key, sha256) = source
        let text = verified_source(key, sha256)
        problems.append(prefix_problems(key, text))
        problems.append(prefix_problems("\{key} (CRLF)", crlf_text(text)))
        if !@gleam.parse_text(text).has_errors() {
          problems.append(round_trip_problems(key, text))
        }
        let st = @gleam.SourceText(text)
        for cut in prefix_cuts(token_boundaries(text)) {
          match prefix(st, cut) {
            Some(p) =>
              problems.append(prefix_problems("\{key} (prefix \{cut})", p))
            None =>
              problems.push("\{key}: cut \{cut} is not a code point boundary")
          }
          prefixes = prefixes + 1
        }
        files = files + 1
      }
      println("boundary laws: \{files} files, \{prefixes} prefixes")
      if !problems.is_empty() {
        fail(
          "boundary laws: \{problems.length()} problems:\n" +
          problems.iter().take(10).collect().join("\n"),
        )
      }
    }
  }
}

///|
test "span_in_bounds allows end 0 only for the compiler's EOF spans" {
  let source = @gleam.SourceText("pub fn f() {\n  1\n}\n")
  fn diag(kind : String, start : Int32, end : Int32) -> @gleam.Diagnostic {
    @gleam.Diagnostic(
      code="GL-PARSE-001",
      severity=Error,
      title="Syntax error",
      message="m",
      span=@gleam.SrcSpan::from_compiler(
        @gleam.ByteOffset::new(start).unwrap(),
        @gleam.ByteOffset::new(end).unwrap(),
      ).unwrap(),
      kind~,
    )
  }

  @expect.expect_all(s => {
    s.expect(span_in_bounds(source, diag("UnexpectedEof", 0, 0))).to_be_true()
    s.expect(span_in_bounds(source, diag("UnexpectedEof", 5, 0))).to_be_false()
    s
    .expect(span_in_bounds(source, diag("InvalidModuleTypePattern", 5, 0)))
    .to_be_true()
    s
    .expect(span_in_bounds(source, diag("UnexpectedToken", 5, 0)))
    .to_be_false()
    s.expect(@gleam.SrcSpan::new(5, 4)).to_equal(None)
    s.expect(span_in_bounds(source, diag("UnexpectedToken", 5, 6))).to_be_true()
    s
    .expect(span_in_bounds(source, diag("UnexpectedToken", 5, 99)))
    .to_be_false()
  })
}

///|
test "prefix refuses a cut inside a character" {
  let source = @gleam.SourceText("é x")
  @expect.expect_all(s => {
    s.expect(prefix(source, 2)).to_equal(Some("é"))
    s.expect(prefix(source, 1)).to_equal(None)
    s.expect(prefix(source, 4)).to_equal(Some("é x"))
  })
}
