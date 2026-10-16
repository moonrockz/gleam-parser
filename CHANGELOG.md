# Changelog

All notable changes to `moonrockz/gleam-parser` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

## [0.3.0] - 2026-10-16

<!-- Highlights: replace this comment with a few sentences on what this release brings. -->

### ⚠️ Breaking changes

- *(ast)* @ast.max_depth, @parser.json_depth and @parser.definition_root_depth are removed; DecodeError no longer reports "nesting deeper than 150 levels"; a definition is no longer dropped for its JSON depth. ([#7](https://github.com/moonrockz/gleam-parser/pull/7))
- *(parser)* Parse_text(text, dialect?) and parse_module(stream, dialect?) take config? : Config instead; pass config={ ..Config::default(), dialect: d } to keep a custom dialect. The snippet parsers take config?. @parser.max_nesting is removed; the limit is Config.fuel (default 100 units). TooMuchNesting carries budget and spent. ([#8](https://github.com/moonrockz/gleam-parser/pull/8))

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
