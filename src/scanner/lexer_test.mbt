///|
fn stream(text : String) -> @scanner.TokenStream {
  @scanner.tokenize(@scanner.SourceText::new(text))
}

///|
fn kinds(text : String) -> Array[@scanner.TokenKind] {
  stream(text).tokens.iter().map(t => t.kind).collect()
}

///|
/// Kind, lexeme, start and end byte of every token.
fn dump(text : String) -> Array[(@scanner.TokenKind, String, Int32, Int32)] {
  stream(text).tokens
  .iter()
  .map(t => (t.kind, t.lexeme, t.span.start, t.span.end))
  .collect()
}

///|
fn error_kinds(text : String) -> Array[String] {
  stream(text).diagnostics.iter().map(d => d.kind).collect()
}

///|
test "single-character tokens" {
  @expect.expect(kinds("@()[]{}:,#")).to_equal([
    At,
    LeftParen,
    RightParen,
    LeftSquare,
    RightSquare,
    LeftBrace,
    RightBrace,
    Colon,
    Comma,
    Hash,
  ])
}

///|
test "operators with and without dots" {
  @expect.expect_all(e => {
    e
    .expect(kinds("+ +. - -. * *. / /. %"))
    .to_equal([
      Plus,
      PlusDot,
      Minus,
      MinusDot,
      Star,
      StarDot,
      Slash,
      SlashDot,
      Percent,
    ])
    e
    .expect(kinds("< <. <= <=. > >. >= >=. <> <- ->"))
    .to_equal([
      Less,
      LessDot,
      LessEqual,
      LessEqualDot,
      Greater,
      GreaterDot,
      GreaterEqual,
      GreaterEqualDot,
      Concatenate,
      LArrow,
      RArrow,
    ])
    e
    .expect(kinds("| || |> && ! != = == . .."))
    .to_equal([
      Vbar,
      VbarVbar,
      Pipe,
      AmperAmper,
      Bang,
      NotEqual,
      Equal,
      EqualEqual,
      Dot,
      DotDot,
    ])
    e
    .expect(kinds("<< >> <<< >>>"))
    .to_equal([LtLt, GtGt, LtLt, Less, GtGt, Greater])
  })
}

///|
test "spans are byte offsets and lexemes are the source" {
  debug_inspect(
    dump("<=. ->"),
    content=(
      #|[(LessEqualDot, "<=.", 0, 3), (RArrow, "->", 4, 6)]
    ),
  )
}

///|
test "runs of equals signs split into == and =" {
  @expect.expect_all(e => {
    e.expect(kinds("====")).to_equal([EqualEqual, EqualEqual])
    e.expect(kinds("=====")).to_equal([EqualEqual, EqualEqual, Equal])
    e.expect(kinds("======")).to_equal([EqualEqual, EqualEqual, EqualEqual])
    e.expect(dump("=====")[2]).to_equal((Equal, "=", 4, 5))
  })
}

///|
test "=== is an error that covers the three characters" {
  let s = stream("a === b")
  @expect.expect_all(e => {
    e.expect(error_kinds("a === b")).to_equal(["InvalidTripleEqual"])
    e.expect(s.diagnostics[0].span).to_equal(@span.SrcSpan::new(2, 5))
    e.expect(kinds("a === b")).to_equal([Name("a"), Error, Name("b")])
    e.expect(s.tokens[1].lexeme).to_equal("===")
    e.expect(s.to_source()).to_equal("a === b")
  })
}

///|
test "seven or more markers are a merge conflict" {
  @expect.expect_all(e => {
    e.expect(error_kinds("=======")).to_equal(["MergeConflictIndicator"])
    e.expect(error_kinds("<<<<<<<")).to_equal(["MergeConflictIndicator"])
    e.expect(error_kinds(">>>>>>>")).to_equal(["MergeConflictIndicator"])
    e
    .expect(stream("=======").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(0, 7))
    e.expect(kinds("=======")).to_equal([Error])
    e.expect(stream("=======").to_source()).to_equal("=======")
  })
}

///|
test "procedural operators are errors" {
  @expect.expect_all(e => {
    for op in ["+=", "++", "-=", "*=", "/=", "%="] {
      e.expect(error_kinds(op)).to_equal(["UnsupportedProceduralOperator"])
      e.expect(kinds(op)).to_equal([Error])
      e
      .expect(stream(op).diagnostics[0].span)
      .to_equal(@span.SrcSpan::new(0, 2))
    }
  })
}

