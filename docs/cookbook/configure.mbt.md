# Configure the parser

A `Config` holds the parser dialect and its `NestingLimit`. Every parse
entry point takes `config?`. The default accepts Gleam 1.19 with unlimited
nesting. Parsing and formatting use heap continuations on every target;
syntax depth does not consume the machine stack.

`Dialect.keywords` contains `Keyword` values. The parser treats an omitted
keyword as an ordinary name. The scanner still classifies the compiler's
keywords, and the CST keeps its original tokens. Use `Dialect::reserves`
to check whether a keyword is reserved by a dialect.

```mbt check
///|
test "cf: a dialect can unreserve a keyword" {
  let base = @gleam.Config::default()
  let dialect = {
    ..base.dialect,
    keywords: base.dialect.keywords
    .iter()
    .filter(k => k != @gleam.Keyword::Echo)
    .collect()[:],
  }
  let result = @gleam.parse_text("const echo = 1\n", config={ ..base, dialect, })
  @expect.expect(result.has_errors()).to_be_false()
}
```

For migration, replace strings in a custom `keywords` list with `Keyword`
cases. For example, replace `"echo"` with `Keyword::Echo`. The default
dialect still reserves all 22 compiler keywords.

An optional finite budget counts nested levels of syntax: each nested expression, pattern,
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
    fuel: Limited(@gleam.Budget(3)),
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

A finite budget must be at least 1. The same budget works on every target.
Use `Unlimited` to remove the limit:

```mbt check
///|
test "cf: unlimited nesting is the default" {
  let deep = "fn f() {\n  [[[[[1]]]]]\n}\n"
  let r = @gleam.parse_text(deep, config={
    ..@gleam.Config::default(),
    fuel: Unlimited,
  })
  @expect.expect_all(e => {
    e.expect(r.has_errors()).to_be_false()
    e.expect(@gleam.Budget::from_int(0)).to_equal(None)
  })
}
```

For migration, replace `fuel: budget` with `fuel: Limited(budget)` in a
`Config`, and `fuel: Some(budget)` with `fuel: Some(Limited(budget))` in a
`Partial`. Use `limit.budget()` to read its optional finite budget.

A configuration is built in layers. `Config::from_toml` reads the
`[parser]` table of a `gleam-parser.toml` text, `Config::from_env` reads
`GLEAM_PARSER_GLEAM` and `GLEAM_PARSER_FUEL`, and `with_fallback` merges
layers: a set field wins over the layer below it. A bad value is a
`ConfigError` that names its source; nothing falls back silently.
Set `fuel = "unlimited"` in TOML or `GLEAM_PARSER_FUEL=unlimited` to clear
a lower layer's limit. `Some(Unlimited)` does the same in a caller layer.

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
    e.expect(config.fuel.budget().map(b => b.units())).to_equal(Some(2000))
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
fn cf_parse_with_config(text : String) -> @gleam.ParseResult raise {
  let config = @gleam.Config::load()
  @gleam.parse_text(text, config~)
}
```
