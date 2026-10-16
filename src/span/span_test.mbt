///|
test "a span contains its start and not its end" {
  let s = @span.SrcSpan::new(3, 7).unwrap()
  @expect.expect_all(e => {
    e.expect(s.contains(@span.ByteOffset::new(3).unwrap())).to_be_true()
    e.expect(s.contains(@span.ByteOffset::new(6).unwrap())).to_be_true()
    e.expect(s.contains(@span.ByteOffset::new(7).unwrap())).to_be_false()
    e.expect(s.contains(@span.ByteOffset::new(2).unwrap())).to_be_false()
    e.expect(s.length().unwrap().to_int()).to_equal(4)
  })
}

///|
test "an empty span contains nothing" {
  let s = @span.SrcSpan::new(5, 5).unwrap()
  @expect.expect_all(e => {
    e.expect(s.contains(@span.ByteOffset::new(5).unwrap())).to_be_false()
    e.expect(s.length().unwrap().to_int()).to_equal(0)
  })
}

///|
test "positions compare by value" {
  @expect.expect(@span.Position::new(1, 1)).to_equal(
    Some(
      @span.Position(
        @span.LineNumber::new(1).unwrap(),
        @span.ColumnNumber::new(1).unwrap(),
      ),
    ),
  )
}
