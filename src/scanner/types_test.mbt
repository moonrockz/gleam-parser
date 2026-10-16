///|
test "keywords are the compiler's 22 words" {
  @expect.expect_all(e => {
    e.expect(@scanner.Keyword::of("fn")).to_equal(Some(@scanner.Keyword::Fn))
    e.expect(@scanner.Keyword::of("use")).to_equal(Some(@scanner.Keyword::Use))
    e
    .expect(@scanner.Keyword::of("macro"))
    .to_equal(Some(@scanner.Keyword::Macro))
    e.expect(@scanner.Keyword::of("Fn")).to_equal(None)
    e.expect(@scanner.Keyword::of("function")).to_equal(None)
    e.expect(@scanner.Keyword::Opaque.text()).to_equal("opaque")
    let words = [
      "as", "assert", "auto", "case", "const", "delegate", "derive", "echo", "else",
      "fn", "if", "implement", "import", "let", "macro", "opaque", "panic", "pub",
      "test", "todo", "type", "use",
    ]
    for w in words {
      e.expect(@scanner.Keyword::of(w).map(k => k.text())).to_equal(Some(w))
    }
  })
}

///|
test "comment spans exclude the slashes" {
  let c = @scanner.Comment::from_parts(
    kind=Doc,
    content=" hi",
    span=@span.SrcSpan::from_ints(10, 16).unwrap(),
  ).unwrap()
  @expect.expect_all(e => {
    e.expect(@scanner.CommentKind::Regular.prefix_length().to_int()).to_equal(2)
    e.expect(@scanner.CommentKind::Doc.prefix_length().to_int()).to_equal(3)
    e.expect(@scanner.CommentKind::Module.prefix_length().to_int()).to_equal(4)
    e
    .expect(c.content_span())
    .to_equal(@span.SrcSpan::from_ints(13, 16).unwrap())
    e.expect(@scanner.Trivia::Comment(c).text()).to_equal("/// hi")
    e
    .expect(@scanner.Trivia::Comment(c).span())
    .to_equal(@span.SrcSpan::from_ints(10, 16).unwrap())
    e
    .expect(
      @scanner.Trivia::Newline("\r\n", @span.SrcSpan::from_ints(0, 2).unwrap()).text(),
    )
    .to_equal("\r\n")
  })
}

///|
test "comment construction rejects spans shorter than the prefix" {
  @expect.expect_all(e => {
    for kind in [@scanner.CommentKind::Regular, Doc, Module] {
      let prefix = kind.prefix_length().to_int()
      for length in 0..<prefix {
        e
        .expect(
          @scanner.Comment::from_parts(
            kind~,
            content="",
            span=@span.SrcSpan::from_ints(0, length).unwrap(),
          ),
        )
        .to_equal(None)
      }
      e
      .expect(
        @scanner.Comment::from_parts(
          kind~,
          content="",
          span=@span.SrcSpan::eof(@span.ByteOffset::from_int(10).unwrap()),
        ),
      )
      .to_equal(None)
      for start in [0, 10, 2147483647 - prefix] {
        guard @scanner.Comment::from_parts(
            kind~,
            content="",
            span=@span.SrcSpan::from_ints(start, start + prefix).unwrap(),
          )
          is Some(comment) else {
          fail("valid empty comment was rejected")
        }
        e
        .expect(comment.content_span())
        .to_equal(
          @span.SrcSpan::from_ints(start + prefix, start + prefix).unwrap(),
        )
      }
      e
      .expect(
        @scanner.Comment::from_parts(
          kind~,
          content="",
          span=@span.SrcSpan::from_ints(2147483647, 2147483647).unwrap(),
        ),
      )
      .to_equal(None)
    }
  })
}

///|
test "a token and a stream rebuild their source" {
  let sp = (a : Int32, b : Int32) => @span.SrcSpan::from_ints(a, b).unwrap()
  let t1 = @scanner.Token::{
    kind: Keyword(Fn),
    lexeme: "fn",
    span: sp(2, 4),
    trivia_before: [@scanner.Trivia::Whitespace("  ", sp(0, 2))][:],
    trivia_after: [][:],
  }
  let t2 = @scanner.Token::{
    kind: Name("x"),
    lexeme: "x",
    span: sp(5, 6),
    trivia_before: [@scanner.Trivia::Whitespace(" ", sp(4, 5))][:],
    trivia_after: [@scanner.Trivia::Newline("\n", sp(6, 7))][:],
  }
  let stream = @scanner.TokenStream::{
    tokens: [t1, t2][:],
    trivia: [][:],
    diagnostics: [][:],
  }
  @expect.expect_all(e => {
    e.expect(t1.to_source()).to_equal("  fn")
    e.expect(stream.to_source()).to_equal("  fn x\n")
    e.expect(stream.has_errors()).to_be_false()
  })
}

///|
test "a stream with only trivia rebuilds from its trivia" {
  let stream = @scanner.TokenStream::{
    tokens: [][:],
    trivia: [
      @scanner.Trivia::Whitespace(" ", @span.SrcSpan::from_ints(0, 1).unwrap()),
    ][:],
    diagnostics: [][:],
  }
  @expect.expect(stream.to_source()).to_equal(" ")
}
