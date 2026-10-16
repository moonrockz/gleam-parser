///|
test "trivia_extra agrees with the oracle on comments_only" {
  let text = "//// Module docs line one.\n//// Line two.\n\n// A regular comment.\n\n/// A detached doc comment.\n"
  let extra = @cst.trivia_extra(@scanner.tokenize_text(text))
  @expect.expect_all(e => {
    e
    .expect(extra.module_comments)
    .to_equal([
      @span.SrcSpan::from_ints(4, 26).unwrap(),
      @span.SrcSpan::from_ints(31, 41).unwrap(),
    ])
    e
    .expect(extra.comments)
    .to_equal([@span.SrcSpan::from_ints(45, 64).unwrap()])
    e
    .expect(extra.doc_comments)
    .to_equal([@span.SrcSpan::from_ints(69, 93).unwrap()])
    e
    .expect(extra.new_lines.iter().map(x => x.to_int()).collect())
    .to_equal([26, 41, 42, 64, 65, 93])
    e
    .expect(extra.empty_lines.iter().map(x => x.to_int()).collect())
    .to_equal([42, 65])
    e.expect(extra.trailing_commas.length()).to_equal(0)
  })
}

///|
test "empty lines reset at a comment and at a token" {
  // `\n\n` after a token: one empty line at previous + 1; a comment between
  // two line ends is not an empty line; whitespace between them is.
  let extra = @cst.trivia_extra(@scanner.tokenize_text("a\n\n// c\n\nb\n  \n"))
  @expect.expect_all(e => {
    e
    .expect(extra.new_lines.iter().map(x => x.to_int()).collect())
    .to_equal([1, 2, 7, 8, 10, 13])
    e
    .expect(extra.empty_lines.iter().map(x => x.to_int()).collect())
    .to_equal([2, 8, 11])
  })
}

///|
test "CRLF line ends count at the carriage return" {
  let extra = @cst.trivia_extra(@scanner.tokenize_text("a\r\n\r\nb"))
  @expect.expect_all(e => {
    e
    .expect(extra.new_lines.iter().map(x => x.to_int()).collect())
    .to_equal([1, 3])
    e
    .expect(extra.empty_lines.iter().map(x => x.to_int()).collect())
    .to_equal([2])
  })
}
