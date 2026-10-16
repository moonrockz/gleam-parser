# gleam-ast-oracle

Parses `.gleam` files with the Gleam compiler (`gleam-core` at tag v1.19.2)
and writes gleam-parser's canonical AST JSON (`docs/ast-json.md`), one line
per file. It is the parity oracle: `mise run fixtures:record` and
`mise run corpus:goldens` run it. CI never builds it.

The crate pins its Rust toolchain in `rust-toolchain.toml`. Run the build
task from the repository root. It enters the crate directory before it runs
Cargo so that the pinned toolchain applies.

    mise run oracle:build
    tools/gleam-ast-oracle/target/release/gleam-ast-oracle a.gleam b.gleam

An accepted file produces `module`, `extra` and `warnings`. A rejected file
produces `error` with the first error's kind, lexical kind and byte span.
`tests/features/ast_json.feature` checks the JSON codec against every
fixture. `tests/features/parser.feature` checks parser parity against the
same fixtures. `mise run test:bdd` runs both features.

To move to a new Gleam version, change the `tag` in `Cargo.toml` and in
`tests/corpus/gleam_version.txt`, then re-record fixtures and goldens.
See the Gleam upgrade procedure in `AGENTS.md` for the source and schema
changes that must accompany a version change.
