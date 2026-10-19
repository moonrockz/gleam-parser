# Format Gleam source

`format` writes a module as `gleam format` (1.19.2) does: 80 columns, two
spaces of indentation, comments and empty lines kept. Every one of the
compiler's own formatter test cases and every file of a 233-file corpus
formats to the binary's bytes. It raises `ParseFailed` with the error
diagnostics when the text has a syntax error.

```mbt check
///|
test "fm: format a module" {
  let text = "import  b\nimport a\n\npub fn main(){\n  io.println(  \"hi\" )\n}\n"
  @expect.expect(@gleam.format(text)).to_equal(
    "import a\nimport b\n\npub fn main() {\n  io.println(\"hi\")\n}\n",
  )
}
```

A syntax error is `ParseFailed`; render its diagnostics as the compiler
does:

```mbt check
///|
test "fm: a syntax error" {
  let text = "pub fn f( {\n}\n"
  let message = try {
    @gleam.format(text) |> ignore
    "formatted"
  } catch {
    ParseFailed(diagnostics) =>
      @gleam.render_plain(diagnostics[0], @gleam.SourceText(text), "main.gleam")
    OutOfFuel(_) => "out of fuel"
    DialectMismatch(..) => "different dialect"
  }
  @expect.expect(message).to_contain("Syntax error")
}
```

When you already have a parse result, `format_parsed` formats it after
your own checks (here: a module with a warning):

```mbt check
///|
test "fm: format a parse result after checking its diagnostics" {
  let result = @gleam.parse_text("/// a\n// b\npub const x = 1\n")
  let warnings = result.diagnostics.filter(d => d.severity is Warning)
  @expect.expect_all(s => {
    s.expect(warnings.length()).to_equal(1)
    s
    .expect(@gleam.format_parsed(result))
    .to_equal("/// a\n// b\n\npub const x = 1\n")
  })
}
```

The formatter is idempotent and keeps every comment once where the
compiler's formatter is and does (the rare exceptions are listed under
"Format Parity" in AGENTS.md). Parsing and formatting have no default
nesting cap. If you choose a finite nesting budget, deeper source is
rejected by the parser first. A flat chain of any length
(`a + b + c + …`, `a.b.c…`, `f()()…`) formats.
