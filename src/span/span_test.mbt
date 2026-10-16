///|
test "a span contains its start and not its end" {
  let s = @span.SrcSpan::from_ints(3, 7).unwrap()
  @expect.expect_all(e => {
    e.expect(s.contains(@span.ByteOffset::from_int(3).unwrap())).to_be_true()
    e.expect(s.contains(@span.ByteOffset::from_int(6).unwrap())).to_be_true()
    e.expect(s.contains(@span.ByteOffset::from_int(7).unwrap())).to_be_false()
    e.expect(s.contains(@span.ByteOffset::from_int(2).unwrap())).to_be_false()
    e.expect(s.length().unwrap().to_int()).to_equal(4)
  })
}

///|
test "an empty span contains nothing" {
  let s = @span.SrcSpan::from_ints(5, 5).unwrap()
  @expect.expect_all(e => {
    e.expect(s.contains(@span.ByteOffset::from_int(5).unwrap())).to_be_false()
    e.expect(s.length().unwrap().to_int()).to_equal(0)
  })
}

///|
test "positions compare by value" {
  @expect.expect(@span.Position::from_ints(1, 1)).to_equal(
    Some(
      @span.Position::at(
        @span.LineNumber::from_int(1).unwrap(),
        @span.ColumnNumber::from_int(1).unwrap(),
      ),
    ),
  )
}
