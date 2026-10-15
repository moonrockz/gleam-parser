# moonrockz/gleam-parser

Parser and parsing utilities for the [Gleam](https://gleam.run) programming
language in MoonBit. One expected user is
[morphir-moonbit](https://github.com/finos/morphir-moonbit), as a frontend
that reads Gleam and a backend that writes it.

Status: scanner, AST, parser, CST and diagnostics are done. The AST mirrors
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
- **Dialect** (`Dialect::gleam_1_19()`): what the parser accepts.
- **Config** (`Config::default()`, `Config::load()`): the dialect and the
  fuel budget (the recursion limit, 100 units by default), from a
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
  let tree = @gleam.Tree::new(@gleam.parse_text("pub fn add(a, b) {\n  a + b\n}\n"))
  // Byte 25 is the `b` in `a + b`.
  let b = tree.node_at(25).unwrap()
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
