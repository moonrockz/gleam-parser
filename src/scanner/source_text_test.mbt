///|
fn pos(line : Int32, column : Int32) -> @span.Position? {
  Some(@span.Position::new(line, column).unwrap())
}

///|
test "ASCII text: bytes equal units, lines split at LF" {
  let st = @scanner.SourceText::new("ab\ncd")
  @expect.expect_all(e => {
    e.expect(st.byte_length().to_int()).to_equal(5)
    e.expect(st.line_count().to_int()).to_equal(2)
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(3).unwrap()))
    .to_equal(Some(@span.ByteOffset::new(3).unwrap()))
    e
    .expect(st.utf16_offset_of(@span.ByteOffset::new(3).unwrap()))
    .to_equal(Some(@span.Utf16Offset::new(3).unwrap()))
    e
    .expect(st.position_of(@span.ByteOffset::new(0).unwrap()))
    .to_equal(pos(1, 1))
    e
    .expect(st.position_of(@span.ByteOffset::new(2).unwrap()))
    .to_equal(pos(1, 3))
    e
    .expect(st.position_of(@span.ByteOffset::new(3).unwrap()))
    .to_equal(pos(2, 1))
    e
    .expect(st.position_of(@span.ByteOffset::new(5).unwrap()))
    .to_equal(pos(2, 3))
    e.expect(st.position_of(@span.ByteOffset::new(6).unwrap())).to_equal(None)
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(6).unwrap()))
    .to_equal(None)
    e
    .expect(@span.ByteOffset::new(-1).bind(x => st.utf16_offset_of(x)))
    .to_equal(None)
  })
}

///|
test "the empty text has one line and position 1:1 at offset 0" {
  let st = @scanner.SourceText::new("")
  @expect.expect_all(e => {
    e.expect(st.byte_length().to_int()).to_equal(0)
    e.expect(st.line_count().to_int()).to_equal(1)
    e
    .expect(st.position_of(@span.ByteOffset::new(0).unwrap()))
    .to_equal(pos(1, 1))
    e
    .expect(st.utf16_offset_of(@span.ByteOffset::new(0).unwrap()))
    .to_equal(Some(@span.Utf16Offset::new(0).unwrap()))
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(0).unwrap()))
    .to_equal(Some(@span.ByteOffset::new(0).unwrap()))
  })
}

///|
test "two-byte character: é is one column and two bytes" {
  let st = @scanner.SourceText::new("é!")
  @expect.expect_all(e => {
    e.expect(st.byte_length().to_int()).to_equal(3)
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(1).unwrap()))
    .to_equal(Some(@span.ByteOffset::new(2).unwrap()))
    e
    .expect(st.utf16_offset_of(@span.ByteOffset::new(2).unwrap()))
    .to_equal(Some(@span.Utf16Offset::new(1).unwrap()))
    e
    .expect(st.utf16_offset_of(@span.ByteOffset::new(1).unwrap()))
    .to_equal(None)
    e.expect(st.position_of(@span.ByteOffset::new(1).unwrap())).to_equal(None)
    e
    .expect(st.position_of(@span.ByteOffset::new(2).unwrap()))
    .to_equal(pos(1, 2))
  })
}

///|
test "surrogate pair: one column, four bytes, no boundary at the low unit" {
  let st = @scanner.SourceText::new("𝄞x")
  @expect.expect_all(e => {
    e.expect(st.text().length()).to_equal(3)
    e.expect(st.byte_length().to_int()).to_equal(5)
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(0).unwrap()))
    .to_equal(Some(@span.ByteOffset::new(0).unwrap()))
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(1).unwrap()))
    .to_equal(None)
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(2).unwrap()))
    .to_equal(Some(@span.ByteOffset::new(4).unwrap()))
    e
    .expect(st.utf16_offset_of(@span.ByteOffset::new(4).unwrap()))
    .to_equal(Some(@span.Utf16Offset::new(2).unwrap()))
    e
    .expect(st.position_of(@span.ByteOffset::new(4).unwrap()))
    .to_equal(pos(1, 2))
  })
}

///|
test "lone surrogate: one column, three bytes" {
  let st = @scanner.SourceText::new(@lawkit.units([0xD800, 0x61]))
  @expect.expect_all(e => {
    e.expect(st.byte_length().to_int()).to_equal(4)
    e
    .expect(st.byte_offset_of(@span.Utf16Offset::new(1).unwrap()))
    .to_equal(Some(@span.ByteOffset::new(3).unwrap()))
    e
    .expect(st.position_of(@span.ByteOffset::new(3).unwrap()))
    .to_equal(pos(1, 2))
  })
}

///|
test "CRLF is one line break; the line starts after the LF" {
  let st = @scanner.SourceText::new("a\r\nb")
  @expect.expect_all(e => {
    e.expect(st.line_count().to_int()).to_equal(2)
    e
    .expect(st.position_of(@span.ByteOffset::new(1).unwrap()))
    .to_equal(pos(1, 2))
    e
    .expect(st.position_of(@span.ByteOffset::new(2).unwrap()))
    .to_equal(pos(1, 3))
    e
    .expect(st.position_of(@span.ByteOffset::new(3).unwrap()))
    .to_equal(pos(2, 1))
  })
}

///|
test "a lone CR is a line break" {
  let st = @scanner.SourceText::new("a\rb")
  @expect.expect_all(e => {
    e.expect(st.line_count().to_int()).to_equal(2)
    e
    .expect(st.position_of(@span.ByteOffset::new(2).unwrap()))
    .to_equal(pos(2, 1))
  })
}

///|
test "a BOM is column 1 and three bytes" {
  let st = @scanner.SourceText::new("\u{FEFF}x")
  @expect.expect_all(e => {
    e.expect(st.byte_length().to_int()).to_equal(4)
    e
    .expect(st.position_of(@span.ByteOffset::new(0).unwrap()))
    .to_equal(pos(1, 1))
    e
    .expect(st.position_of(@span.ByteOffset::new(3).unwrap()))
    .to_equal(pos(1, 2))
  })
}

///|
test "a text that ends with a line break has an empty last line" {
  let st = @scanner.SourceText::new("a\n")
  @expect.expect_all(e => {
    e.expect(st.line_count().to_int()).to_equal(2)
    e
    .expect(st.position_of(@span.ByteOffset::new(2).unwrap()))
    .to_equal(pos(2, 1))
  })
}

///|
test "slice gives the text of a byte span" {
  let st = @scanner.SourceText::new("let é = \"𝄞\"\nx")
  @expect.expect_all(e => {
    e.expect(st.slice(@span.SrcSpan::new(0, 3).unwrap())).to_equal(Some("let"))
    e.expect(st.slice(@span.SrcSpan::new(4, 6).unwrap())).to_equal(Some("é"))
    e
    .expect(st.slice(@span.SrcSpan::new(9, 15).unwrap()))
    .to_equal(Some("\"𝄞\""))
    e.expect(st.slice(@span.SrcSpan::new(4, 5).unwrap())).to_equal(None)
    e.expect(st.slice(@span.SrcSpan::new(16, 17).unwrap())).to_equal(Some("x"))
    e.expect(st.slice(@span.SrcSpan::new(17, 17).unwrap())).to_equal(Some(""))
    e.expect(st.slice(@span.SrcSpan::new(17, 18).unwrap())).to_equal(None)
  })
}
