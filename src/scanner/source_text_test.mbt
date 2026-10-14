///|
fn pos(line : Int32, column : Int32) -> @span.Position? {
  Some(@span.Position::new(line, column))
}

///|
test "ASCII text: bytes equal units, lines split at LF" {
  let st = @scanner.SourceText::new("ab\ncd")
  @expect.expect_all(e => {
    e.expect(st.byte_length()).to_equal(5)
    e.expect(st.line_count()).to_equal(2)
    e.expect(st.byte_offset_of(3)).to_equal(Some(3))
    e.expect(st.utf16_offset_of(3)).to_equal(Some(3))
    e.expect(st.position_of(0)).to_equal(pos(1, 1))
    e.expect(st.position_of(2)).to_equal(pos(1, 3))
    e.expect(st.position_of(3)).to_equal(pos(2, 1))
    e.expect(st.position_of(5)).to_equal(pos(2, 3))
    e.expect(st.position_of(6)).to_equal(None)
    e.expect(st.byte_offset_of(6)).to_equal(None)
    e.expect(st.utf16_offset_of(-1)).to_equal(None)
  })
}

///|
test "the empty text has one line and position 1:1 at offset 0" {
  let st = @scanner.SourceText::new("")
  @expect.expect_all(e => {
    e.expect(st.byte_length()).to_equal(0)
    e.expect(st.line_count()).to_equal(1)
    e.expect(st.position_of(0)).to_equal(pos(1, 1))
    e.expect(st.utf16_offset_of(0)).to_equal(Some(0))
    e.expect(st.byte_offset_of(0)).to_equal(Some(0))
  })
}

///|
test "two-byte character: é is one column and two bytes" {
  let st = @scanner.SourceText::new("é!")
  @expect.expect_all(e => {
    e.expect(st.byte_length()).to_equal(3)
    e.expect(st.byte_offset_of(1)).to_equal(Some(2))
    e.expect(st.utf16_offset_of(2)).to_equal(Some(1))
    e.expect(st.utf16_offset_of(1)).to_equal(None)
    e.expect(st.position_of(1)).to_equal(None)
    e.expect(st.position_of(2)).to_equal(pos(1, 2))
  })
}

///|
test "surrogate pair: one column, four bytes, no boundary at the low unit" {
  let st = @scanner.SourceText::new("𝄞x")
  @expect.expect_all(e => {
    e.expect(st.text().length()).to_equal(3)
    e.expect(st.byte_length()).to_equal(5)
    e.expect(st.byte_offset_of(0)).to_equal(Some(0))
    e.expect(st.byte_offset_of(1)).to_equal(None)
    e.expect(st.byte_offset_of(2)).to_equal(Some(4))
    e.expect(st.utf16_offset_of(4)).to_equal(Some(2))
    e.expect(st.position_of(4)).to_equal(pos(1, 2))
  })
}

///|
test "lone surrogate: one column, three bytes" {
  let st = @scanner.SourceText::new(@lawkit.units([0xD800, 0x61]))
  @expect.expect_all(e => {
    e.expect(st.byte_length()).to_equal(4)
    e.expect(st.byte_offset_of(1)).to_equal(Some(3))
    e.expect(st.position_of(3)).to_equal(pos(1, 2))
  })
}

///|
test "CRLF is one line break; the line starts after the LF" {
  let st = @scanner.SourceText::new("a\r\nb")
  @expect.expect_all(e => {
    e.expect(st.line_count()).to_equal(2)
    e.expect(st.position_of(1)).to_equal(pos(1, 2))
    e.expect(st.position_of(2)).to_equal(pos(1, 3))
    e.expect(st.position_of(3)).to_equal(pos(2, 1))
  })
}

///|
test "a lone CR is a line break" {
  let st = @scanner.SourceText::new("a\rb")
  @expect.expect_all(e => {
    e.expect(st.line_count()).to_equal(2)
    e.expect(st.position_of(2)).to_equal(pos(2, 1))
  })
}

///|
test "a BOM is column 1 and three bytes" {
  let st = @scanner.SourceText::new("\u{FEFF}x")
  @expect.expect_all(e => {
    e.expect(st.byte_length()).to_equal(4)
    e.expect(st.position_of(0)).to_equal(pos(1, 1))
    e.expect(st.position_of(3)).to_equal(pos(1, 2))
  })
}

///|
test "a text that ends with a line break has an empty last line" {
  let st = @scanner.SourceText::new("a\n")
  @expect.expect_all(e => {
    e.expect(st.line_count()).to_equal(2)
    e.expect(st.position_of(2)).to_equal(pos(2, 1))
  })
}

///|
test "slice gives the text of a byte span" {
  let st = @scanner.SourceText::new("let é = \"𝄞\"\nx")
  @expect.expect_all(e => {
    e.expect(st.slice(@span.SrcSpan::new(0, 3))).to_equal(Some("let"))
    e.expect(st.slice(@span.SrcSpan::new(4, 6))).to_equal(Some("é"))
    e.expect(st.slice(@span.SrcSpan::new(9, 15))).to_equal(Some("\"𝄞\""))
    e.expect(st.slice(@span.SrcSpan::new(4, 5))).to_equal(None)
    e.expect(st.slice(@span.SrcSpan::new(16, 17))).to_equal(Some("x"))
    e.expect(st.slice(@span.SrcSpan::new(17, 17))).to_equal(Some(""))
    e.expect(st.slice(@span.SrcSpan::new(17, 18))).to_equal(None)
  })
}
