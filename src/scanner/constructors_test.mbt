///|
test "comment constructor reports short spans and EOF locations" {
  let short = @span.SrcSpan(0, 1)
  let eof = @span.SrcSpan::eof(@span.ByteOffset(3))
  let errors = []
  for span in [short, eof] {
    ignore(@scanner.Comment::Comment(kind=Regular, content="", span~)) catch {
      error => errors.push(error)
    }
  }
  let span = @span.SrcSpan(0, 2)
  let comment = @scanner.Comment::Comment(kind=Regular, content="", span~)
  @expect.expect_all(e => {
    e
    .expect(errors)
    .to_equal([
      @scanner.CommentPrefixTooShort(kind=Regular, span=short),
      @scanner.CommentAtEof(eof),
    ])
    e
    .expect(@scanner.Comment::from_parts(kind=Regular, content="", span~))
    .to_equal(Some(comment))
  })
}
