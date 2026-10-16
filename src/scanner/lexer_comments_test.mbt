///|
fn trivia_of(text : String, index : Int32) -> Array[@scanner.Trivia] {
  let s = stream(text)
  if s.tokens.length() == 0 {
    s.trivia.to_owned()
  } else if index < s.tokens.length() {
    s.tokens[index].trivia_before.to_owned()
  } else {
    s.tokens[s.tokens.length() - 1].trivia_after.to_owned()
  }
}

///|
test "the three comment kinds, content after the slashes" {
  let text = "// a\n/// b\n//// c\nx"
  let t = trivia_of(text, 0)
  @expect.expect_all(e => {
    e.expect(kinds(text)).to_equal([Name("x")])
    e.expect(t.length()).to_equal(6)
    e
    .expect(t[0])
    .to_equal(
      @scanner.Trivia::Comment(
        @scanner.Comment::new(
          kind=Regular,
          content=" a",
          span=@span.SrcSpan::new(0, 4).unwrap(),
        ).unwrap(),
      ),
    )
    e
    .expect(t[1])
    .to_equal(@scanner.Trivia::Newline("\n", @span.SrcSpan::new(4, 5).unwrap()))
    e
    .expect(t[2])
    .to_equal(
      @scanner.Trivia::Comment(
        @scanner.Comment::new(
          kind=Doc,
          content=" b",
          span=@span.SrcSpan::new(5, 10).unwrap(),
        ).unwrap(),
      ),
    )
    e
    .expect(t[4])
    .to_equal(
      @scanner.Trivia::Comment(
        @scanner.Comment::new(
          kind=Module,
          content=" c",
          span=@span.SrcSpan::new(11, 17).unwrap(),
        ).unwrap(),
      ),
    )
    e.expect(stream(text).to_source()).to_equal(text)
  })
}

///|
test "comment content spans match the compiler (after the slashes)" {
  let t = trivia_of("/// b\n", 0)
  guard t[0] is @scanner.Trivia::Comment(c) else { fail("expected a comment") }
  @expect.expect(c.content_span()).to_equal(@span.SrcSpan::new(3, 5).unwrap())
}

///|
test "a comment ends before a CRLF; the CR is not in it" {
  let t = trivia_of("// a\r\nx", 0)
  @expect.expect_all(e => {
    e
    .expect(t[0])
    .to_equal(
      @scanner.Trivia::Comment(
        @scanner.Comment::new(
          kind=Regular,
          content=" a",
          span=@span.SrcSpan::new(0, 4).unwrap(),
        ).unwrap(),
      ),
    )
    e
    .expect(t[1])
    .to_equal(
      @scanner.Trivia::Newline("\r\n", @span.SrcSpan::new(4, 6).unwrap()),
    )
  })
}

///|
test "a comment at the end of the text and empty comments" {
  @expect.expect_all(e => {
    e
    .expect(trivia_of("x //", 1))
    .to_equal([
      @scanner.Trivia::Whitespace(" ", @span.SrcSpan::new(1, 2).unwrap()),
      @scanner.Trivia::Comment(
        @scanner.Comment::new(
          kind=Regular,
          content="",
          span=@span.SrcSpan::new(2, 4).unwrap(),
        ).unwrap(),
      ),
    ])
    e
    .expect(trivia_of("///", 0))
    .to_equal([
      @scanner.Trivia::Comment(
        @scanner.Comment::new(
          kind=Doc,
          content="",
          span=@span.SrcSpan::new(0, 3).unwrap(),
        ).unwrap(),
      ),
    ])
    e
    .expect(trivia_of("/////", 0))
    .to_equal([
      @scanner.Trivia::Comment(
        @scanner.Comment::new(
          kind=Module,
          content="/",
          span=@span.SrcSpan::new(0, 5).unwrap(),
        ).unwrap(),
      ),
    ])
    e.expect(stream("x // é\n").to_source()).to_equal("x // é\n")
  })
}

///|
test "a comment with non-ASCII content has byte spans" {
  let t = trivia_of("// é\nx", 0)
  @expect.expect(t[0].span()).to_equal(@span.SrcSpan::new(0, 5).unwrap())
}
