# Configure the parser

A `Config` holds what the parser accepts (its `Dialect`) and how deep it
reads (its fuel `Budget`). Every parse entry point takes `config?`;
without it, `Config::default()` applies: Gleam 1.19 and 100 units of fuel.

Fuel counts nested levels of syntax: each nested expression, pattern,
type, constant, guard or bit-array size spends one unit while it is open
and gives it back when it closes. When the budget is spent the parser
reports `GL-PARSE-004` (`Recursion limit exceeded`) and names the
operations on the stack:

```mbt check
///|
test "cf: a small budget names what nests" {
  let deep = "fn f() {\n  [[[[[1]]]]]\n}\n"
  let r = @gleam.parse_text(deep, config={
    ..@gleam.Config::default(),
    fuel: @gleam.Budget::new(3).unwrap(),
  })
  @expect.expect_all(e => {
    e.expect(r.diagnostics.map(d => d.code)).to_equal(["GL-PARSE-004"])
    e.expect(r.diagnostics[0].message).to_equal("Recursion limit exceeded")
    e
    .expect(
      r.diagnostics[0].text.has_prefix(
        "The fuel budget of 3 ran out while nesting expression ×3.",
      ),
    )
    .to_be_true()
  })
}
```

The default of 100 is sized for wasm, the smallest stack. On native or js
a larger budget is safe; a `Budget` is at least 1:

```mbt check
///|
test "cf: a larger budget on a large stack" {
  let deep = "fn f() {\n  [[[[[1]]]]]\n}\n"
  let r = @gleam.parse_text(deep, config={
    ..@gleam.Config::default(),
    fuel: @gleam.Budget::new(500).unwrap(),
  })
  @expect.expect_all(e => {
    e.expect(r.has_errors()).to_be_false()
    e.expect(@gleam.Budget::new(0)).to_equal(None)
  })
}
```

A configuration is built in layers. `Config::from_toml` reads the
`[parser]` table of a `gleam-parser.toml` text, `Config::from_env` reads
`GLEAM_PARSER_GLEAM` and `GLEAM_PARSER_FUEL`, and `with_fallback` merges
layers: a set field wins over the layer below it. A bad value is a
`ConfigError` that names its source; nothing falls back silently.

```mbt check
///|
test "cf: layers with fallback" {
  let file = @gleam.Config::from_toml(
    "[parser]\ngleam = \"1.19\"\nfuel = 500\n",
  )
  let env = @gleam.Config::from_env(
    @gleam.Environment::of({ "GLEAM_PARSER_FUEL": "2000" }),
  )
  let config = env.with_fallback(file).to_config(@gleam.Config::default())
  @expect.expect_all(e => {
    e.expect(config.fuel.units()).to_equal(2000)
    e.expect(config.dialect.name).to_equal("gleam-1.19")
  })
  let bad = try {
    @gleam.Config::from_toml("[parser]\nfuel = 0\n") |> ignore
    "no error"
  } catch {
    ConfigError(source=TomlKey(key), message~) => "\{key}: \{message}"
    _ => "other"
  }
  @expect.expect(bad).to_equal("parser.fuel: must be at least 1")
}
```

`Config::load` does the same from the file `gleam-parser.toml` in the
working directory (a missing file is no layer) and the process
environment; it is the one function of the library that reads a file:

```mbt nocheck
///|
let config = @gleam.Config::load()

///|
let r = @gleam.parse_text(text, config~)
```
