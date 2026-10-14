# AST fixtures

Each `.gleam` file is a small module; the `.json` next to it is the Rust
oracle's canonical JSON for it (`mise run fixtures:record`, after
`mise run oracle:build`). `tests/features/ast_json.feature` decodes each
`.json`, encodes it again and compares bytes. Edit a `.gleam`, re-record,
commit both.

## Fixtures

| Fixture | Exercises |
|---|---|
| `empty`, `comments_only`, `imports`, `constants`, `types`, `functions`, `expressions`, `strings`, `deprecated_syntax`, `target_shorthand` | Plan 3: one of each definition kind, literal forms, deprecated syntax warnings |
| `patterns` | Every pattern form: alternatives, string prefixes, lists with tails, constructors with labels and spreads, bit arrays with sizes and units |
| `bit_arrays` | Bit array options in constants and expressions |
| `guards` | Clause guards: operators, not, field access, tuple index, constants, blocks |
| `use_pipes` | Pipelines with `echo`, `use` forms, captures |
| `records` | Record updates, field access chains, tuple indexes |
| `imports_full` | Unqualified imports, types, aliases, a documented import |
| `attributes` | `@external`, `@target`, `@deprecated`, `@internal` on every definition kind |
| `doc_comments` | Module docs, attached, detached and shared doc comments |
| `crlf` | CRLF line ends: `new_lines`, `empty_lines`, string values |
| `trailing_commas` | Every place the compiler records a trailing comma |
| `nested` | Moderate nesting of every construct |
| `error_*` | One compiler error kind each; the feature checks the first error's kind and span |

`tests/features/parser.feature` parses every `.gleam` here and compares the
canonical JSON (or the first error) with the `.json`.