///|
test "a lone ampersand and unknown characters are unrecognized tokens" {
  @expect.expect_all(e => {
    e.expect(error_kinds("&")).to_equal(["UnrecognizedToken"])
    e.expect(stream("&").diagnostics[0].span).to_equal(@span.SrcSpan::new(0, 0))
    e.expect(stream("&").tokens[0].lexeme).to_equal("&")
    e.expect(error_kinds("a;b")).to_equal(["UnrecognizedToken"])
    e
    .expect(stream("a;b").diagnostics[0].message)
    .to_equal("Remove this semicolon")
    e
    .expect(stream("a;b").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(1, 1))
    e.expect(kinds("a;b")).to_equal([Name("a"), Error, Name("b")])
    e.expect(kinds("é")).to_equal([Error])
    e.expect(stream("é").to_source()).to_equal("é")
  })
}

///|
test "visually similar characters name the ascii character" {
  let s = stream("a\u{00A0}b")
  @expect.expect_all(e => {
    e
    .expect(error_kinds("a\u{00A0}b"))
    .to_equal(["VisuallySimilarInvalidCharacter"])
    e
    .expect(s.diagnostics[0].hint)
    .to_equal(
      Some(
        "This looks like ascii space, but it is actually the unicode non-breaking\nspace.",
      ),
    )
    e.expect(s.diagnostics[0].span).to_equal(@span.SrcSpan::new(1, 1))
    e.expect(kinds("a\u{00A0}b")).to_equal([Name("a"), Error, Name("b")])
    e
    .expect(error_kinds("\u{201C}"))
    .to_equal(["VisuallySimilarInvalidCharacter"])
    e
    .expect(stream("\u{FF08}").diagnostics[0].hint)
    .to_equal(
      Some(
        "This looks like ascii left parenthesis, but it is actually the unicode\nfullwidth left parenthesis.",
      ),
    )
  })
}

///|
test "whitespace and line breaks are trivia on the next token" {
  let s = stream("  \t(\n\r\n)\u{0C}")
  @expect.expect_all(e => {
    e.expect(kinds("  \t(\n\r\n)\u{0C}")).to_equal([LeftParen, RightParen])
    e
    .expect(s.tokens[0].trivia_before)
    .to_equal([@scanner.Trivia::Whitespace("  \t", @span.SrcSpan::new(0, 3))])
    e
    .expect(s.tokens[1].trivia_before)
    .to_equal([
      @scanner.Trivia::Newline("\n", @span.SrcSpan::new(4, 5)),
      @scanner.Trivia::Newline("\r\n", @span.SrcSpan::new(5, 7)),
    ])
    e
    .expect(s.tokens[1].trivia_after)
    .to_equal([@scanner.Trivia::Whitespace("\u{0C}", @span.SrcSpan::new(8, 9))])
    e.expect(s.to_source()).to_equal("  \t(\n\r\n)\u{0C}")
  })
}

///|
test "a text with no tokens keeps its trivia on the stream" {
  let s = stream(" \n")
  @expect.expect_all(e => {
    e.expect(s.tokens.length()).to_equal(0)
    e.expect(s.trivia.length()).to_equal(2)
    e.expect(s.to_source()).to_equal(" \n")
    e.expect(stream("").to_source()).to_equal("")
    e.expect(stream("").tokens.length()).to_equal(0)
  })
}

///|
test "a byte order mark is whitespace" {
  let s = stream("\u{FEFF}(")
  @expect.expect_all(e => {
    e.expect(kinds("\u{FEFF}(")).to_equal([LeftParen])
    e
    .expect(s.tokens[0].trivia_before)
    .to_equal([
      @scanner.Trivia::Whitespace("\u{FEFF}", @span.SrcSpan::new(0, 3)),
    ])
    e.expect(s.tokens[0].span).to_equal(@span.SrcSpan::new(3, 4))
  })
}

///|
test "a byte order mark after the start is an unrecognized token" {
  let s = stream("a\u{FEFF}b")
  @expect.expect_all(e => {
    e.expect(error_kinds("a\u{FEFF}b")).to_equal(["UnrecognizedToken"])
    e.expect(s.diagnostics[0].span).to_equal(@span.SrcSpan::new(1, 1))
    e.expect(kinds("a\u{FEFF}b")).to_equal([Name("a"), Error, Name("b")])
    e.expect(s.to_source()).to_equal("a\u{FEFF}b")
  })
}
