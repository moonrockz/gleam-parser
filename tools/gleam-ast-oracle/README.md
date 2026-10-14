# gleam-ast-oracle

Parses `.gleam` files with the Gleam compiler (`gleam-core` at tag v1.19.2)
and writes gleam-parser's canonical AST JSON (`docs/ast-json.md`), one line
per file. It is the parity oracle: `mise run fixtures:record` and
`mise run corpus:goldens` run it. CI never builds it.

    mise run oracle:build
    tools/gleam-ast-oracle/target/release/gleam-ast-oracle a.gleam b.gleam

To move to a new Gleam version, change the `tag` in `Cargo.toml` and in
`tests/corpus/gleam_version.txt`, then re-record fixtures and goldens.
