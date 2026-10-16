///|
test "the cursor reads code points and reports byte positions" {
  let c = Cursor::new("aé𝄞")
  @expect.expect_all(e => {
    e.expect(c.peek()).to_equal(Some('a'))
    e.expect(c.peek1()).to_equal(Some('é'))
    e.expect(c.position()).to_equal(@span.ByteOffset::new(0).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::new(1).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::new(3).unwrap())
    e.expect(c.unit()).to_equal(@span.Utf16Offset::new(2).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::new(7).unwrap())
    e.expect(c.unit()).to_equal(@span.Utf16Offset::new(4).unwrap())
    e.expect(c.peek()).to_equal(None)
    e.expect(c.at_end()).to_be_true()
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::new(7).unwrap())
  })
}

///|
test "CRLF and a lone CR read as a line feed at the CR" {
  let c = Cursor::new("a\r\nb\rc")
  @expect.expect_all(e => {
    c.advance()
    e.expect(c.peek()).to_equal(Some('\n'))
    e.expect(c.peek1()).to_equal(Some('b'))
    e.expect(c.position()).to_equal(@span.ByteOffset::new(1).unwrap())
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::new(3).unwrap())
    e.expect(c.peek()).to_equal(Some('b'))
    c.advance()
    e.expect(c.peek()).to_equal(Some('\n'))
    e.expect(c.peek1()).to_equal(Some('c'))
    c.advance()
    e.expect(c.position()).to_equal(@span.ByteOffset::new(5).unwrap())
    e.expect(c.slice(@span.Utf16Offset::new(0).unwrap())).to_equal("a\r\nb\r")
  })
}

///|
test "a lone surrogate is one code point of three bytes" {
  let c = Cursor::new(@lawkit.units([0xD800, 0x61]))
  c.advance()
  @expect.expect_all(e => {
    e.expect(c.position()).to_equal(@span.ByteOffset::new(3).unwrap())
    e.expect(c.peek()).to_equal(Some('a'))
  })
}
