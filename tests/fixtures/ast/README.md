# AST fixtures

Each `.gleam` file is a small module; the `.json` next to it is the Rust
oracle's canonical JSON for it (`mise run fixtures:record`, after
`mise run oracle:build`). `tests/features/ast_json.feature` decodes each
`.json`, encodes it again and compares bytes. Edit a `.gleam`, re-record,
commit both.
