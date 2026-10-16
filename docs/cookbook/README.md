# gleam-parser cookbook

One article per task. Every code block with the info string `mbt check` runs
as a test (`mise run test:docs`). All articles share one namespace, so each
article prefixes its top-level names (`gs_`, …).

| Article | Task |
|---|---|
| [getting-started.mbt.md](getting-started.mbt.md) | Add gleam-parser to a project and read its version |
| [tokens.mbt.md](tokens.mbt.md) | Scan source into tokens and read a token's position |
| [source-coordinates.mbt.md](source-coordinates.mbt.md) | Construct valid coordinates and ranges, convert offset units, and migrate from integer positions |
| [ast-json.mbt.md](ast-json.mbt.md) | Encode and decode the AST as canonical JSON |
| [parsing.mbt.md](parsing.mbt.md) | Parse a module, read the AST, recover from errors, pick a dialect |
| [diagnostics.mbt.md](diagnostics.mbt.md) | Render diagnostics as the compiler does, or as JSON |
| [configure.mbt.md](configure.mbt.md) | Set the dialect and the fuel budget; load a configuration from TOML and the environment |
| [traverse.mbt.md](traverse.mbt.md) | Choose a traversal: walk, fold, reduce, a visitor, events, a cursor, and the node at a position |
| [format.mbt.md](format.mbt.md) | Format a module or a parse result as `gleam format` does |
