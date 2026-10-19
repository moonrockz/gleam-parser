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
  "0.4.0"
}

///|
/// Spans (UTF-8 byte offsets) and positions (1-based line and column).
pub using @span {
  type SrcSpan,
  type Position,
  type ByteOffset,
  type Utf16Offset,
  type ByteLength,
  type LineNumber,
  type LineCount,
  type ColumnNumber,
  type CoordinateError,
}

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
  type CommentError,
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
  type TupleIndex,
  type BitArrayUnit,
  type InvalidBitArrayUnit,
}

///|
/// Canonical JSON text of an encoded AST value (sorted keys, no whitespace).
pub fn canonical(json : Json) -> String {
  @ast.canonical(json)
}

///|
/// Encode a module with its trivia positions and parse-time warnings.
/// Raise `ExportError` for extension targets; use `encode_extended` to retain them.
/// Use `canonical` to write the JSON in the oracle's key order.
///
/// ```mbt check
/// test {
///   let parsed = @gleam.parse_text("const x = 1").parsed()
///   assert_eq(@gleam.decode_parsed(@gleam.encode_parsed(parsed)), parsed)
/// }
/// ```
pub fn encode_parsed(p : Parsed) -> Json raise @ast.ExportError {
  @ast.encode_parsed(p)
}

///|
/// Decode a module with its trivia positions and parse-time warnings.
/// Raise `DecodeError` with the field path for malformed JSON values.
pub fn decode_parsed(json : Json) -> Parsed raise DecodeError {
  @ast.decode_parsed(json)
}

///|
/// Encode an oracle result, either a parsed module or its first error.
/// Raise `ExportError` if the parsed module contains extension targets.
pub fn encode_oracle_output(o : OracleOutput) -> Json raise @ast.ExportError {
  @ast.encode_oracle_output(o)
}

///|
/// Decode an oracle result, either a parsed module or its first error.
/// Raise `DecodeError` with the field path for malformed JSON values.
pub fn decode_oracle_output(json : Json) -> OracleOutput raise DecodeError {
  @ast.decode_oracle_output(json)
}

///|
/// Encode an expression as a tagged JSON object.
/// Write only a float's lexeme; the decoder derives its numeric value.
pub fn encode_expr(e : Expr) -> Json {
  @ast.encode_expr(e)
}

