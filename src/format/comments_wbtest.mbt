///|
/// A text form of a popped comment, for comparisons.
fn show(c : CommentOrLine) -> String {
  match c {
    Text(s) => "T:" + s
    EmptyLine => "E"
  }
}

///|
fn fixture(text : String) -> Formatter {
  let r = @parser.parse_text(text)
  Formatter(r.extra, @scanner.SourceText(text), @config.Config::default())
}

///|
test "pop_comments returns comments and coalesced empty lines before the limit, in order" {
  // bytes: "// a\n" 0..5, "\n" 5, "\n" 6, "// b\n" 7..12, "c" at 12
  let f = fixture("// a\n\n\n// b\nconst x = 1\n")
  let popped = f.pop_comments_with_position(
    @span.ByteOffset::from_int(13).unwrap(),
  )
  @expect.expect_all(s => {
    s.expect(popped.length()).to_equal(3)
    s
    .expect((popped[0].0, show(popped[0].1)))
    .to_equal((@span.ByteOffset::from_int(2).unwrap(), "T: a"))
    s
    .expect((popped[1].0, show(popped[1].1)))
    .to_equal((@span.ByteOffset::from_int(5).unwrap(), "E"))
    s
    .expect((popped[2].0, show(popped[2].1)))
    .to_equal((@span.ByteOffset::from_int(9).unwrap(), "T: b"))
    // Nothing is left before the limit; the cursor moved.
    s
    .expect(f.any_comments(@span.ByteOffset::from_int(13).unwrap()))
    .to_equal(false)
    s
    .expect(f.any_empty_lines(@span.ByteOffset::from_int(13).unwrap()))
    .to_equal(false)
  })
}

///|
test "leading empty lines are dropped and doc comments drop every empty line" {
  let f = fixture("\n\n// a\n\n/// d\n\n/// e\nconst x = 1\n")
  @expect.expect_all(s => {
    let comments = f.pop_comments(@span.ByteOffset::from_int(100).unwrap())
    // The empty lines after `// a` are popped too (one per gap, as the
    // compiler coalesces only consecutive ones).
    s.expect(comments.map(show)).to_equal(["T: a", "E", "E"])
    let docs = f.pop_doc_comments(@span.ByteOffset::from_int(100).unwrap())
    s.expect(docs).to_equal([" d", " e"])
    s
    .expect(f.any_empty_lines(@span.ByteOffset::from_int(100).unwrap()))
    .to_equal(false)
  })
}

///|
test "pop_empty_lines, spans_multiple_lines and has_trailing_comma" {
  let f = fixture("const x = [\n  1,\n\n  2,\n]\n")
  @expect.expect_all(s => {
    s
    .expect(f.pop_empty_lines(@span.ByteOffset::from_int(30).unwrap()))
    .to_equal(true)
    s
    .expect(f.pop_empty_lines(@span.ByteOffset::from_int(30).unwrap()))
    .to_equal(false)
    s
    .expect(
      f.spans_multiple_lines(
        @span.ByteOffset::from_int(10).unwrap(),
        @span.ByteOffset::from_int(15).unwrap(),
      ),
    )
    .to_equal(true)
    s
    .expect(
      f.spans_multiple_lines(
        @span.ByteOffset::from_int(14).unwrap(),
        @span.ByteOffset::from_int(15).unwrap(),
      ),
    )
    .to_equal(false)
    // the comma after `2` is a trailing comma of the list
    s
    .expect(
      f.has_trailing_comma(
        @span.ByteOffset::from_int(20).unwrap(),
        @span.ByteOffset::from_int(24).unwrap(),
      ),
    )
    .to_equal(true)
    s
    .expect(
      f.has_trailing_comma(
        @span.ByteOffset::from_int(0).unwrap(),
        @span.ByteOffset::from_int(9).unwrap(),
      ),
    )
    .to_equal(false)
  })
}

///|
test "printed_comments joins comments with line feeds and keeps one empty line" {
  @expect.expect_all(s => {
    s
    .expect(
      printed_comments([Text(" a"), Text(" b")][:], true).map(d => {
        @pretty.render(d, start=Unbroken)
      }),
    )
    .to_equal(Some("// a\n// b\n"))
    s
    .expect(
      printed_comments([Text(" a"), EmptyLine, Text(" b")][:], false).map(d => {
        @pretty.render(d, start=Unbroken)
      }),
    )
    .to_equal(Some("// a\n\n// b"))
    s.expect(printed_comments([][:], true) is None).to_equal(true)
  })
}
