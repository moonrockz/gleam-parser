# Changelog

All notable changes to `moonrockz/gleam-parser` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

## [0.5.0] - 2026-10-19

<!-- Highlights: replace this comment with a few sentences on what this release brings. -->

### ⚠️ Breaking changes

- *(dialect)* Replace Function and CustomType external fields with ([#25](https://github.com/moonrockz/gleam-parser/pull/25))

### 🚀 Features

- *(dialect)* [**breaking**] Support registered target profiles ([#25](https://github.com/moonrockz/gleam-parser/pull/25)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/gleam-parser/compare/v0.4.0...v0.5.0

## [0.4.0] - 2026-10-18

Parsing and formatting now accept deeply nested Gleam source without a default
nesting limit or growth of the machine stack. Callers can still set a finite
nesting budget. This release also validates source coordinates and AST indexes,
fixes Unicode diagnostic alignment and parser recovery metadata, and improves
the parity and rejection tooling. Custom dialect keyword lists now use typed
keywords and control which words the parser reserves. These API changes need
the migrations below.

### ⚠️ Breaking changes

- *(span)* Source coordinates, AST indexes, bit array units, path indexes and traversal depths use validated types. Replace raw integers with native constructors such as `ByteOffset(value)`, which raise typed errors, or named `from_*` factories, which return `Option`. `Position(line, column)` takes raw integers; `Position::at` takes validated coordinates. Span lengths return `Option`. Construct comments with `Comment(...)` or `Comment::from_parts` instead of struct literals. See the tested [source coordinates migration guide](https://github.com/moonrockz/gleam-parser/blob/v0.4.0/docs/cookbook/source-coordinates.mbt.md). ([#18](https://github.com/moonrockz/gleam-parser/pull/18))
- *(parser)* `Dialect.keywords` takes `ArrayView[Keyword]`. Replace strings in custom keyword lists with `Keyword` cases such as `Keyword::Echo`. Omitted keywords now parse as ordinary names. The default dialect reserves all compiler keywords. ([#19](https://github.com/moonrockz/gleam-parser/pull/19))
- *(parser)* `Config.fuel` is `NestingLimit`, and `Partial.fuel` is `Option[NestingLimit]`. Replace `fuel: budget` with `fuel: Limited(budget)` and `fuel: Some(budget)` with `fuel: Some(Limited(budget))`. The default is `Unlimited`. TOML `fuel = "unlimited"` and `GLEAM_PARSER_FUEL=unlimited` remove a fallback limit. See the tested [configuration guide](https://github.com/moonrockz/gleam-parser/blob/v0.4.0/docs/cookbook/configure.mbt.md). ([#20](https://github.com/moonrockz/gleam-parser/pull/20))

### 🚀 Features

- *(parser)* [**breaking**] Remove default nesting limits ([#20](https://github.com/moonrockz/gleam-parser/pull/20)) by @DamianReeves

### 🐛 Bug fixes

- *(ast)* Enforce decoder scalar constraints ([#17](https://github.com/moonrockz/gleam-parser/pull/17)) by @DamianReeves
- *(parser)* [**breaking**] Align Unicode diagnostics, discard failed-definition metadata and honor dialect keywords ([#19](https://github.com/moonrockz/gleam-parser/pull/19)) by @DamianReeves
- *(tooling)* Detect duplicate lock keys, preserve manifest overrides and clarify corpus recovery ([#22](https://github.com/moonrockz/gleam-parser/pull/22)) by @DamianReeves

### 🚜 Refactoring

- *(span)* [**breaking**] Validate coordinate and index domains ([#18](https://github.com/moonrockz/gleam-parser/pull/18)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/gleam-parser/compare/v0.3.0...v0.4.0

## [0.3.0] - 2026-10-16

This release adds the formatter and the syntax tree. `format(text)` writes
Gleam source as `gleam format` 1.19.2 does: all 893 of the compiler's
formatter test cases and all 233 files of the parity corpus format to the
binary's bytes, comments stay where the compiler keeps them, and a flat
chain of any length formats inside the parser's fuel budget. The syntax tree
(`src/syntax`) is a read-only node model over the AST with seven traversals,
byte-offset spans, JSON paths and a `Tree` that answers the parent, the path
and the node at an offset. The parser has a recursion budget (fuel) and a
`Config` read from defaults, `gleam-parser.toml`, the environment and the
caller; the JSON codec has no depth limit any more. The parse entry points
take `config?` instead of `dialect?`; see the breaking changes below.

### ⚠️ Breaking changes

- *(ast)* `@ast.max_depth`, `@parser.json_depth` and `@parser.definition_root_depth` are removed; `DecodeError` no longer reports "nesting deeper than 150 levels"; a definition is no longer dropped for its JSON depth. ([#7](https://github.com/moonrockz/gleam-parser/pull/7))
- *(parser)* `parse_text(text, dialect?)` and `parse_module(stream, dialect?)` take `config? : Config` instead; pass `config={ ..Config::default(), dialect: d }` to keep a custom dialect. The snippet parsers take `config?`. `@parser.max_nesting` is removed; the limit is `Config.fuel` (default 100 units). `TooMuchNesting` carries `budget` and `spent`. ([#8](https://github.com/moonrockz/gleam-parser/pull/8))

### 🚀 Features

- *(parser)* [**breaking**] Fuel-limited recursion and parser Config ([#8](https://github.com/moonrockz/gleam-parser/pull/8)) by @DamianReeves
- *(syntax)* Read-only node model and seven traversals (v0.2) ([#10](https://github.com/moonrockz/gleam-parser/pull/10)) by @DamianReeves
- *(format)* Formatter scaffold, fixtures, comments and definitions (v0.3 PR 1) ([#12](https://github.com/moonrockz/gleam-parser/pull/12)) by @DamianReeves
- *(format)* Expressions, statements, patterns, cases and guards (v0.3 PR 2) ([#13](https://github.com/moonrockz/gleam-parser/pull/13)) by @DamianReeves

### 🐛 Bug fixes

- *(config)* Name the file in a TOML error from load and keep the read error's text ([#9](https://github.com/moonrockz/gleam-parser/pull/9)) by @DamianReeves
- *(release)* Prepare uses v0.1.0 on a repository with no release tag ([#11](https://github.com/moonrockz/gleam-parser/pull/11)) by @DamianReeves

### 🚜 Refactoring

- *(ast)* [**breaking**] Iterative JSON codec ([#7](https://github.com/moonrockz/gleam-parser/pull/7)) by @DamianReeves

### 🧪 Testing

- *(format)* Laws, corpus laws, cookbook and scoreboard hardening (v0.3 PR 3) ([#14](https://github.com/moonrockz/gleam-parser/pull/14)) by @DamianReeves
- *(format)* Comment law at the hard positions inside expressions ([#15](https://github.com/moonrockz/gleam-parser/pull/15)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/gleam-parser/compare/v0.1.0...v0.3.0

## [0.1.0] - 2026-10-15

The first release of gleam-parser: a scanner, parser, AST, CST and
diagnostics for Gleam in MoonBit, measured against the Gleam compiler
v1.19.2. The scanner is lossless. The parser is a port of the compiler's
`parse.rs` with recovery per definition, and its AST equals the compiler's
byte for byte on every fixture and on all 233 files of a 25-package corpus.
Diagnostics render in the compiler's layout. The canonical JSON codec gives a
stable interchange form of the AST for tools such as morphir-moonbit.

### 🚀 Features

- Bootstrap the gleam-parser repository ([#1](https://github.com/moonrockz/gleam-parser/pull/1)) by @DamianReeves
- *(scanner)* Lossless Gleam scanner with the compiler's lexical errors ([#2](https://github.com/moonrockz/gleam-parser/pull/2)) by @DamianReeves
- *(ast)* Compiler-mirror AST, canonical JSON and the Rust oracle ([#3](https://github.com/moonrockz/gleam-parser/pull/3)) by @DamianReeves
- *(parser)* Recursive-descent parser with recovery, CST, dialect and the compiler's diagnostics layout ([#4](https://github.com/moonrockz/gleam-parser/pull/4)) by @DamianReeves
- *(parity)* Corpus parity and rejection parity against the Gleam compiler ([#5](https://github.com/moonrockz/gleam-parser/pull/5)) by @DamianReeves

### ⚙️ Maintenance

- Add repository base files by @DamianReeves