///|
/// Decode an expression from its tagged JSON object.
/// Raise `DecodeError` with the field path for malformed JSON values.
///
/// ```mbt check
/// test {
///   let value : @gleam.Expr = Var(
///     location=@gleam.SrcSpan::from_ints(0, 1).unwrap(),
///     name="x",
///   )
///   assert_eq(@gleam.decode_expr(@gleam.encode_expr(value)), value)
/// }
/// ```
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
/// Optional nesting policy: `NestingLimit::Unlimited` or `Limited(Budget)`.
/// A finite `Budget` is at least 1. `FuelExhausted` reports its operations.
pub using @fuel {
  type NestingLimit,
  type Budget,
  type InvalidBudget,
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
/// The default for a standalone `Fuel()`, 100 units.
/// `Config::default()` uses `NestingLimit::Unlimited`.
pub let default_budget : Budget = @fuel.default_budget

///|
/// The syntax tree (v0.2): a read-only node model (`NodeRef`), parent
/// links and positions (`Tree`), paths (`NodePath`) and seven traversals:
/// `walk`, `fold`, `reduce`, `Visitor` with `accept`, `EventReader`
/// (pull), `push_events` with `Handler` (push) and `TreeCursor`. Every
/// traversal uses an explicit stack, so no depth overflows and no fuel is
/// spent.
pub using @syntax {
  type NodeRef,
  type Control,
  type PathStep,
  type ChildIndex,
  type NodeDepth,
  type TraversalValueError,
  type NodePath,
  type Tree,
  trait Visitor,
  type Event,
  type EnterEvent,
  type LeaveEvent,
  trait EventSource,
  type EventReader,
  trait Handler,
  type TreeCursor,
}

///|
/// Visit every node below `root` in pre-order (see `@syntax.walk`).
///
/// ```mbt check
/// test {
///   let root = @gleam.NodeRef::of_result(
///     @gleam.parse_text("pub fn f(x) {\n  x\n}\n"),
///   )
///   let kinds = []
///   @gleam.walk(root, n => {
///     kinds.push(n.kind())
///     Continue
///   })
///   inspect(kinds.join(" "), content="module function arg expression var")
/// }
/// ```
pub fn walk(
  root : NodeRef,
  enter : (NodeRef) -> Control,
  leave~ : (NodeRef) -> Unit = _ => (),
) -> Unit {
  @syntax.walk(root, enter, leave~)
}

///|
/// Walk with an accumulator (see `@syntax.fold`).
pub fn[A] fold(
  root : NodeRef,
  init : A,
  enter : (A, NodeRef) -> (A, Control),
  leave~ : (A, NodeRef) -> A = (a, _) => a,
) -> A {
  @syntax.fold(root, init, enter, leave~)
}

///|
/// Reduce the tree to one value, bottom up (see `@syntax.reduce`).
pub fn[A] reduce(root : NodeRef, f : (NodeRef, ArrayView[A]) -> A) -> A {
  @syntax.reduce(root, f)
}

///|
/// `reduce` with each child's step next to its result (see
/// `@syntax.reduce_with_fields`).
pub fn[A] reduce_with_fields(
  root : NodeRef,
  f : (NodeRef, ArrayView[(PathStep, A)]) -> A,
) -> A {
  @syntax.reduce_with_fields(root, f)
}

///|
/// Walk with a `Visitor` (see `@syntax.accept`).
pub fn[V : Visitor] accept(root : NodeRef, visitor : V) -> Unit {
  @syntax.accept(root, visitor)
}

///|
/// Pull every event from `source` and push it to `handler` (see
/// `@syntax.push_events`).
pub fn[S : EventSource, H : Handler] push_events(
  source : S,
  handler : H,
) -> Unit {
  @syntax.push_events(source, handler)
}

///|
/// Every node type as (category, kind, fields) (see `@syntax.kind_table`).
pub fn kind_table() -> Array[(String, String, Array[String])] {
  @syntax.kind_table()
}

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
/// Format Gleam source as `gleam format` does (see `@format.format`):
/// 80 columns, two spaces of indentation, comments and empty lines kept.
/// Raises `ParseFailed` with the error diagnostics when the text has a
/// syntax error.
///
/// ```mbt check
/// test {
///   inspect(@gleam.format("const  x  =  1\n"), content="const x = 1\n")
/// }
/// ```
pub fn format(text : String, config? : Config) -> String raise FormatError {
  @format.format(text, config?)
}

///|
/// Format a parse result (see `@format.format_parsed`).
pub fn format_parsed(
  result : ParseResult,
  config? : Config,
) -> String raise FormatError {
  @format.format_parsed(result, config?)
}

///|
pub using @format {type FormatError}

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

///|
/// Validated source-language target registration. A target does not supply a backend.
pub using @target {type RegistrationError}

///|
/// A validated registry of source-language targets. Standard targets are always present.
pub type TargetRegistry = @target.Registry

///|
/// A validated extension name. Standard target names and aliases are reserved.
pub type TargetName = @target.Name

///|
/// Named optional registrations and the application's available-profile registry.
pub using @dialect {type Profile, type Profiles, type ProfileError}

///|
/// Generic bindings, checked standard export errors, and versioned extended documents.
pub using @ast {
  type ExternalBindings,
  type ExternalBinding,
  type BindingError,
  type ExportError,
  type Extended,
  type ExtendedError,
}

///|
/// Encode a parse result in the versioned extended JSON format. Record the
/// dialect, profile identities, and registry used to parse the source. This
/// preserves extension targets and bindings that compiler-compatible export rejects.
///
/// ```mbt check
/// test {
///   let orbit = @gleam.Target::extension("orbit")
///   let config = {
///     ..@gleam.Config::default(),
///     dialect: @gleam.Dialect::gleam_1_19().register_target(orbit),
///   }
///   let result = @gleam.parse_text("@target(orbit) const answer = 42", config~)
///   let document = @gleam.decode_extended(@gleam.encode_extended(result))
///   assert_eq(document.parsed, result.parsed())
/// }
/// ```
pub fn encode_extended(result : ParseResult) -> Json raise @ast.ExtendedError {
  @ast.encode_extended(
    @ast.Extended(
      result.parsed(),
      dialect=result.config.dialect.name,
      targets=result.config.dialect.targets,
      profiles=result.config.dialect.profiles.map(p => p.identity)[:],
    ),
  )
}

///|
/// Decode extended JSON with its embedded registry. No optional module is
/// loaded. Reject unsupported versions, invalid registrations, unknown target
/// references, and duplicate bindings with a source path in `DecodeError`.
pub fn decode_extended(json : Json) -> @ast.Extended raise DecodeError {
  @ast.decode_extended(json)
}
