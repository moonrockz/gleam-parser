# Parse a Gleam module

`parse_text` turns source text into the compiler's untyped AST, the
`ModuleExtra` positions, the CST (every token per definition) and the
diagnostics. A definition with a syntax error is reported and skipped; the
other definitions still parse.

```mbt check
///|
test "pa: read definitions from the AST" {
  let r = @gleam.parse_text(
    "import gleam/io\n\n/// Says hi.\npub fn main() {\n  io.println(\"hi\")\n}\n",
  )
  guard r.module_.definitions
    is [{ definition: Import(i), .. }, { definition: Function(f), .. }] else {
    fail("expected an import and a function")
  }
  @expect.expect_all(e => {
    e.expect(r.has_errors()).to_be_false()
    e.expect(i.module_).to_equal("gleam/io")
    e.expect(f.name.map(n => n.name)).to_equal(Some("main"))
    e.expect(f.documentation.map(d => d.text)).to_equal(Some(" Says hi.\n"))
    e.expect(f.publicity).to_equal(@gleam.Publicity::Public)
  })
}
```

Spans are UTF-8 byte offsets; `SourceText` turns them into lines and
columns. The CST rebuilds the text, also when a definition failed:

```mbt check
///|
test "pa: recovery keeps the good definitions and the whole text" {
  let text = "fn broken( {\n  1\n}\n\npub fn ok() {\n  2\n}\n"
  let r = @gleam.parse_text(text)
  @expect.expect_all(e => {
    e.expect(r.module_.definitions.length()).to_equal(1)
    e.expect(r.diagnostics.length()).to_equal(1)
    e.expect(r.diagnostics[0].kind).to_equal("UnexpectedToken")
    e
    .expect(r.cst.definitions.map(d => d.kind))
    .to_equal([@gleam.DefinitionKind::Skipped, Function])
    e.expect(r.cst.to_source()).to_equal(text)
  })
}
```

`r.parsed()` is the oracle's shape (`module`, `extra`, `warnings`), so the
canonical JSON of a parse equals the Gleam compiler's for the same text:

```mbt check
///|
test "pa: canonical JSON of a parse" {
  let r = @gleam.parse_text("const x = 1\n")
  let json = @gleam.canonical(@gleam.encode_parsed(r.parsed()))
  @expect.expect(json.has_prefix("{\"extra\":{\"comments\":[]")).to_be_true()
}
```

A `Config` names what the parser accepts (its `Dialect`) and how deep it
reads (its fuel `Budget`). `Config::default()` is Gleam 1.19 with 100 units
of fuel. A dialect without a deprecation rule gives no warning for it:

```mbt check
///|
test "pa: a quiet dialect" {
  let text = "fn f(x) {\n  [\"a\"..x]\n}\n"
  let loud = @gleam.parse_text(text)
  let quiet = @gleam.parse_text(text, config={
    ..@gleam.Config::default(),
    dialect: { ..@gleam.Dialect::gleam_1_19(), deprecations: [][:], },
  })
  @expect.expect_all(e => {
    e.expect(loud.diagnostics.map(d => d.code)).to_equal(["GL-PARSE-002"])
    e.expect(quiet.diagnostics.length()).to_equal(0)
  })
}
```

See [configure.mbt.md](configure.mbt.md) for the fuel budget and the
configuration file.
