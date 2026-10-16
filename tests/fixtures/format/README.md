# Formatter fixtures

Each `<suite>/<nnn>.gleam` is the input of a test case of the Gleam compiler's
formatter (`format/src/tests.rs` is suite `tests`, `format/src/tests/<suite>.rs`
the others; `<nnn>` is the case's 1-based index in the file). Each
`<nnn>.formatted.gleam` is what `gleam format` 1.19.2 writes for it. See
`NOTICE` for the licence.

To re-extract and re-record (local only):

    git clone --depth 1 --branch v1.19.2 https://github.com/gleam-lang/gleam .dev/gleam
    mise run formatter:cases
    mise run corpus:fetch
    mise run formatter:record

`mise run test:format` scores gleam-parser against these files and against
`tests/corpus/format.lock`.
