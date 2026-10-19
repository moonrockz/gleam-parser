# moonrockz/gleam-parser

Parser and parsing utilities for the [Gleam](https://gleam.run) programming
language in MoonBit. One expected user is
[morphir-moonbit](https://github.com/finos/morphir-moonbit), as a frontend
that reads Gleam and a backend that writes it.

Status: scanner, AST, parser, CST, diagnostics, syntax tree and formatter
are done. The AST mirrors
the Gleam compiler's untyped AST at v1.19.2; the parity oracle is the
compiler itself.

Done:

- **Scanner** (`tokenize`): lossless tokens with trivia (whitespace, line
  breaks, `//`, `///` and `////` comments) that rebuild the source byte for
  byte; spans are UTF-8 byte offsets as in the compiler; a lexical error is
  a `GL-SCAN-001` diagnostic with the compiler's message plus an `Error`
  token, and scanning goes on.
- **AST and JSON**: the compiler's untyped AST (v1.19.2) with a canonical
  JSON encoder and decoder (`docs/ast-json.md`); a Rust oracle on
  `gleam-core` writes the same JSON, and `tests/fixtures/ast` prove byte
  equality.

- **Parser** (`parse_text`, `parse_module`): a recursive-descent port of the
  compiler's `parse.rs`; on every fixture the canonical JSON equals the
  compiler's byte for byte, and the first error has the compiler's kind and
  span. A definition that does not parse is reported and skipped; the rest
  of the file is parsed.
- **CST** (`ParseResult.cst`): every token grouped per definition;
  `ModuleCst::to_source()` is the text byte for byte, also with errors.
- **Formatter** (`format`, `format_parsed`): `gleam format`'s text (80
  columns), from a port of the compiler's formatter on `moonrockz/pretty`;
  comments and empty lines are kept. Every one of the compiler's 893
  formatter test cases and every file of the 233-file corpus formats to the
  binary's bytes (`tests/format`).

  ```moonbit
  inspect(
    @gleam.format("pub fn main(){\n  io.println(  \"hi\" )\n}\n"),
    content="pub fn main() {\n  io.println(\"hi\")\n}\n",
  )
  ```

- **Dialect** (`Dialect::gleam_1_19()`): what the parser accepts.
- **Config** (`Config::default()`, `Config::load()`): the dialect and the
  optional nesting limit (`Unlimited` by default), from a
  `gleam-parser.toml` file, `GLEAM_PARSER_*` variables and the caller,
  merged with `with_fallback`.
- **Syntax tree** (`NodeRef`, `Tree`, `NodePath`): a read-only node model
  over the AST with parent links, position lookup and seven traversal
  styles: `walk`, `fold`, `reduce`, `Visitor`, pull events, push events
  and `TreeCursor`; every traversal uses an explicit stack.
- **Report** (`render_plain`, `render_terminal`, `encode_diagnostics`): the
  compiler's diagnostic layout, with colours, or as JSON.
- **Parity**: on a pinned corpus of 25 published packages (233 files), all
  233 files give the compiler's AST byte for byte (`mise run test:parity`);
  44 rejection fixtures check the accept and reject verdicts and the first
  error against the compiler (`mise run test:rejection`).

```moonbit
test {
  let r = @gleam.parse_text("import gleam/io\n\npub fn main() {\n  io.println(\"hi\")\n}\n")
  inspect(r.module_.definitions.length(), content="2")
  inspect(r.has_errors(), content="false")
}
```

Find the node at a byte offset and its path (from a tested doc example):

```moonbit
test {
  let tree = @gleam.Tree(@gleam.parse_text("pub fn add(a, b) {\n  a + b\n}\n"))
  // Byte 25 is the `b` in `a + b`.
  let b = tree.node_at(@gleam.ByteOffset::from_int(25).unwrap()).unwrap()
  inspect("\{b.category()}/\{b.kind()}", content="expression/var")
  inspect(tree.node_path(b).unwrap(), content="definitions[0].body[0].expression[0].right[0]")
}
```

Planned:

- **Printer and formatter**: Gleam source from an AST, `gleam format` parity.

## Installation

```bash
moon add moonrockz/gleam-parser
```

In your package's `moon.pkg`:

```
import {
  "moonrockz/gleam-parser" @gleam,
}
```

## Development

- `mise run check`: info, lint, format and all tests.
- `mise run test:targets`: the library on wasm, wasm-gc, js and native.
- `mise run test:parity` and `mise run test:rejection`: parity with the Gleam
  compiler on the corpus and on the rejection fixtures (see `AGENTS.md`).
- See `AGENTS.md` for conventions and `docs/cookbook/` for tested examples.

## Optional target profiles

Standard Gleam stays the default. A core-only consumer can register its own
source-language target without installing a profile module:

```moonbit
test {
  let orbit = @gleam.Target::extension("orbit")
  let dialect = @gleam.Dialect::gleam_1_19().register_target(orbit)
  let config = { ..@gleam.Config::default(), dialect }
  let result = @gleam.parse_text("@target(orbit) pub const answer = 42", config~)
  assert_eq(result.has_errors(), false)
  let document = @gleam.decode_extended(@gleam.encode_extended(result))
  assert_eq(document.parsed, result.parsed())
}
```

`@external(orbit, "module", "symbol")` uses the same registry. Functions and
external types retain one binding per target in `externals`; use
`external_for(target)` for lookup. Bindings do not create target restrictions.
Parsing retains every definition. A registration supplies no backend and does
not resolve foreign symbols.

For reusable configurations, construct a `Profile` and apply it with
`Dialect::with_profile`. Compose compatible profiles explicitly. Conflicts
raise typed errors that identify both providers. TOML profile names resolve
only through the `Profiles` registry that the application supplies.

The optional [Morphir module](profiles/morphir/src/README.mbt.md) is published
as `moonrockz/gleam-parser-morphir`. With its profile enabled, the parser accepts
Gleam such as:

```gleam
@target(morphir)
pub const destination = "morphir"

@external(erlang, "erlang", "length")
@external(javascript, "./list.mjs", "length")
@external(morphir, "morphir/sdk/list", "length")
pub fn length(xs: List(a)) -> Int

@target(morphir)
@external(morphir, "example/domain", "CustomerId")
pub type CustomerId
```

`@target(morphir)` marks a definition for a downstream translator.
`@external(morphir, ...)` records an external binding and can coexist with
standard bindings. The standard preset rejects the Morphir annotations.
The profile supplies parsing and metadata; it does not generate Morphir code
or resolve the illustrative foreign references above. See the module's
[source examples and tested parser calls](profiles/morphir/src/README.mbt.md#what-gleam-does-this-profile-accept).

Install the optional module separately, then enable it:

```moonbit
let dialect = @gleam.Dialect::gleam_1_19().with_profile(@morphir.profile())
let config = { ..@gleam.Config::default(), dialect }
let result = @gleam.parse_text(
  "@external(morphir, \"example/domain\", \"CustomerId\")\npub type CustomerId\n",
  config~,
)
```

`format_parsed(result)` uses the parse dialect. An explicitly different dialect
raises `DialectMismatch`. Compiler-compatible `encode_parsed` preserves standard
JSON bytes and raises `NonStandardTarget` for extension-bearing ASTs. Use
`encode_extended(result)` for versioned JSON with generic bindings and dialect
identity. Decoding does not load profile code.

The [tested cookbook](docs/cookbook/target-profiles.mbt.md) covers core-only use,
custom registration, composition, conflicts, configuration lookup, JSON, and
formatting. See the [0.5 migration guide](docs/migration-0.5.md) for changed AST
fields and encoder signatures, and [extended JSON schema](docs/extended-json.md)
for the interchange contract.
