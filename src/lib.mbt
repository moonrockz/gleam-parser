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
  "0.1.0"
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

///|
/// The parser: a module from tokens, with recovery per definition. A
/// `ParseResult` holds the AST (`module_`), `extra`, `warnings`, the `cst`
/// and the `diagnostics`; `ParseError` is what the snippet parsers raise.
pub using @parser {
  type ParseResult,
  type ParseError,
  type ParseErrorType,
  type IncorrectNamePosition,
  type ParseErrorDetails,
}

///|
/// Dialects: what the parser accepts (`Dialect::gleam_1_19()` is the
/// default) and the deprecation `Rule`s it warns about.
pub using @dialect {type Dialect, type Rule}

///|
/// Fuel: the recursion budget (`Budget`, at least 1; `default_budget` is
/// 100 units), the operation names an exhausted budget reports (`Spent`),
/// and the error `FuelExhausted`.
pub using @fuel {
  type Budget,
  type Operation,
  type Spent,
  type Fuel,
  type FuelExhausted,
}

///|
/// Configuration: `Config` (dialect, fuel) from defaults, a TOML text, the
/// environment and the caller, merged with `with_fallback`; `Config::load`
/// reads `gleam-parser.toml` and `GLEAM_PARSER_*`.
pub using @config {
  type Config,
  type Partial,
  type Source,
  type ConfigError,
  type Environment,
}

///|
/// The default fuel budget, 100 units (see `@fuel.default_budget`).
pub let default_budget : Budget = @fuel.default_budget

///|
/// The CST: every token grouped per definition (`ModuleCst::to_source()`
/// is the text byte for byte; a `Skipped` definition is a run the parser
/// reported and skipped).
pub using @cst {type ModuleCst, type DefinitionCst, type DefinitionKind}

///|
/// Parse a token stream into a module (see `@parser.parse_module`).
pub fn parse_module(stream : TokenStream, config? : Config) -> ParseResult {
  @parser.parse_module(stream, config?)
}

///|
/// Parse Gleam source text into a module, with recovery per definition.
/// `config` sets the dialect and the fuel budget; see `Config`.
///
/// ```mbt check
/// test {
///   let r = @gleam.parse_text("pub fn main() {\n  io.println(\"hi\")\n}\n")
///   inspect(r.module_.definitions.length(), content="1")
///   inspect(r.has_errors(), content="false")
/// }
/// ```
pub fn parse_text(text : String, config? : Config) -> ParseResult {
  @parser.parse_text(text, config?)
}

///|
/// Render a diagnostic as the Gleam compiler prints it (no colours).
pub fn render_plain(
  d : Diagnostic,
  source : SourceText,
  path : String,
) -> String {
  @report.render_plain(d, source, path)
}

///|
/// Render a diagnostic with ANSI colours.
pub fn render_terminal(
  d : Diagnostic,
  source : SourceText,
  path : String,
) -> String {
  @report.render_terminal(d, source, path)
}

///|
/// Diagnostics as JSON (gleam-parser's own shape).
pub fn encode_diagnostics(ds : ArrayView[Diagnostic]) -> Json {
  @report.encode_diagnostics(ds)
}
