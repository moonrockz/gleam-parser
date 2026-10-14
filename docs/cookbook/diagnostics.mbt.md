# Report diagnostics as the Gleam compiler does

Every `Diagnostic` has the compiler's `title`, `message` (the label under
the span), `text`, `hint` and extra `labels`. `render_plain` prints it in
the compiler's layout; `render_terminal` adds colours;
`encode_diagnostics` gives JSON.

```mbt check
///|
test "di: render a syntax error" {
  let text = "const no_cute_bee = \"cute\" <>\n"
  let r = @gleam.parse_text(text)
  let out = @gleam.render_plain(
    r.diagnostics[0],
    @gleam.SourceText::new(text),
    "src/main.gleam",
  )
  inspect(
    out,
    content=(
      #|error: Syntax error
      #|  ┌─ src/main.gleam:1:28
      #|  │
      #|1 │ const no_cute_bee = "cute" <>
      #|  │                            ^^ This operator has no value on its right side
      #|
      #|Hint: Remove it or put a value after it.
      #|
    ),
  )
}
```

The first error diagnostic has the compiler's error kind and span; a
lexical error the compiler's lexer reaches first comes first:

```mbt check
///|
test "di: the compiler's first error" {
  let r = @gleam.parse_text("fn f() {\n  1 ;\n}\n")
  @expect.expect(r.diagnostics.map(d => d.kind)).to_equal([
    "UnrecognizedToken", "UnexpectedEof",
  ])
}
```

```mbt check
///|
test "di: diagnostics as JSON" {
  let r = @gleam.parse_text("const x 1\n")
  let json = @gleam.encode_diagnostics(r.diagnostics).stringify()
  @expect.expect(json.contains("\"kind\":\"UnexpectedToken\"")).to_be_true()
}
```
