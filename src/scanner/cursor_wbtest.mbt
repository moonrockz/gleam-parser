///|
test "the cursor reads code points and reports byte positions" {
  let c = Cursor("aé𝄞")
  @expect.expect_all(e => {
    e.expect(c.peek()).to_equal(Some('a'))
    e.expect(c.peek1()).to_equal(Some('é'))
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(0).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(1).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(3).unwrap())
    e.expect(c.unit()).to_equal(@span.Utf16Offset::from_int(2).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(7).unwrap())
    e.expect(c.unit()).to_equal(@span.Utf16Offset::from_int(4).unwrap())
    e.expect(c.peek()).to_equal(None)
    e.expect(c.at_end()).to_be_true()
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(7).unwrap())
  })
}

///|
test "CRLF and a lone CR read as a line feed at the CR" {
  let c = Cursor("a\r\nb\rc")
  @expect.expect_all(e => {
    c.advance()
    e.expect(c.peek()).to_equal(Some('\n'))
    e.expect(c.peek1()).to_equal(Some('b'))
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(1).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(3).unwrap())
    e.expect(c.peek()).to_equal(Some('b'))
    c.advance()
    e.expect(c.peek()).to_equal(Some('\n'))
    e.expect(c.peek1()).to_equal(Some('c'))
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(5).unwrap())
    e
    .expect(c.slice(@span.Utf16Offset::from_int(0).unwrap()))
    .to_equal("a\r\nb\r")
  })
}

///|
test "a lone surrogate is one code point of three bytes" {
  let c = Cursor(@lawkit.units([0xD800, 0x61]))
  c.advance()
  @expect.expect_all(e => {
    e.expect(c.position()).to_equal(@span.ByteOffset::from_int(3).unwrap())
    e.expect(c.peek()).to_equal(Some('a'))
  })
}
