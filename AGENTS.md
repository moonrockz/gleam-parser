# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Overview

This module (`moonrockz/gleam-parser`) is a **parser and parsing utilities**
library for the [Gleam](https://gleam.run) programming language. One expected
user is [morphir-moonbit](https://github.com/finos/morphir-moonbit). It gives,
in stages (bd epics `v0.1`, `v0.2`, `v0.3`):

- **Scanner** — lossless tokenization (`tokenize`, a port of the compiler's
  `lexer.rs`). All trivia before a token is its `trivia_before`; the trivia
  after the last token is its `trivia_after`; with no token it is
  `TokenStream.trivia`. Lexemes and trivia rebuild the source; spans are
  UTF-8 byte offsets, as in the Gleam compiler; `\r\n` and a lone `\r` are
  one line break. A comment's `span` includes the slashes and
  `Comment::content_span()` is the compiler's span (after them). A string
  token's value keeps escapes as written with `\r\n` and `\r` as `\n` (the
  compiler's `Token::String`). A lexical error is a `GL-SCAN-001`
  diagnostic (`kind` = the `LexicalErrorType` variant) plus one `Error`
  token from the token start to the end of the error, at least one
  character, or to the closing quote inside a string; scanning continues.
- **Parser** — a recursive-descent port of the compiler's `parse.rs`
  (`src/parser`), one file per concern, over the compiler's two-token
  lookahead. A scanner `Error` token is a hole in the stream, as a lexical
  error is in the compiler. Recovery per definition: a syntax error is
  reported, the parser skips to the next definition start (`import`,
  `const`, `pub`, `fn`, `type`, `opaque` or `@` in column 1) and goes on;
  the skipped tokens are a `Skipped` CST definition. `ParseResult` holds
  `module_`, `extra`, `warnings`, `cst` and `diagnostics`;
  `ParseResult::parsed()` is the oracle's `Parsed`. See "Parser contract".
- **AST** — a mirror of the compiler's untyped AST at v1.19.2 (`src/ast`),
  without analysis-only fields (see `docs/ast-json.md`), with a canonical
  JSON encoder and decoder. The parity oracle `tools/gleam-ast-oracle`
  (Rust, `gleam-core` v1.19.2, Rust 1.98.1 pinned by its
  `rust-toolchain.toml`) writes the same JSON; `mise run oracle:build`
  builds it, `mise run fixtures:record` records `tests/fixtures/ast/*.json`;
  CI never runs cargo.
- **CST** — every token grouped per definition (`src/cst`);
  `ModuleCst::to_source()` is the text byte for byte. `trivia_extra`
  derives the comment, line-end and empty-line positions of `ModuleExtra`
  from trivia; the parser adds the trailing commas (recorded where the
  compiler's `series_of` records them, so `[1, ..rest]` has one).
- **Dialect** — `Dialect::gleam_1_19()` (`src/dialect`): the reserved words,
  attributes, targets and deprecation rules the parser accepts.
- **Fuel and Config** — `src/fuel`: an immutable recursion budget
  (`Budget`, at least 1; `default_budget` 100 units, sized for wasm), one
  unit per nested entry, `FuelExhausted` names the operations.
  `src/config`: `Config { dialect, fuel }` from defaults,
  `gleam-parser.toml` (`[parser]`: `gleam`, `fuel`), `GLEAM_PARSER_GLEAM`
  and `GLEAM_PARSER_FUEL` and the caller, merged with `with_fallback` (set
  fields win); every bad value is a `ConfigError` that names its source;
  `Config::load` is the only I/O. Every parse entry point takes `config?`.
- **Report** — `render_plain`, `render_terminal`, `encode_diagnostics`
  (`src/report`): the compiler's layout (codespan-reporting 0.13.1 rich
  display), then the text and `Hint: `.
- **Syntax tree** (v0.2) — `src/syntax`: a read-only node model over the
  AST. `NodeRef` points into the typed AST (28 cases, nothing copied);
  `(category, kind)` is the JSON vocabulary of `docs/ast-json.md`, fields
  are the JSON keys in encoder order, and `kind_table()` lists every row
  (checked against the schema by `tests/features/syntax.feature`). Spans
  are byte offsets, and a node's span contains its children's: the module
  spans to its last token, a definition to its last child (a constant's
  value, an external function's return annotation, `end_position`), a
  clause guard starts at the leftmost node of its left spine (the compiler
  locates a `TupleIndex` guard at `.index` only). Paths mirror the JSON
  (`definitions[0].body[1].value[0]`) with three differences: a
  single-node field gets index 0, the `definition` wrapper of a targeted
  definition is not a step, and a clause's `alternative_patterns` is
  flattened to one index. `src/syntax/children.mbt` (`entries` and
  `kind_table`) changes with the schema; laws check that every row equals
  a node's fields and that every JSON key holding nodes is a field. Seven traversals on explicit stacks (no
  recursion, no fuel): `walk`, `fold`, `reduce` (bottom up, returns a
  value; a trait cannot carry the result type), `Visitor` with `accept`,
  `EventReader` (pull), `push_events` with `Handler` (push), `TreeCursor`.
  `Tree` indexes parents once and answers `parent`, `node_path`,
  `node_at(offset)` (the smallest span, deepest among equals) and
  `tokens_in`. One documented gap: a descent with `goto_first_child_for`
  stops at a function capture's generated argument; `goto_node_at` reaches
  the hole.
- **Formatter** (v0.3) — `src/format`: a port of the compiler's
  `format/src/lib.rs` on `moonrockz/pretty` (its pretty-arena forms:
  `group_alone`, `break_`, `flex_break`, `lines`, `force_break`,
  `next_break_fits`, `nest_if_broken`, `set_nesting`, `zero_width`,
  `raw_text`; `render(doc, width=80, start=Unbroken)`). `format(text,
  config?)` and `format_parsed(result, config?)` give `gleam format`'s
  text; `FormatError` is `ParseFailed` (the error diagnostics) or
  `OutOfFuel` (`expr`, `pattern`, `type_ast`, `const_expr`, `clause_guard`
  and `bit_array_size` spend one unit per nesting level; `statement` spends
  none, and a flat chain (a left-nested operator chain, a field-access or
  tuple-index chain, a call chain) is walked in a loop with no fuel and no
  stack per link, so the formatter accepts what the parser accepts). A private
  `Formatter` keeps the comment arrays of `ModuleExtra` with forward
  cursors, as the compiler pops slices; comment text comes from the CST
  source (`ModuleCst::to_source()`). Every compiler function keeps its name
  (`module` is `format_module`). pretty-arena's declared widths win over
  the text (`const `, `if ` and ` as` count one column less). Every
  compiler test case and every corpus file formats to the binary's bytes.
  See "Format Parity".

### Gleam reference

The reference is the Gleam compiler at tag `v1.19.2`
(<https://github.com/gleam-lang/gleam>). Sources that define behaviour:
`compiler-core/src/parse/lexer.rs`, `parse/token.rs`, `parse.rs`,
`parse/extra.rs`, `parse/error.rs`, `ast.rs`, `ast/untyped.rs`,
`ast/constant.rs`, `warning.rs`, `format/src/lib.rs` and
`pretty-arena/src/lib.rs`. The parity oracle is `tools/gleam-ast-oracle`
(Rust, on `gleam-core`); it runs only locally.

To move to a new Gleam version: bump the tag in
`tools/gleam-ast-oracle/Cargo.toml` and `tests/corpus/gleam_version.txt`;
diff the files above between the tags; apply the changes to `src/ast`,
`src/scanner`, `src/parser`, `src/syntax/children.mbt`, `src/format` and
`docs/ast-json.md`; then re-record and ratchet as "Gleam Parity" and
"Format Parity" say (`mise run formatter:cases`, `formatter:record`,
`formatter:ratchet`; a test checks that the two files name the same tag).

### Parser contract

- The AST the parser builds equals the compiler's for the same text
  (`tests/features/parser.feature` compares the canonical JSON of every
  fixture with the oracle's, byte for byte). Keep the port close to
  `parse.rs`: the same functions, the same spans, the same error kinds at
  the same spans.
- The first error diagnostic of a file is the compiler's first error. Order
  rule: a lexical error that the compiler's lexer reached before the parser
  stopped (its start is before the end of the farthest token the parser
  loaded) comes first; then diagnostics by position; `UnexpectedEof` keeps
  the compiler's raw span `0..0` and sorts at the end of the text (the
  renderer shows it at the last byte, as `error.rs` does). An error whose
  end the compiler takes from an inner `UnexpectedEof` (for example
  `InvalidModuleTypePattern` at the end of a file) keeps the compiler's
  `start..0` span too.
- Doc comments follow `take_documentation`: the `///` lines before a
  definition's start (its `pub`, `fn`, `import` module name, `const` name,
  variant name, field label) join with `\n` after each line; a regular
  comment between a doc comment and the definition detaches it (warning
  `GL-PARSE-003`); a doc comment inside a body is taken by the next
  definition; a trailing doc comment with no definition is ignored.
- Fuel keeps every target stack-safe, `GL-PARSE-004` (`TooMuchNesting`,
  message `Recursion limit exceeded`): the parser spends one unit of
  `Config.fuel` per nested entry of an expression, pattern, type,
  constant, clause guard or bit-array size (`Parser::nested`), and reports
  the budget and the operations on the stack when it runs out. The default
  budget is 100 units (wasm overflows at about 140 nested lists); raise it
  only on native or js. The JSON codec does not recurse
  (`src/ast/step.mbt`), so an AST the parser accepts always encodes,
  decodes and canonicalises; the laws in `src/parser/nesting_law_test.mbt`
  check the limit against the codec. The compiler has no such limit (known
  difference).
- Snippet parsers for tests and tools: `parse_expression_text`,
  `parse_statements_text`, `parse_pattern_text`, `parse_type_text`,
  `parse_constant_text` (the compiler's test interfaces; they raise
  `ParseError`).
- A new fixture: write `tests/fixtures/ast/<name>.gleam`, run `mise run
  fixtures:record`, add it to `tests/features/parser.feature` and to
  `tests/fixtures/ast/README.md`. An error fixture is checked on its first
  error only.

### Architecture Summary

```
moonrockz/gleam-parser
├── moon.work             # Workspace: the library (.), tests (tests/) and the cookbook (docs/cookbook/)
├── src/                  # The library (the only published module)
│   ├── lib.mbt           # Package entry point; re-exports; version()
│   ├── span/             # SrcSpan (UTF-8 byte offsets), Position (1-based line and column)
│   ├── diagnostic/       # Severity, Label, Diagnostic, the code table
│   ├── scanner/          # SourceText; lexer (port of lexer.rs); tokens, trivia, lexical diagnostics
│   ├── lawkit/           # Property-test generators and helpers (public test support)
│   ├── ast/              # Compiler-mirror AST; canonical JSON encode/decode (step trampoline, no depth limit)
│   ├── cst/              # ModuleCst, DefinitionCst (tokens per definition); trivia_extra
│   ├── dialect/          # Dialect::gleam_1_19(): attributes, targets, deprecation rules
│   ├── fuel/             # Budget, Operation, Spent, Fuel (immutable), FuelExhausted
│   ├── config/           # Config, Partial, Source, ConfigError, Environment; from_toml, from_env, load
│   ├── parser/           # Port of parse.rs: definitions, expressions, patterns, types, constants, guards, bit arrays; recovery; fuel
│   ├── report/           # render_plain, render_terminal (codespan layout), encode_diagnostics
│   ├── syntax/           # NodeRef, children, kind_table; walk, fold, reduce, Visitor, events, Tree, NodePath, TreeCursor
│   └── format/           # Port of format/src/lib.rs on moonrockz/pretty: formatter state, comments, definitions, expressions, patterns, cases
├── tests/                # Unpublished module moonrockz/gleam_parser_tests
│   ├── bdd/              # MoonSpec step definitions for tests/features
│   ├── features/         # Gherkin features
│   ├── fixtures/ast/     # Gleam sources with the oracle's JSON
│   ├── corpus/           # packages.txt, gleam_version.txt, manifest.json, goldens.lock, baseline.json
│   ├── parity/           # Corpus parity (mise run test:parity)
│   ├── format/           # Format parity scoreboard (mise run test:format), baseline.json
│   ├── fixtures/format/  # The compiler's formatter cases with gleam format's output
│   └── rejection/        # Rejection fixtures, verdicts.json, pending.json, messages/ (mise run test:rejection)
├── tools/gleam-ast-oracle/   # Rust oracle (plan 3)
├── scripts/              # MoonBit tooling scripts (.mbtx)
├── docs/cookbook/        # Unpublished module moonrockz/gleam_parser_cookbook: tested articles
├── .dev/                 # Gitignored working area for specs, plans and scratch files
└── mise-tasks/           # File-based mise tasks
```

### Diagnostics

Every `Diagnostic` has a `code`, a `kind` (the compiler's error variant, for
example `UnrecognizedToken`; empty when there is none), a `severity`, a
one-line `message`, a `span`,
a `title` (the compiler's: "Syntax error", "Deprecated prepend syntax", …),
`labels` (the extra labels only; the primary label is `span` with
`message`), `text` (the compiler's body text, lines joined with `\n`) and
an optional `hint` (without the `Hint: ` prefix; the renderer adds it), with
the compiler's wording from `parse/error.rs` and `warning.rs`. The renderer
(`src/report`) follows codespan-reporting 0.13.1: tab width 4, every code
point width 1 (the compiler uses East Asian widths), lines split at `\n`
only; terminal colours are close to the compiler's, not an oracle.

| Code | Meaning |
|------|---------|
| `GL-SCAN-001` | Lexical error (the message names the LexicalErrorType) |
| `GL-PARSE-001` | Syntax error (the message names the ParseErrorType) |
| `GL-PARSE-002` | Deprecated syntax (warning) |
| `GL-PARSE-003` | Detached doc comment (warning) |
| `GL-PARSE-004` | Too much nesting |

`src/diagnostic/codes.mbt` holds these descriptions (`description(code)`,
re-exported as `diagnostic_description`). Keep this table and that file in
step when you add a code.

### AST and JSON contract

- `src/ast` keeps every field of the compiler's untyped types except the
  analysis-only ones: `type_`, `return_type`, `typed_parameters`,
  `implementations`, `purity`, `compiled_case`, `constructor`
  (`Inferred`/`ValueConstructor`), `names`, `unused_definition_positions`,
  `origin`, `field_map`, `record_constructor`, `definition_location`,
  `extra_information`, and `Module.name`/`Module.documentation` (empty at
  parse time; `ModuleExtra.module_comments` holds the module docs). Variants
  the parser never builds are not mirrored: `Pattern::Invalid`,
  `ClauseGuard::Invalid`, `ClauseGuard::ModuleSelect`, `Constant::Invalid`.
- Field names are the compiler's in snake_case; a name that is a MoonBit
  keyword gets a trailing underscore (`module_`, `guard_`, `opaque_`,
  `alias_`, `constructor_`). Type names drop the `Untyped` prefix
  (`UntypedExpr` is `Expr`). Every list is an `ArrayView`.
- `@ast.canonical(json)` writes keys in code-unit order with serde_json's
  escaping (MoonBit's `String` compare is length-first, so it is not used).
  `SrcSpan` is `{"end":n,"start":n}`; `BigInt` is a decimal string; `Float`
  writes `value` only (`float_value` is derived with `parse_float_value`);
  payload-free enums (`Target`, `BinOp`, `IntOperator`,
  `ImplicitCallArgOrigin`) are snake_case strings; enums with payload are
  objects with `kind`; `Expr::Fn.kind`, `Expr::Todo.kind` and
  `Assignment.kind` are written as `fn_kind`, `todo_kind`,
  `assignment_kind`.
- `decode_*` after `encode_*` gives an equal value; `encode` of a decoded
  fixture gives the fixture's bytes (`tests/features/ast_json.feature`).
- The compiler's `u64` indexes are `UInt64` and are written with exact
  digits. The codec runs on a step trampoline (`src/ast/step.mbt`): a
  node encoder or decoder takes a continuation and returns a step, `run`
  loops, so no AST depth overflows the stack on any target and there is no
  depth limit. Keep the four rules of `step.mbt` when you add a node. The
  derived `Eq` and `Debug` of the AST still recurse. `@json.parse` has its
  own nesting limit (`max_nesting_depth`) and recursion.
- To change the schema: change `src/ast/encode.mbt`, `src/ast/decode.mbt`,
  `tools/gleam-ast-oracle/src/encode.rs`, `docs/ast-json.md` and
  `src/syntax/children.mbt` (`entries`, `kind_table`) together, then
  `mise run fixtures:record` and commit the fixtures.

### Positions

`SrcSpan { start, end }` holds UTF-8 byte offsets, as the compiler does.
`SourceText` maps a byte offset to a UTF-16 offset (for editors) and to a
`Position { line, column }` (1-based; columns count code points). `\r\n` and
a lone `\r` are one line break each. A BOM and a lone surrogate are one code
point of three bytes each.

## Library Dependencies

Treat `moonbitlang/core`, `moonbitlang/x` and `moonbitlang/async` as the
MoonBit core library; look there before adding a helper or a dependency.
Library code (`src/**`) may use packages owned by `moonrockz`,
`moonbitlang` and `moonbit-community`, plus the module's own packages; any
other owner needs a decision recorded here. The published `moon.mod`
imports `moonrockz/expect` (used by the packages' own tests),
`moonbit-community/toml` (the configuration file), `moonbitlang/x`
(`fs`, for `Config::load`) and `moonrockz/pretty` (the document engine of
the formatter); it brings `moonbitlang/async` and `bobzhang/lexer` to
users, which is accepted.

Test-only dependencies (`moonrockz/moonspec`, `moonbitlang/async`,
`moonbitlang/x`) live in the unpublished workspace module `tests/`
(`moonrockz/gleam_parser_tests`). Its tests run with `tests/` as the working
directory, so repository files are `../moon.mod`, `../.corpus`; data in the
module is `features/...`, `corpus/...`. `.moonignore` keeps everything but
`src/` and the READMEs out of the published package.

The module name has a hyphen, so every importer of the root package gives it
an alias in `moon.pkg`: `"moonrockz/gleam-parser" @gleam`. The root
package's own black-box tests import it the same way (`for "test"`).

### Toolchain

- Targets: wasm, wasm-gc, js and native (`mise run test:targets`, CI job
  `targets`). llvm is left out because the toolchain does not ship
  `moonbitlang/core` for it.
- The MoonBit toolchain version is pinned in `.github/workflows/*.yml`
  (`MOONBIT_VERSION`). Keep your local toolchain on the same version
  (`moon version --all`, `moon upgrade`).
- To upgrade: `moon upgrade`, bump `MOONBIT_VERSION`, bump the `import`
  versions in `moon.mod`, `tests/moon.mod`, `docs/cookbook/moon.mod` and the
  pinned imports in `scripts/*.mbtx`, then `moon update && moon check && mise
  run test`. Fix all new warnings, not only errors.
- Use `derive(Debug)` (not `derive(Show)`) for data types. `assert_eq`
  requires `Debug`. Implement `Show` by hand only for real text formats.

## Project Structure

- MoonBit packages are organized per directory; each has a `moon.pkg` listing dependencies.
- Blackbox tests: `*_test.mbt`; whitebox tests: `*_wbtest.mbt`. In blackbox tests,
  qualify names from the package under test (for example `@scanner.TokenKind`).
- Top-level `moon.mod` describes the module and metadata (the legacy `moon.mod.json`
  format is deprecated).

## Design Philosophy

This project follows **functional design principles** (aligned with moonrockz/gherkin and moonrockz/cucumber-expressions):

- **Algebraic data types (ADTs)** for domain concepts (enums + structs).
- **Make invalid states unrepresentable** — use the type system to prevent illegal states.
- **Avoid primitive obsession** — use domain types (e.g. `Token`, `Span`) instead of raw strings/ints.
- **Prefer immutability** — minimal `mut`; favor returning new values.
- **Pattern matching over conditionals** — exhaustive `match` on enums.
- **Total functions** — use `Option`/`Result` or typed `raise` for failures; avoid panic.

Visitor and AST design will aim for **flexibility** similar to moonrockz/gherkin (multiple traversal styles, composable visitors).

## Test-Driven Development (TDD)

- **Red–Green–Refactor**: Write a failing test first, then minimal implementation, then refactor.
- Use `#declaration_only` to sketch public APIs before implementation.
- Specify behavior as Gherkin features run by
  [moonrockz/moonspec](https://mooncakes.io/docs/moonrockz/moonspec)
  (`tests/features/` for the library, `scripts/features/` for scripts).
- Write assertions with [moonrockz/expect](https://mooncakes.io/docs/moonrockz/expect):
  `@expect.expect(actual).to_equal(expected)`, `.to_be_true()`, `.to_contain(...)`.
- Use soft assertions when a test or a step checks more than one fact: put the
  checks in one `@expect.expect_all(s => { ... })` block and write
  `s.expect(...)`, so a failure reports every failed check at once. Keep a
  precondition hard: a check that later code depends on uses
  `@expect.expect(...)` or `guard ... else { fail(...) }`. A single assertion
  needs no block, and a law returns a `Bool` instead. Use `inspect(...)` for
  snapshot tests.
- Gherkin `{string}` parameters keep backslash escapes literally; a step that
  needs a real line break unescapes `\\n` and `\\r` itself.
- Run `mise run test:unit` for tests; `moon test --update` to refresh snapshots.

### Property-Based Testing (Laws)

Property-based tests supplement the example tests and features; they state
**laws**: rules that hold for every input, checked against many generated
inputs.

- **When to write laws.** For every new type, feature or capability, ask which
  laws it must obey, and write them down in the plan next to the example
  tests: invariants (every child's span lies inside its parent's), round
  trips (decode after encode gives the value back), equivalences (two APIs
  give the same result), algebraic rules (identity, idempotence,
  associativity), and models (a small reference implementation agrees with
  the real one).
- **Tooling.** `moonbitlang/core/quickcheck` (import it and
  `moonbitlang/core/quickcheck/splitmix` for `"test"` only). Check a law with
  `@quickcheck.check(law, count=…, max_size=…, seed=…)`. Always set `seed`.
- **Generators.** Wrap the value in a newtype and implement
  `@quickcheck.Arbitrary` (and `@quickcheck.Shrink`). Shared generators are
  `pub` types in `src/lawkit`: `Units` (any UTF-16 text: surrogates, `\r`,
  CRLF, BOM), `edge_chars()`, `GleamText` (any text: token pieces, broken
  fragments, edge characters in literal and comment forms, cuts of a small
  module; shrinks) and `GleamTokens` (valid token sequences with their kind
  names), `GleamAst` (random ASTs with every node kind, for the JSON
  round-trip laws), `GleamModule` (valid modules: every definition kind,
  attribute, expression, statement, pattern, guard and type form, no
  deprecated syntax; shrinks by dropping a definition) and
  `Construct`/`nested(construct, depth)` (each nesting construct at any
  depth); later plans add `Commented` and `Spaced`. Keep generated depth
  bounded by `size`, so generators do not overflow the stack on wasm.
- **Valid input fails loudly.** A generator of valid input makes the law fail
  on any diagnostic, never skip the case. Generate arbitrary text only for
  laws that must hold for any text (never crash; a diagnostic instead).
- **Name laws as laws.** Test names start with `law:` and state the rule.
- **Boundary values.** A law lists its edge values and its generator reaches
  them: none, one and many; equal, nested, adjacent and empty spans; the start
  and end of every span, one byte before each; line and file ends; non-ASCII
  text (surrogate pairs, lone surrogates); limits ± 1.
- **Reach the success branch.** A law that returns `true` on an error tests
  nothing for inputs that fail; measure how often the generator reaches the
  success branch.
- **Enumerate small edge products** in one example test with soft assertions
  instead of sampling.
- **Corpus as a law check.** A law that holds for generated input also holds
  for the pinned corpus; add it to the parity check where it is cheap.
- **Run on every target.** Laws run in `mise run test:unit` and `mise run
  test:targets`. Keep `count` and `max_size` small enough that a package's
  tests stay fast.

## Documentation

Two kinds of user documentation, both tested:

- **API reference**: `///` doc comments on public items, shown on
  mooncakes.io. The first line says what the item does; then the details a
  user needs (defaults, edge cases, errors). Entry points and items whose use
  is not obvious get an example in a fenced block with the info string
  `mbt check` that holds a `test { ... }`. `moon test` runs these examples as
  black-box tests of the package, so refer to the package by its alias
  (`@gleam.version`). Use `debug_inspect` for `derive(Debug)` values. A doc
  comment block can hold only `test` blocks: with a `struct` or `impl` in it,
  moon skips the block (warning 4191). For such an example, use a block with
  the info string `mbt nocheck`, check it once in a scratch test, and point
  to a tested example (a cookbook article, by its GitHub URL). When you
  add or change a public item, update its doc comment and example.
- **Cookbook** (`docs/cookbook/`): one article per user task
  (`<slug>.mbt.md`), indexed in `docs/cookbook/README.md`. The directory is
  the unpublished workspace module `moonrockz/gleam_parser_cookbook` with one
  package; `mise run test:docs` runs every `mbt check` block (CI job
  `unit-tests`). All articles share one namespace, so prefix each article's
  top-level names (`gs_`, …). Use an `mbt nocheck` block only
  for code that cannot run as a test, such as a `main` that writes a file.
- `README.mbt.md` is the mooncakes.io landing page. It is not in a package,
  so its examples are not run: keep them short and copy them from tested
  code.
- Write documentation in ASD-STE100 Simplified Technical English: short
  sentences, active voice, one word for one meaning.

## Coding Convention

- MoonBit block style: blocks separated by `///|`; block order irrelevant.
- Deprecated code in `deprecated.mbt` per directory.

## Conventional Commits

All commits MUST use **[Conventional Commits](https://www.conventionalcommits.org)**:

```
type(scope): description
```

Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `style`.
Breaking changes: add `!` after type (e.g. `feat(parser)!: change return type`).
Also add a `BREAKING CHANGE: <what breaks and how to migrate>` footer (Conventional
Commits 1.0.0; `BREAKING-CHANGE:` works too). git-cliff writes the footer text as the
changelog's breaking-change line; without it the line repeats the subject. For a
squash merge, put the footer in the squash commit body
(`gh pr merge --squash --body $'…\n\nBREAKING CHANGE: …'`).
`mise run release:prepare` warns about breaking commits without the footer.

Scopes (examples): `scanner`, `parser`, `ast`, `cst`, `dialect`, `report`, `span`, `diagnostic`, `ci`, `build`.

## Mise Tasks

All operations use **file-based mise tasks** in `mise-tasks/`. Do not add inline `[tasks]` to `.mise.toml`.

| Task | Purpose |
|------|---------|
| `hooks:install` | Install project git hooks via lefthook |
| `info:generate` | Run `moon info` to generate interfaces |
| `lint:check` | `moon check` |
| `format:check` | `moon fmt --check` (also `scripts/*.mbtx`) |
| `check` | info + lint + format + tests |
| `test:unit` | MoonBit unit tests of the library packages |
| `test:bdd` | MoonSpec features (`tests/bdd`) |
| `test:scripts` | Script tests (`scripts/*.mbtx`) |
| `test:docs` | Cookbook articles |
| `test:targets` | Check and test the library on wasm, wasm-gc, js and native |
| `test` | unit + bdd + scripts + rejection + docs |
| `oracle:build` | Build the Rust AST oracle (`tools/gleam-ast-oracle`; needs cargo; local only) |
| `fixtures:record` | Record the oracle's JSON for `tests/fixtures/ast/*.gleam` (needs `oracle:build`) |
| `corpus:manifest` | Rebuild `tests/corpus/manifest.json` from `packages.txt` (downloads every package) |
| `corpus:fetch` | Download and verify the pinned corpus into `.corpus/` |
| `corpus:goldens` | Run the oracle over the corpus and write `goldens.lock` (needs cargo; local only) |
| `test:parity` | Score Gleam parity against the lock (needs `corpus:fetch`) |
| `parity:ratchet` | Raise `tests/corpus/baseline.json` to the current counts |
| `rejection:record` | Record the compiler's verdicts for `tests/rejection` (needs cargo; local only) |
| `test:rejection` | Check verdicts, first errors and message snapshots against `verdicts.json` |
| `formatter:cases` | Extract the compiler's formatter test cases into `tests/fixtures/format` (needs a Gleam checkout, default `.dev/gleam`; local only) |
| `formatter:record` | Record `gleam format`'s output for the fixtures and `tests/corpus/format.lock` (needs the `gleam` binary via mise aqua and `corpus:fetch`; local only) |
| `test:format` | Score format parity against the fixtures and the lock; fail below `tests/format/baseline.json` |
| `formatter:ratchet` | Raise `tests/format/baseline.json` to the current counts |
| `coverage:ci-gate`, `coverage:ci-warn` | Coverage threshold (80) |
| `release:prepare`, `release:version`, `release:plan`, `release:notes`, `release:refresh`, `release:status`, `release:credentials`, `release:publish` | Release process (see Release Process) |

## Scripts

Project tooling logic is written in MoonBit, not bash, `jq` or `awk`.

- Put tooling logic in standalone scripts: `scripts/<name>.mbtx`.
- Keep each mise task a one-line launcher:
  `exec moon run -q --target wasm scripts/<name>.mbtx -- <args>`.
  `-q` hides dependency manifest warnings; errors and output still show.
  Do not use `moonx`; the CI toolchain does not include it.
- In a script, put logic in pure functions. `async fn main` does only I/O.
- Specify each script's behavior in `scripts/features/<name>.feature`. The script
  runs its feature with moonspec from an `async test`; `moon test` runs with
  `scripts/` as the working directory, so load `features/<name>.feature`.
- Pin module imports in each script (`moonbitlang/async@<version>`,
  `moonbitlang/x@<version>/sys`, `moonrockz/moonspec@<version>`,
  `moonrockz/expect@<version>`) to the versions used by the module.
- Test the scripts with `mise run test:scripts`. `moon test` and `moon fmt`
  handle a `.mbtx` file only when you give its path.
- Do not add new logic to bash task files. A task that calls one `moon`
  command can stay bash.

| Script | Task | Purpose |
|--------|------|---------|
| `scripts/coverage.mbtx` | `coverage:ci-gate`, `coverage:ci-warn` | Coverage summary and threshold |
| `scripts/credentials.mbtx` | `release:credentials` | Write mooncakes.io credentials (CI only) |
| `scripts/release.mbtx` | `release:prepare`, `release:version`, `release:plan`, `release:notes`, `release:refresh`, `release:status` | Release pull request, next version, release decision in CI, release notes, pull request body, release health check |
| `scripts/publish.mbtx` | `release:publish` | Publish to mooncakes.io; a release tag must match `moon.mod`'s version; an already published version (a second run for the tag) succeeds |
| `scripts/hooks_install.mbtx` | `hooks:install` | Install lefthook hooks |
| `scripts/fixtures.mbtx` | `fixtures:record` | Run the oracle over the AST fixtures and write their `.json` |
| `scripts/corpus.mbtx` | `corpus:manifest`, `corpus:fetch` | Pin (Hex metadata, GitHub tag archives), download and verify the parity corpus |
| `scripts/goldens.mbtx` | `corpus:goldens` | Run the oracle over the corpus; one raw result per file |
| `scripts/rejection.mbtx` | `rejection:record` | Record the oracle's verdict per rejection fixture |
| `scripts/format_cases.mbtx` | `formatter:cases` | Decode the `assert_format!` and `assert_format_rewrite!` inputs of the compiler's tests into fixtures |
| `scripts/formatted.mbtx` | `formatter:record` | Run `gleam format --stdin` over the fixtures and the corpus; write the outputs and the lock |

## Gleam Parity

gleam-parser measures parity with the Gleam compiler (gleam-core v1.19.2, the
version in `tests/corpus/gleam_version.txt`) on a pinned corpus of 25
published packages (233 files under `src/` and `test/`).

- `tests/corpus/packages.txt` lists the packages as `name@version`, with an
  optional `github.com/owner/repo#tag` when the Hex metadata has no GitHub
  link or the tag is not `v<version>`. `manifest.json` pins each tag archive
  (SHA-1) and each `.gleam` file (SHA-256).
- `tests/corpus/goldens.lock` holds, per file, the SHA-256 of the canonical
  oracle JSON, or, for a file the compiler rejects, its first error as
  `PARSE_ERROR:<kind>:<lexical kind or ->:<start>:<end>` (such a file matches
  when gleam-parser's first error has that kind, lexical kind and location).
  Only hashes are committed; the raw oracle output stays local in
  `.dev/out/goldens/raw/`.
- `mise run test:parity` prints the scoreboard: files, tokenized (no lexical
  error), parsed (no error diagnostic), matched (the canonical JSON of
  `ParseResult::parsed()` hashes to the golden). It fails when a count drops
  below `tests/corpus/baseline.json`. CI runs it in the `parity` job. It also
  runs the corpus laws: the lossless scan and parse with LF and with CRLF, the
  JSON round trip, and the never-crash laws on prefixes cut at token
  boundaries (every boundary, or 50 evenly spaced ones per file).
- Reports go to `_build/reports/parity/`: `parity.html` (filter by status),
  `parity.json`, `parity.xml` (JUnit: one testsuite per package; unmatched
  files are `skipped`, only a baseline regression is a `failure`) and
  `summary.md` (the CI job summary). CI uploads them as the `parity-report`
  artifact.
- When a change raises the counts, run `mise run parity:ratchet` and commit
  `baseline.json`.
- To see why a file does not match, run `mise run corpus:goldens` once (needs
  cargo), then `mise run test:parity`: it prints the first differing JSON path
  and both values for up to 20 files.
- To add a package: add it to `packages.txt`, run `mise run corpus:manifest`,
  then `mise run corpus:goldens`, then `mise run parity:ratchet`; commit the
  manifest, the lock and the baseline.
- To move to a new Gleam version: change the tag in
  `tools/gleam-ast-oracle/Cargo.toml` and `tests/corpus/gleam_version.txt`
  (a test checks they agree), port the compiler changes (`src/ast`,
  `src/parser`, `src/syntax/children.mbt`), then
  `mise run fixtures:record`, `mise run corpus:goldens`,
  `mise run rejection:record` and `mise run parity:ratchet`.

## Rejection Parity

gleam-parser checks which Gleam source it accepts and rejects, and its first
error, against the compiler (the oracle).

- `tests/rejection/<group>/<case>.gleam` are small modules. A negative
  fixture has one syntax problem and is valid otherwise. The oracle decides
  the verdict: three fixtures written as rejections (`definitions/fn_no_body`,
  `expressions/block_ends_with_let`, `expressions/case_without_clauses`) are
  accepted by the parser; the compiler reports them in a later phase.
- `mise run rejection:record` (needs cargo) runs the oracle on every fixture
  and writes `tests/rejection/verdicts.json`: the fixture's SHA-256 and, under
  `gleam-<version>`, `accepted` or the first error's kind, lexical kind and
  location. CI never runs the oracle.
- `mise run test:rejection` parses each fixture in `gleam-1.19`. gleam-parser
  accepts a file when it gives no diagnostic with severity `Error`. The
  checks are `verdict` (accept against reject) and `error` (both reject: the
  first error's kind, lexical kind and location must equal the oracle's). A
  changed fixture fails with "run `mise run rejection:record`".
- `tests/rejection/messages/<fixture>.txt` holds gleam-parser's rendered
  message (`render_plain`) for every fixture it rejects. A changed, missing or
  stale message fails the check. Review the messages, then run
  `GLEAM_REJECTION_MODE=approve mise run test:rejection`; the pull request
  diff is the review.
- `test:rejection` writes `_build/reports/rejection/index.html`: per fixture,
  the compiler's and gleam-parser's verdicts and first errors side by side.
  CI uploads it as the `rejection-report` artifact.
- `tests/rejection/pending.json` lists the fixture and check pairs that do not
  match yet. The list only shrinks: the check fails on a mismatch that is not
  listed and on a listed pair that now matches (remove it).
  `GLEAM_REJECTION_MODE=write-pending` rewrites the list; use it only when
  adding fixtures. The one expected entry is `nesting/too_deep.gleam`
  (`verdict`): the compiler has no nesting limit.

## Format Parity

gleam-parser checks `format` against `gleam format` 1.19.2.

- `tests/fixtures/format/<suite>/<nnn>.gleam` are the inputs of the
  compiler's formatter tests (`format/src/tests.rs` is suite `tests`,
  `format/src/tests/<suite>.rs` the others; `<nnn>` is the case's 1-based
  index among the real cases of the file; a commented-out macro and the one
  `format!` case are skipped). `<nnn>.formatted.gleam` is the binary's
  output. `NOTICE` carries the Apache-2.0 attribution. `mise run
  formatter:cases` extracts them from a checkout at the pinned tag (`git
  clone --depth 1 --branch v1.19.2 https://github.com/gleam-lang/gleam
  .dev/gleam`); `mise run formatter:record` records the outputs with the
  binary (`mise x aqua:gleam-lang/gleam@<version>`), and writes
  `tests/corpus/format.lock` (`<corpus key> <sha256 of the output>` or
  `FORMAT_ERROR`). Both run locally only.
- `mise run test:format` (`tests/format`, `GLEAM_FORMAT_MODE=check`) scores
  `fixtures`, `fixtures_matched`, `corpus` and `corpus_matched` (the corpus
  part needs `corpus:fetch`) and fails when a matched count drops below
  `tests/format/baseline.json`. `mise run formatter:ratchet` raises the
  baseline. Reports go to `_build/reports/format/` (`summary.md`,
  `format.json`, `format.html`); for up to 20 unmatched files the summary
  shows the first differing line. CI runs it in the `parity` job and uploads
  `format-report`.
- The baseline is 893/893 fixtures and 233/233 corpus files: every mismatch
  is a regression. A new mismatch is a port bug; fix it against
  `format/src/lib.rs` with a test whose expectation comes from the binary.

## Tooling

- `moon fmt` — format code.
- `moon info` — update generated `.mbti` interface.
- `moon check` — typecheck.
- Run `moon info && moon fmt` before committing when API or formatting may have changed.

## The `.dev/` Working Area

`.dev/` is a gitignored scratch area for AI-assisted development: temporary scripts, agent and
script outputs, and working documents. Nothing in it is committed. Layout:

- Specs from the superpowers `brainstorming` skill: `.dev/docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- Plans from the superpowers `writing-plans` skill: `.dev/docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md`
- Scratch scripts and their outputs: `.dev/scripts/`, `.dev/out/`

This layout overrides the default location of any skill or tool. Never place specs, plans or
other working documents under `docs/`, and never `git add` anything under `.dev/`. When a
design is final and meant for readers, write it up in a committed location on purpose.

## Release Process

- Publishes to **mooncakes.io** and **GitHub Releases**, and records every release in
  `CHANGELOG.md`.
- The release-manager skill (`.claude/skills/release-manager/`) walks an agent through
  a release, troubleshooting (`TROUBLESHOOTING.md`) and improving the process after
  each release. Agents other than Claude Code can read its `SKILL.md` directly.
- `mise run release:status` checks that main, the tags, the GitHub release and
  mooncakes.io agree; each problem it prints names the command that fixes it.
- To release, run `mise run release:prepare` on a clean working tree. It fetches
  `origin/main`, computes the next version with git-cliff (pinned in `.mise.toml`,
  configured in `cliff.toml`; on 0.x a `feat` or a breaking change bumps the minor,
  anything else the patch), sets `version` in `moon.mod`, prepends the version's
  section to `CHANGELOG.md`, commits `chore(release): v<version>` on branch
  `release/v<version>`, pushes it and opens the pull request. It also sets the
  string that `version()` in `src/lib.mbt` returns; `tests/bdd/version_wbtest.mbt`
  checks that it equals `moon.mod`'s version. Give a version to
  override git-cliff (`mise run release:prepare 1.0.0`); `--local` stops before the
  push.
- `prepare` warns about breaking commits (`!`) without a `BREAKING CHANGE:` footer
  and lists them in the pull request body. Rewrite each such line under "Breaking
  changes" in `CHANGELOG.md`.
- In the pull request, replace the highlights comment at the top of the new section
  with a few sentences on what the release brings, and reword the generated lines
  where needed. Push, then run `mise run release:refresh` on the release branch: it
  writes the new notes into the pull request body. Then merge. Do not bump the
  version in any other pull request.
- Merge the release pull request before other pull requests. A pull request that
  merges first is not in the new section and goes into no later section either (the
  tag covers it). If that happens, close the release pull request, delete its branch
  and run `mise run release:prepare` again.
- The merge changes `moon.mod` on `main`, so the Release workflow runs:
  - `plan` (`mise run release:plan`) releases when `v<version>` has no tag yet and
    `CHANGELOG.md` has the version's section with its highlights written; otherwise
    it skips, or fails when the section is missing or still has the highlights
    placeholder.
  - `validate` runs `moon fmt`, `moon check`, `mise run test:unit` and
    `mise run test:scripts`; `publish` publishes to mooncakes.io (needs the
    `MOONCAKES_USER_TOKEN` org secret).
  - `release` creates the tag on the merge commit and the GitHub release. Its notes
    (`mise run release:notes <version>`) are an install line followed by the
    changelog section: highlights, breaking changes, grouped changes with PR links
    and authors, and the compare link.
- A pushed `v*` tag (it must match `moon.mod`'s version) and a manual run also work.
- A release run is safe to repeat: release runs never overlap (a concurrency group),
  an already published version and an existing GitHub release are skipped. The tag is
  created with `GITHUB_TOKEN`, which starts no second run.
- Write commit and pull request titles for the changelog: the squash-merge title is
  the changelog line. `chore(release)` and `chore(beads)` commits are left out.

## Work Tracking

**bd (beads) is the primary tracker for all work.** GitHub Issues are the
public intake for reports from outside contributors.

- Track every task, bug, feature and epic in bd. Do NOT use markdown TODO
  lists or other tracking methods.
- Mirror each GitHub issue into bd with `--external-ref gh-<number>`, and keep
  the two in step: when the bd issue closes, close the GitHub issue.
- A pull request that resolves a GitHub issue says `Closes #<number>` in its
  body. Name the bd issue in the body too.
- Work lands on `main` through pull requests (squash merge). Branch first;
  do not push to `main` unless the user says so for that change.
- bd runs with `agent.profile: team-maintainer` (`.beads/config.yaml`):
  commit, `bd sync` and push are routine parts of the work. An explicit
  "do not commit" or "do not push" from the user still wins, and pushes go to
  your branch, not to `main`.

## Persistent Memory

Store knowledge that must outlive the session with `bd remember`. Do not use
`MEMORY.md` files or any agent's own memory store for this project; bd
memories sync through `refs/dolt/data`, so every machine and agent sees them.

```bash
bd remember "insight" --key <slug>   # store, or update the memory with that key
bd memories <keyword>                # search
bd recall <key>                      # read one
```

`bd prime` (the SessionStart hook) injects the memories into each session.

<!-- BEGIN BEADS INTEGRATION -->

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT
use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: syncs through a Dolt remote on the Git origin
  (`refs/dolt/data`), separate from source branches
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:gleam-parser-123 --json
bd create "Issue title" --description="..." --external-ref gh-12 --json   # mirror a GitHub issue
```

**Claim and update:**

```bash
bd update gleam-parser-42 --status in_progress --json
bd update gleam-parser-42 --priority 1 --json
```

**Complete work:**

```bash
bd close gleam-parser-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Storage and Sync

- bd stores issues in an embedded Dolt database at `.beads/embeddeddolt/`
  (not committed).
- Git worktrees share the database of the main checkout. Do not create a
  database inside a worktree.
- Cross-machine sync uses a Dolt remote on the GitHub origin. Dolt keeps issue
  history under `refs/dolt/data`, separate from source branches:
  - `bd sync` — pull, check for conflicts, and push in one step.
  - `bd dolt pull` / `bd dolt push` — the individual steps.
- Issue changes need no commit or pull request: `bd sync` publishes them to
  `refs/dolt/data`.
- `.beads/issues.jsonl` is a passive export (`bd export -o .beads/issues.jsonl`)
  for viewers and interchange. It is gitignored; do not commit it.

### Setup on a Fresh Clone

```bash
bd bootstrap            # clones refs/dolt/data from origin and wires the Dolt remote
mise run hooks:install  # installs lefthook git hooks (these call `bd hooks run <hook>`)
git config beads.role maintainer   # or contributor
```

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT duplicate tracking systems (GitHub issues are mirrored, not tracked twice)

<!-- END BEADS INTEGRATION -->

## Landing the Plane (Session Completion)

When you end a work session, complete ALL steps below. Work is NOT complete
until the pushes succeed.

1. **File issues for remaining work** in bd.
2. **Run quality gates** if code changed: `mise run check`,
   `moon info && moon fmt`.
3. **Update issue status**: close finished work, update in-progress items.
4. **Push** (mandatory):
   ```bash
   bd sync                  # publish issue changes to refs/dolt/data
   git pull --rebase
   git push                 # your branch; open or update its pull request
   git status               # MUST show "up to date with origin"
   ```
5. **Clean up**: clear stashes, prune merged branches.
6. **Hand off**: give context for the next session.

Never stop before pushing; that leaves work stranded on one machine. If a push
fails, resolve the cause and retry.
