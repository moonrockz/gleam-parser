///|
/// The version of gleam-parser, the same as `version` in `moon.mod`.
/// `mise run release:prepare` rewrites the string below; `tests/bdd`
/// checks that it equals `moon.mod`.
///
/// ```mbt check
/// test {
///   inspect(@gleam.version().split(".").count(), content="3")
/// }
/// ```
pub fn version() -> String {
  "0.0.1"
}

///|
/// Spans (UTF-8 byte offsets) and positions (1-based line and column).
pub using @span {type SrcSpan, type Position}

///|
/// Source text with byte, UTF-16 and line/column lookups.
pub using @scanner {type SourceText}

///|
/// Diagnostics: severity, labels and the problem record.
pub using @diagnostic {type Severity, type Label, type Diagnostic}

///|
/// The one-line description of a diagnostic code (`GL-SCAN-001`, …), or
/// `None` for an unknown code. The table is in AGENTS.md > Diagnostics.
pub fn diagnostic_description(code : String) -> String? {
  @diagnostic.description(code)
}

///|
/// The scanner: tokens, trivia and lexical errors.
pub using @scanner {
  type TokenStream,
  type Token,
  type TokenKind,
  type Keyword,
  type Trivia,
  type Comment,
  type CommentKind,
  type LexicalErrorType,
  type UnicodeEscapeError,
}

///|
/// Scan `source` into tokens with trivia and diagnostics. The scan is
/// lossless: `TokenStream::to_source()` is the text.
pub fn tokenize(source : SourceText) -> TokenStream {
  @scanner.tokenize(source)
}

///|
/// `tokenize` of a `SourceText` built from `text`.
pub fn tokenize_text(text : String) -> TokenStream {
  @scanner.tokenize_text(text)
}

///|
/// The number an `Int` literal denotes (sign, radix prefix, `_` separators).
pub fn parse_int_value(value : String) -> BigInt? {
  @scanner.parse_int_value(value)
}

///|
/// The number a `Float` literal denotes (`1.`, `1.e3`, `1.0e-3`, `_`).
pub fn parse_float_value(value : String) -> Double? {
  @scanner.parse_float_value(value)
}

///|
/// The AST: a mirror of the Gleam compiler's untyped AST (v1.19.2), with
/// canonical JSON (`docs/ast-json.md`).
pub using @ast {
  type Parsed,
  type Module,
  type TargetedDefinition,
  type Target,
  type Definition,
  type SpannedString,
  type Documentation,
  type External,
  type Publicity,
  type Deprecation,
  type Function,
  type Arg,
  type ArgNames,
  type Import,
  type ImportAlias,
  type AssignName,
  type UnqualifiedImport,
  type ModuleConstant,
  type CustomType,
  type RecordConstructor,
  type RecordConstructorArg,
  type TypeAlias,
  type TypeAst,
  type TypeAstConstructor,
  type TypeAstConstructorName,
  type TypeAstFn,
  type TypeAstVar,
  type TypeAstTuple,
  type TypeAstHole,
  type Statement,
  type Assignment,
  type AssignmentKind,
  type Use,
  type UseAssignment,
  type Assert,
  type Expr,
  type FunctionLiteralKind,
  type CallArg,
  type ImplicitCallArgOrigin,
  type BinOp,
  type Clause,
  type ClauseGuard,
  type Pattern,
  type TailPattern,
  type StringPrefixLeftSideAssignment,
  type BitArraySize,
  type IntOperator,
  type BitArraySegment,
  type BitArrayOption,
  type TodoKind,
  type RecordBeingUpdated,
  type RecordUpdateArg,
  type Constant,
  type ModuleExtra,
  type Warning,
  type OracleOutput,
  type DecodeError,
}

///|
/// Canonical JSON text of an encoded AST value (sorted keys, no whitespace).
pub fn canonical(json : Json) -> String {
  @ast.canonical(json)
}

///|
pub fn encode_parsed(p : Parsed) -> Json {
  @ast.encode_parsed(p)
}

///|
pub fn decode_parsed(json : Json) -> Parsed raise DecodeError {
  @ast.decode_parsed(json)
}

///|
pub fn encode_oracle_output(o : OracleOutput) -> Json {
  @ast.encode_oracle_output(o)
}

///|
pub fn decode_oracle_output(json : Json) -> OracleOutput raise DecodeError {
  @ast.decode_oracle_output(json)
}

///|
pub fn encode_expr(e : Expr) -> Json {
  @ast.encode_expr(e)
}

///|
pub fn decode_expr(json : Json) -> Expr raise DecodeError {
  @ast.decode_expr(json)
}
