# gleam-parser cookbook

One article per task. Every code block with the info string `mbt check` runs
as a test (`mise run test:docs`). All articles share one namespace, so each
article prefixes its top-level names (`gs_`, …).

| Article | Task |
|---|---|
| [getting-started.mbt.md](getting-started.mbt.md) | Add gleam-parser to a project and read its version |
| [tokens.mbt.md](tokens.mbt.md) | Scan source into tokens and read a token's position |
| [ast-json.mbt.md](ast-json.mbt.md) | Encode and decode the AST as canonical JSON |
| [parsing.mbt.md](parsing.mbt.md) | Parse a module, read the AST, recover from errors, pick a dialect |
| [diagnostics.mbt.md](diagnostics.mbt.md) | Render diagnostics as the compiler does, or as JSON |
