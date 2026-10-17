///|
/// A formatter with no comments, for snippets.
fn bare() -> Formatter {
  Formatter(
    @ast.ModuleExtra::empty(),
    @scanner.SourceText(""),
    @config.Config::default(),
  )
}

///|
fn pattern_text(text : String) -> String raise {
  let p = @parser.parse_pattern_text(text)
  let f = bare()
  pretty_print(f.runner.run(() => f.pattern(p)))
}

///|
test "patterns: literals, variables, discards, assignments, tuples, constructors" {
  @expect.expect_all(s => {
    s.expect(pattern_text("12345")).to_equal("12_345")
    s.expect(pattern_text("1.50")).to_equal("1.5")
    s.expect(pattern_text("\"s\"")).to_equal("\"s\"")
    s.expect(pattern_text("x")).to_equal("x")
    s.expect(pattern_text("_x")).to_equal("_x")
    s.expect(pattern_text("Some(x) as y")).to_equal("Some(x) as y")
    s.expect(pattern_text("_ as y")).to_equal("y")
    s.expect(pattern_text("#(a,b)")).to_equal("#(a, b)")
    s.expect(pattern_text("None")).to_equal("None")
    s.expect(pattern_text("one.Two(a,b: c)")).to_equal("one.Two(a, b: c)")
    s.expect(pattern_text("Two(..)")).to_equal("Two(..)")
    s.expect(pattern_text("Two(a, ..)")).to_equal("Two(a, ..)")
    s.expect(pattern_text("Two(a:)")).to_equal("Two(a:)")
  })
}

///|
test "patterns: lists, string prefixes, bit arrays and sizes" {
  @expect.expect_all(s => {
    s.expect(pattern_text("[]")).to_equal("[]")
    s.expect(pattern_text("[a,b]")).to_equal("[a, b]")
    s.expect(pattern_text("[a, ..rest]")).to_equal("[a, ..rest]")
    s.expect(pattern_text("[a, .._]")).to_equal("[a, ..]")
    s.expect(pattern_text("[..rest]")).to_equal("rest")
    s.expect(pattern_text("\"pre\" <> rest")).to_equal("\"pre\" <> rest")
    s
    .expect(pattern_text("\"pre\" as p <> rest"))
    .to_equal("\"pre\" as p <> rest")
    s
    .expect(pattern_text("<<a:size(8), b:bits>>"))
    .to_equal("<<a:size(8), b:bits>>")
    s
    .expect(pattern_text("<<a:size(n + 1 * 2)>>"))
    .to_equal("<<a:size(n + 1 * 2)>>")
    s
    .expect(pattern_text("<<a:size({ n + 1 } * 2)>>"))
    .to_equal("<<a:size({ n + 1 } * 2)>>")
  })
}

///|
test "a long constructor pattern breaks its arguments; a single breakable argument breaks inside" {
  @expect.expect_all(s => {
    s
    .expect(
      pattern_text(
        "Wibble(aaaaaaaaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbbbbbbbb, cccccccccccccccccccccccccc)",
      ),
    )
    .to_equal(
      "Wibble(\n  aaaaaaaaaaaaaaaaaaaaaaaa,\n  bbbbbbbbbbbbbbbbbbbbbbbbbb,\n  cccccccccccccccccccccccccc,\n)",
    )
    s
    .expect(
      pattern_text(
        "Wibble([aaaaaaaaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbbbbbbbb, cccccccccccccccccccccccccc])",
      ),
    )
    .to_equal(
      "Wibble([\n  aaaaaaaaaaaaaaaaaaaaaaaa,\n  bbbbbbbbbbbbbbbbbbbbbbbbbb,\n  cccccccccccccccccccccccccc,\n])",
    )
  })
}
