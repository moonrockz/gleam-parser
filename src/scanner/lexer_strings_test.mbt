///|
test "string literals keep escapes as written" {
  @expect.expect_all(e => {
    e.expect(kinds("\"hi\"")).to_equal([String("hi")])
    e.expect(dump("\"hi\"")).to_equal([(String("hi"), "\"hi\"", 0, 4)])
    e.expect(kinds("\"a\\\"b\"")).to_equal([String("a\\\"b")])
    e
    .expect(kinds("\"\\n\\t\\r\\f\\\\\""))
    .to_equal([String("\\n\\t\\r\\f\\\\")])
    e.expect(kinds("\"\\u{1F600}\"")).to_equal([String("\\u{1F600}")])
    e.expect(kinds("\"\"")).to_equal([String("")])
    e.expect(kinds("\"é𝄞\"")).to_equal([String("é𝄞")])
    e.expect(dump("\"é𝄞\"")[0].3).to_equal(8)
  })
}

///|
test "a string may span lines; CRLF in it reads as LF in the value only" {
  let s = stream("\"a\r\nb\rc\"")
  @expect.expect_all(e => {
    e.expect(s.tokens[0].kind).to_equal(String("a\nb\nc"))
    e.expect(s.tokens[0].lexeme).to_equal("\"a\r\nb\rc\"")
    e.expect(s.tokens[0].span).to_equal(@span.SrcSpan::new(0, 8))
    e.expect(s.to_source()).to_equal("\"a\r\nb\rc\"")
  })
}

///|
test "a string left open is one error to the end of the text" {
  let s = stream("x = \"abc\ny")
  @expect.expect_all(e => {
    e.expect(error_kinds("x = \"abc\ny")).to_equal(["UnexpectedStringEnd"])
    e.expect(s.diagnostics[0].span).to_equal(@span.SrcSpan::new(4, 4))
    e.expect(kinds("x = \"abc\ny")).to_equal([Name("x"), Equal, Error])
    e.expect(s.tokens[2].lexeme).to_equal("\"abc\ny")
    e.expect(s.to_source()).to_equal("x = \"abc\ny")
  })
}

///|
test "bad escapes" {
  @expect.expect_all(e => {
    e.expect(error_kinds("\"\\q\" x")).to_equal(["BadStringEscape"])
    e
    .expect(stream("\"\\q\" x").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(1, 2))
    e.expect(kinds("\"\\q\" x")).to_equal([Error, Name("x")])
    e.expect(stream("\"\\q\" x").tokens[0].lexeme).to_equal("\"\\q\"")
    e.expect(error_kinds("\"\\")).to_equal(["BadStringEscape"])
    e
    .expect(stream("\"\\").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(1, 1))
    e.expect(stream("\"\\").to_source()).to_equal("\"\\")
  })
}

///|
test "unicode escape errors" {
  @expect.expect_all(e => {
    e
    .expect(error_kinds("\"\\u1F600\""))
    .to_equal(["InvalidUnicodeEscape.MissingOpeningBrace"])
    e
    .expect(stream("\"\\u1F600\"").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(2, 3))
    e
    .expect(error_kinds("\"\\u{1G}\""))
    .to_equal(["InvalidUnicodeEscape.ExpectedHexDigitOrCloseBrace"])
    e
    .expect(stream("\"\\u{1G}\"").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(5, 6))
    e
    .expect(error_kinds("\"\\u{1"))
    .to_equal(["InvalidUnicodeEscape.ExpectedHexDigitOrCloseBrace"])
    e
    .expect(error_kinds("\"\\u{}\""))
    .to_equal(["InvalidUnicodeEscape.InvalidNumberOfHexDigits"])
    e
    .expect(stream("\"\\u{}\"").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(1, 5))
    e
    .expect(error_kinds("\"\\u{1234567}\""))
    .to_equal(["InvalidUnicodeEscape.InvalidNumberOfHexDigits"])
    e
    .expect(error_kinds("\"\\u{D800}\""))
    .to_equal(["InvalidUnicodeEscape.InvalidCodepoint"])
    e
    .expect(error_kinds("\"\\u{110000}\""))
    .to_equal(["InvalidUnicodeEscape.InvalidCodepoint"])
    e
    .expect(stream("\"\\u{D800}\"").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(1, 9))
    e.expect(kinds("\"\\u{D800}\" y")).to_equal([Error, Name("y")])
    e.expect(stream("\"\\u{D800}\" y").to_source()).to_equal("\"\\u{D800}\" y")
  })
}
