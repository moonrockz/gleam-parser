# moonrockz/gleam-parser

Parser and parsing utilities for the [Gleam](https://gleam.run) programming
language in MoonBit. One expected user is
[morphir-moonbit](https://github.com/finos/morphir-moonbit), as a frontend
that reads Gleam and a backend that writes it.

Status: bootstrap. The AST will mirror the Gleam compiler's untyped AST at
v1.19.2; the parity oracle is the compiler itself.

Planned, in order:

- **Scanner**: lossless tokens with trivia (whitespace, `//`, `///` and
  `////` comments) that rebuild the source byte for byte.
- **Parser**: tokens to AST, concrete syntax tree (CST) and diagnostics with
  the compiler's wording; a definition that does not parse is reported and
  the rest of the file is parsed.
- **AST and JSON**: the compiler's untyped AST, with a canonical JSON encoder
  and decoder.
- **Syntax tree**: a read-only node model with six traversal styles.
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
- See `AGENTS.md` for conventions and `docs/cookbook/` for tested examples.
