# AST fixtures

Each `.gleam` file is a small module. The `.json` next to it is the Rust
oracle's canonical JSON for it (`mise run fixtures:record`, after
`mise run oracle:build`). `tests/features/ast_json.feature` decodes each
`.json`, encodes it again and compares bytes. Edit a `.gleam`, re-record,
commit both.

## Fixtures

| Fixture | Exercises |
|---|---|
| `empty`, `comments_only`, `imports`, `constants`, `types`, `functions`, `expressions`, `strings`, `deprecated_syntax`, `target_shorthand` | Plan 3: one of each definition kind, literal forms, deprecated syntax warnings |
| `patterns` | Every pattern form, including float and string patterns; size variables, binary operators and blocks in bit array patterns |
| `bit_arrays` | With `patterns`, all 17 bit array option kinds in constants, expressions and patterns |
| `guards` | Clause guards: operators, not, field access, tuple index, constants, blocks |
| `use_pipes` | Pipelines with `echo`, `use` forms, captures |
| `records` | Record updates, field access chains, tuple indexes |
| `imports_full` | Unqualified imports, types, aliases, a documented import |
| `attributes` | `@external`, `@target`, `@deprecated`, `@internal` on every definition kind |
| `doc_comments` | Module docs, attached, detached and shared doc comments |
| `crlf` | CRLF line ends: `new_lines`, `empty_lines`, string values |
| `trailing_commas` | Every place the compiler records a trailing comma |
| `nested` | Moderate nesting of every construct |
| `edge_forms` | Labelled discard arguments, qualified types with a null name, deprecated list prepend, record spread and empty clause guard warnings |
| `error_*` | One compiler error kind each; the feature checks the first error's kind and span |

`tests/features/parser.feature` parses every `.gleam` here and compares the
canonical JSON (or the first error) with the `.json`.

`comments_only` ends with a doc comment that the compiler ignores because no
definition follows. `doc_comments` has a detached doc comment followed by a
regular comment. Together with `deprecated_syntax`, `target_shorthand` and
`edge_forms`, these fixtures cover all eight warning kinds.
