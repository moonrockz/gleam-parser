///|
test "a span contains its start and not its end" {
  let s = @span.SrcSpan::new(3, 7)
  @expect.expect_all(e => {
    e.expect(s.contains(3)).to_be_true()
    e.expect(s.contains(6)).to_be_true()
    e.expect(s.contains(7)).to_be_false()
    e.expect(s.contains(2)).to_be_false()
    e.expect(s.length()).to_equal(4)
  })
}

///|
test "an empty span contains nothing" {
  let s = @span.SrcSpan::new(5, 5)
  @expect.expect_all(e => {
    e.expect(s.contains(5)).to_be_false()
    e.expect(s.length()).to_equal(0)
  })
}

///|
test "positions compare by value" {
  @expect.expect(@span.Position::new(1, 1)).to_equal(@span.Position::{
    line: 1,
    column: 1,
  })
}
