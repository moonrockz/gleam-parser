# Changelog

All notable changes to `moonrockz/gleam-parser` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

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
