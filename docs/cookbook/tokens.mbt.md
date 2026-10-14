# Scan Gleam source into tokens

`tokenize` gives every token with the trivia (whitespace, line breaks and
comments) before it. The lexemes and the trivia rebuild the source.

```mbt check
///|
test "tk: tokens and trivia rebuild the source" {
  let source = "// add\npub fn add(a, b) {\n  a + b\n}\n"
  let stream = @gleam.tokenize_text(source)
  @expect.expect_all(e => {
    e.expect(stream.to_source()).to_equal(source)
    e.expect(stream.diagnostics.length()).to_equal(0)
    e.expect(stream.tokens[0].kind).to_equal(@gleam.TokenKind::Keyword(Pub))
    e.expect(stream.tokens[0].trivia_before.length()).to_equal(2)
  })
}
```

A lexical error does not stop the scan. It gives a `GL-SCAN-001` diagnostic
with the compiler's message, and an `Error` token over the text it covers:

```mbt check
///|
test "tk: a lexical error is a diagnostic and an Error token" {
  let stream = @gleam.tokenize_text("let x = 'a'")
  let d = stream.diagnostics[0]
  @expect.expect_all(e => {
    e.expect(d.code).to_equal("GL-SCAN-001")
    e.expect(d.kind).to_equal("UnrecognizedToken")
    e.expect(d.message).to_equal("Unexpected single quote")
    e.expect(stream.tokens[3].kind).to_equal(@gleam.TokenKind::Error)
    e.expect(stream.to_source()).to_equal("let x = 'a'")
  })
}
```

Spans are UTF-8 byte offsets, as in the Gleam compiler. Use `SourceText` to
turn one into a line and column:

```mbt check
///|
test "tk: token position" {
  let text = "let é = 1"
  let source = @gleam.SourceText::new(text)
  let stream = @gleam.tokenize(source)
  let equal = stream.tokens[2]
  @expect.expect_all(e => {
    e.expect(equal.span).to_equal(@gleam.SrcSpan::new(7, 8))
    e
    .expect(source.position_of(equal.span.start))
    .to_equal(Some(@gleam.Position::new(1, 7)))
  })
}
```
