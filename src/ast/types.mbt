// A mirror of the Gleam compiler's untyped AST at v1.19.2
// (compiler-core/src/ast.rs, ast/untyped.rs, ast/constant.rs,
// parse/extra.rs, warning.rs). Field names are the compiler's; analysis-only
// fields are left out (see AGENTS.md > AST). Every list is a read-only view.

///|
/// What the compiler's `parse_module` returns: the module, the trivia
/// positions (`ModuleExtra`) and the parse-time warnings.
pub(all) struct Parsed {
  module_ : Module
  extra : ModuleExtra
  warnings : ArrayView[Warning]
} derive(Eq, Debug)

///|
/// `Module<(), Vec<TargetedDefinition>>` without `name` and
/// `documentation`, which the parser leaves empty.
pub(all) struct Module {
  definitions : ArrayView[TargetedDefinition]
} derive(Eq, Debug)

///|
pub(all) struct TargetedDefinition {
  definition : Definition
  target : Target?
} derive(Eq, Debug)

///|
/// `build::Target`.
pub(all) enum Target {
  Erlang
  JavaScript
} derive(Eq, Debug, Hash)

///|
/// Return the target's JSON name, `erlang` or `javascript`.
pub fn Target::name(self : Target) -> String {
  match self {
    Erlang => "erlang"
    JavaScript => "javascript"
  }
}

///|
/// Read a target's JSON name. Return `None` for an unknown name.
pub fn Target::of(name : String) -> Target? {
  match name {
    "erlang" => Some(Erlang)
    "javascript" => Some(JavaScript)
    _ => None
  }
}

///|
pub(all) enum Definition {
  Function(Function)
  TypeAlias(TypeAlias)
  CustomType(CustomType)
  Import(Import)
  ModuleConstant(ModuleConstant)
} derive(Eq, Debug)

///|
/// `(SrcSpan, EcoString)`: a name with its span.
pub(all) struct SpannedString {
  location : @span.SrcSpan
  name : String
} derive(Eq, Debug)

///|
/// `(u32, EcoString)`: a doc comment's start byte and text.
pub(all) struct Documentation {
  start : @span.ByteOffset
  text : String
} derive(Eq, Debug)

///|
/// `(EcoString, EcoString, SrcSpan)`: an `@external(target, module,
/// function)` attribute.
pub(all) struct External {
  module_ : String
  function : String
  location : @span.SrcSpan
} derive(Eq, Debug)

///|
pub(all) enum Publicity {
  Public
  Private
  Internal(attribute_location~ : @span.SrcSpan?)
} derive(Eq, Debug)

///|
/// `type_::Deprecation`.
pub(all) enum Deprecation {
  NotDeprecated
  Deprecated(message~ : String)
} derive(Eq, Debug)

///|
pub(all) struct Function {
  location : @span.SrcSpan
  body_start : @span.ByteOffset?
  end_position : @span.ByteOffset
  name : SpannedString?
  arguments : ArrayView[Arg]
  body : ArrayView[Statement]
  publicity : Publicity
  deprecation : Deprecation
  return_annotation : TypeAst?
  documentation : Documentation?
  external_erlang : External?
  external_javascript : External?
} derive(Eq, Debug)

///|
pub(all) struct Arg {
  names : ArgNames
  location : @span.SrcSpan
  annotation : TypeAst?
} derive(Eq, Debug)

///|
pub(all) enum ArgNames {
  Discard(name~ : String, location~ : @span.SrcSpan)
  LabelledDiscard(
    label~ : String,
    label_location~ : @span.SrcSpan,
    name~ : String,
    name_location~ : @span.SrcSpan
  )
  Named(name~ : String, location~ : @span.SrcSpan)
  NamedLabelled(
    label~ : String,
    label_location~ : @span.SrcSpan,
    name~ : String,
    name_location~ : @span.SrcSpan
  )
} derive(Eq, Debug)

///|
pub(all) struct Import {
  documentation : String?
  location : @span.SrcSpan
  module_location : @span.SrcSpan
  module_ : String
  as_name : ImportAlias?
  unqualified_values : ArrayView[UnqualifiedImport]
  unqualified_types : ArrayView[UnqualifiedImport]
} derive(Eq, Debug)

///|
/// `(AssignName, SrcSpan)`.
pub(all) struct ImportAlias {
  name : AssignName
  location : @span.SrcSpan
} derive(Eq, Debug)

///|
pub(all) enum AssignName {
  Variable(String)
  Discard(String)
} derive(Eq, Debug)

///|
pub(all) struct UnqualifiedImport {
  location : @span.SrcSpan
  name : String
  name_position : @span.ByteOffset
  as_name : String?
} derive(Eq, Debug)

///|
pub(all) struct ModuleConstant {
  documentation : Documentation?
  location : @span.SrcSpan
  publicity : Publicity
  name : String
  name_location : @span.SrcSpan
  annotation : TypeAst?
  value : Constant
  deprecation : Deprecation
} derive(Eq, Debug)

///|
pub(all) struct CustomType {
  location : @span.SrcSpan
  end_position : @span.ByteOffset
  name : String
  name_location : @span.SrcSpan
  publicity : Publicity
  constructors : ArrayView[RecordConstructor]
  documentation : Documentation?
  deprecation : Deprecation
  opaque_ : Bool
  parameters : ArrayView[SpannedString]
  external_erlang : External?
  external_javascript : External?
} derive(Eq, Debug)

///|
pub(all) struct RecordConstructor {
  location : @span.SrcSpan
  name_location : @span.SrcSpan
  name : String
  arguments : ArrayView[RecordConstructorArg]
  documentation : Documentation?
  deprecation : Deprecation
} derive(Eq, Debug)

///|
pub(all) struct RecordConstructorArg {
  label : SpannedString?
  ast : TypeAst
  location : @span.SrcSpan
  doc : Documentation?
} derive(Eq, Debug)

///|
pub(all) struct TypeAlias {
  location : @span.SrcSpan
  alias_ : String
  name_location : @span.SrcSpan
  parameters : ArrayView[SpannedString]
  type_ast : TypeAst
  publicity : Publicity
  documentation : Documentation?
  deprecation : Deprecation
} derive(Eq, Debug)

///|
pub(all) enum TypeAst {
  Constructor(TypeAstConstructor)
  Fn(TypeAstFn)
  Var(TypeAstVar)
  Tuple(TypeAstTuple)
  Hole(TypeAstHole)
} derive(Eq, Debug)

///|
pub(all) struct TypeAstConstructor {
  location : @span.SrcSpan
  name : TypeAstConstructorName
  arguments : ArrayView[TypeAst]
  start_parentheses : @span.ByteOffset?
} derive(Eq, Debug)

///|
pub(all) enum TypeAstConstructorName {
  /// `name` is `None` when the text stops after the dot (`module.`).
  Qualified(
    module_~ : String,
    module_location~ : @span.SrcSpan,
    dot_location~ : @span.ByteOffset,
    name~ : SpannedString?
  )
  Unqualified(name~ : String, location~ : @span.SrcSpan)
} derive(Eq, Debug)

///|
pub(all) struct TypeAstFn {
  location : @span.SrcSpan
  arguments : ArrayView[TypeAst]
  return_ : TypeAst
} derive(Eq, Debug)

///|
pub(all) struct TypeAstVar {
  location : @span.SrcSpan
  name : String
} derive(Eq, Debug)

///|
pub(all) struct TypeAstTuple {
  location : @span.SrcSpan
  elements : ArrayView[TypeAst]
} derive(Eq, Debug)

///|
pub(all) struct TypeAstHole {
  location : @span.SrcSpan
  name : String
} derive(Eq, Debug)

///|
pub(all) enum Statement {
  Expression(Expr)
  Assignment(Assignment)
  Use(Use)
  Assert(Assert)
} derive(Eq, Debug)

///|
pub(all) struct Assignment {
  location : @span.SrcSpan
  value : Expr
  pattern : Pattern
  kind : AssignmentKind
  annotation : TypeAst?
} derive(Eq, Debug)

///|
pub(all) enum AssignmentKind {
  Let
  Generated
  Assert(
    location~ : @span.SrcSpan,
    assert_keyword_start~ : @span.ByteOffset,
    message~ : Expr?
  )
} derive(Eq, Debug)

///|
pub(all) struct Use {
  call : Expr
  location : @span.SrcSpan
  right_hand_side_location : @span.SrcSpan
  assignments_location : @span.SrcSpan
  assignments : ArrayView[UseAssignment]
} derive(Eq, Debug)

///|
pub(all) struct UseAssignment {
  location : @span.SrcSpan
  pattern : Pattern
  annotation : TypeAst?
} derive(Eq, Debug)

///|
pub(all) struct Assert {
  location : @span.SrcSpan
  value : Expr
  message : Expr?
} derive(Eq, Debug)

///|
/// `UntypedExpr`.
pub(all) enum Expr {
  Int(location~ : @span.SrcSpan, value~ : String, int_value~ : BigInt)
  Float(location~ : @span.SrcSpan, value~ : String, float_value~ : Double)
  String(location~ : @span.SrcSpan, value~ : String)
  Block(location~ : @span.SrcSpan, statements~ : ArrayView[Statement])
  Var(location~ : @span.SrcSpan, name~ : String)
  Fn(
    location~ : @span.SrcSpan,
    kind~ : FunctionLiteralKind,
    end_of_head_byte_index~ : @span.ByteOffset,
    arguments~ : ArrayView[Arg],
    body~ : ArrayView[Statement],
    return_annotation~ : TypeAst?
  )
  List(location~ : @span.SrcSpan, elements~ : ArrayView[Expr], tail~ : Expr?)
  Call(
    location~ : @span.SrcSpan,
    fun~ : Expr,
    arguments~ : ArrayView[CallArg[Expr]],
    open_parenthesis~ : @span.ByteOffset
  )
  BinOp(
    location~ : @span.SrcSpan,
    operator~ : BinOp,
    operator_start~ : @span.ByteOffset,
    left~ : Expr,
    right~ : Expr
  )
  Pipeline(expressions~ : ArrayView[Expr])
  /// `clauses` is `None` when the `case` has no body.
  Case(
    location~ : @span.SrcSpan,
    subjects~ : ArrayView[Expr],
    clauses~ : ArrayView[Clause]?
  )
  FieldAccess(
    location~ : @span.SrcSpan,
    label_location~ : @span.SrcSpan,
    label~ : String,
    container~ : Expr
  )
  Tuple(location~ : @span.SrcSpan, elements~ : ArrayView[Expr])
  /// `index` is the compiler's `u64`.
  TupleIndex(location~ : @span.SrcSpan, index~ : TupleIndex, tuple~ : Expr)
  Todo(kind~ : TodoKind, location~ : @span.SrcSpan, message~ : Expr?)
  Panic(location~ : @span.SrcSpan, message~ : Expr?)
  Echo(
    location~ : @span.SrcSpan,
    keyword_end~ : @span.ByteOffset,
    expression~ : Expr?,
    message~ : Expr?
  )
  BitArray(
    location~ : @span.SrcSpan,
    segments~ : ArrayView[BitArraySegment[Expr]]
  )
  RecordUpdate(
    location~ : @span.SrcSpan,
    spread_start~ : @span.ByteOffset,
    constructor_~ : Expr,
    record~ : RecordBeingUpdated[Expr],
    arguments~ : ArrayView[RecordUpdateArg[Expr]]
  )
  NegateBool(location~ : @span.SrcSpan, value~ : Expr)
  NegateInt(location~ : @span.SrcSpan, value~ : Expr)
} derive(Eq, Debug)

///|
pub(all) enum FunctionLiteralKind {
  Capture(hole~ : @span.SrcSpan)
  Anonymous(head~ : @span.SrcSpan)
  Use(location~ : @span.SrcSpan)
} derive(Eq, Debug)

///|
pub(all) struct CallArg[A] {
  label : String?
  location : @span.SrcSpan
  value : A
  implicit : ImplicitCallArgOrigin?
} derive(Eq, Debug)

///|
pub(all) enum ImplicitCallArgOrigin {
  Use
  Pipe
  PatternFieldSpread
  IncorrectArityUse
  RecordUpdate
} derive(Eq, Debug, Hash)

///|
/// Return the implicit argument origin's snake_case JSON name.
pub fn ImplicitCallArgOrigin::name(self : ImplicitCallArgOrigin) -> String {
  match self {
    Use => "use"
    Pipe => "pipe"
    PatternFieldSpread => "pattern_field_spread"
    IncorrectArityUse => "incorrect_arity_use"
    RecordUpdate => "record_update"
  }
}

///|
/// Read an implicit argument origin's JSON name.
/// Return `None` for an unknown name.
pub fn ImplicitCallArgOrigin::of(name : String) -> ImplicitCallArgOrigin? {
  match name {
    "use" => Some(Use)
    "pipe" => Some(Pipe)
    "pattern_field_spread" => Some(PatternFieldSpread)
    "incorrect_arity_use" => Some(IncorrectArityUse)
    "record_update" => Some(RecordUpdate)
    _ => None
  }
}

///|
pub(all) enum BinOp {
  And
  Or
  Eq
  NotEq
  LtInt
  LtEqInt
  LtFloat
  LtEqFloat
  GtEqInt
  GtInt
  GtEqFloat
  GtFloat
  AddInt
  AddFloat
  SubInt
  SubFloat
  MultInt
  MultFloat
  DivInt
  DivFloat
  RemainderInt
  Concatenate
} derive(Eq, Debug, Hash)

///|
/// Every operator, in the compiler's order.
pub fn BinOp::all() -> Array[BinOp] {
  [
    And,
    Or,
    Eq,
    NotEq,
    LtInt,
    LtEqInt,
    LtFloat,
    LtEqFloat,
    GtEqInt,
    GtInt,
    GtEqFloat,
    GtFloat,
    AddInt,
    AddFloat,
    SubInt,
    SubFloat,
    MultInt,
    MultFloat,
    DivInt,
    DivFloat,
    RemainderInt,
    Concatenate,
  ]
}

///|
/// Return the binary operator's snake_case JSON name.
pub fn BinOp::name(self : BinOp) -> String {
  match self {
    And => "and"
    Or => "or"
    Eq => "eq"
    NotEq => "not_eq"
    LtInt => "lt_int"
    LtEqInt => "lt_eq_int"
    LtFloat => "lt_float"
    LtEqFloat => "lt_eq_float"
    GtEqInt => "gt_eq_int"
    GtInt => "gt_int"
    GtEqFloat => "gt_eq_float"
    GtFloat => "gt_float"
    AddInt => "add_int"
    AddFloat => "add_float"
    SubInt => "sub_int"
    SubFloat => "sub_float"
    MultInt => "mult_int"
    MultFloat => "mult_float"
    DivInt => "div_int"
    DivFloat => "div_float"
    RemainderInt => "remainder_int"
    Concatenate => "concatenate"
  }
}

///|
/// Read a binary operator's JSON name. Return `None` for an unknown name.
pub fn BinOp::of(name : String) -> BinOp? {
  for op in BinOp::all() {
    if op.name() == name {
      return Some(op)
    }
  }
  None
}

///|
pub(all) struct Clause {
  location : @span.SrcSpan
  pattern : ArrayView[Pattern]
  alternative_patterns : ArrayView[ArrayView[Pattern]]
  guard_ : ClauseGuard?
  then : Expr
} derive(Eq, Debug)

///|
/// `ClauseGuard` without `ModuleSelect` and `Invalid`, which analysis
/// builds, not the parser (`module.name` in a guard is `FieldAccess`).
pub(all) enum ClauseGuard {
  Block(location~ : @span.SrcSpan, value~ : ClauseGuard)
  BinaryOperator(
    location~ : @span.SrcSpan,
    operator~ : BinOp,
    operator_start~ : @span.ByteOffset,
    left~ : ClauseGuard,
    right~ : ClauseGuard
  )
  Not(location~ : @span.SrcSpan, expression~ : ClauseGuard)
  Var(location~ : @span.SrcSpan, name~ : String)
  TupleIndex(
    location~ : @span.SrcSpan,
    index~ : TupleIndex,
    tuple~ : ClauseGuard
  )
  FieldAccess(
    label_location~ : @span.SrcSpan,
    index~ : TupleIndex?,
    label~ : String,
    container~ : ClauseGuard
  )
  Constant(Constant)
} derive(Eq, Debug)

///|
/// `Pattern` without `Invalid` (analysis only).
pub(all) enum Pattern {
  Int(location~ : @span.SrcSpan, value~ : String, int_value~ : BigInt)
  Float(location~ : @span.SrcSpan, value~ : String, float_value~ : Double)
  String(location~ : @span.SrcSpan, value~ : String)
  Variable(location~ : @span.SrcSpan, name~ : String)
  BitArraySize(BitArraySize)
  Assign(name~ : String, location~ : @span.SrcSpan, pattern~ : Pattern)
  Discard(name~ : String, location~ : @span.SrcSpan)
  List(
    location~ : @span.SrcSpan,
    elements~ : ArrayView[Pattern],
    tail~ : TailPattern?
  )
  Constructor(
    location~ : @span.SrcSpan,
    name_location~ : @span.SrcSpan,
    name~ : String,
    arguments~ : ArrayView[CallArg[Pattern]],
    module_~ : SpannedString?,
    spread~ : @span.SrcSpan?
  )
  Tuple(location~ : @span.SrcSpan, elements~ : ArrayView[Pattern])
  BitArray(
    location~ : @span.SrcSpan,
    segments~ : ArrayView[BitArraySegment[Pattern]]
  )
  StringPrefix(
    location~ : @span.SrcSpan,
    left_location~ : @span.SrcSpan,
    left_side_assignment~ : StringPrefixLeftSideAssignment?,
    right_location~ : @span.SrcSpan,
    left_side_string~ : String,
    right_side_assignment~ : AssignName
  )
} derive(Eq, Debug)

///|
pub(all) struct TailPattern {
  location : @span.SrcSpan
  pattern : Pattern
} derive(Eq, Debug)

///|
pub(all) struct StringPrefixLeftSideAssignment {
  name : String
  name_start_position : @span.ByteOffset
  location : @span.SrcSpan
} derive(Eq, Debug)

///|
pub(all) enum BitArraySize {
  Int(location~ : @span.SrcSpan, value~ : String, int_value~ : BigInt)
  Variable(location~ : @span.SrcSpan, name~ : String)
  BinaryOperator(
    location~ : @span.SrcSpan,
    operator~ : IntOperator,
    left~ : BitArraySize,
    right~ : BitArraySize
  )
  Block(location~ : @span.SrcSpan, inner~ : BitArraySize)
} derive(Eq, Debug)

///|
pub(all) enum IntOperator {
  Add
  Subtract
  Multiply
  Divide
  Remainder
} derive(Eq, Debug, Hash)

///|
/// Return the integer operator's snake_case JSON name.
pub fn IntOperator::name(self : IntOperator) -> String {
  match self {
    Add => "add"
    Subtract => "subtract"
    Multiply => "multiply"
    Divide => "divide"
    Remainder => "remainder"
  }
}

///|
/// Read an integer operator's JSON name. Return `None` for an unknown name.
pub fn IntOperator::of(name : String) -> IntOperator? {
  match name {
    "add" => Some(Add)
    "subtract" => Some(Subtract)
    "multiply" => Some(Multiply)
    "divide" => Some(Divide)
    "remainder" => Some(Remainder)
    _ => None
  }
}

///|
pub(all) struct BitArraySegment[V] {
  location : @span.SrcSpan
  value : V
  options : ArrayView[BitArrayOption[V]]
} derive(Eq, Debug)

///|
pub(all) enum BitArrayOption[V] {
  Bytes(location~ : @span.SrcSpan)
  Int(location~ : @span.SrcSpan)
  Float(location~ : @span.SrcSpan)
  Bits(location~ : @span.SrcSpan)
  Utf8(location~ : @span.SrcSpan)
  Utf16(location~ : @span.SrcSpan)
  Utf32(location~ : @span.SrcSpan)
  Utf8Codepoint(location~ : @span.SrcSpan)
  Utf16Codepoint(location~ : @span.SrcSpan)
  Utf32Codepoint(location~ : @span.SrcSpan)
  Signed(location~ : @span.SrcSpan)
  Unsigned(location~ : @span.SrcSpan)
  Big(location~ : @span.SrcSpan)
  Little(location~ : @span.SrcSpan)
  Native(location~ : @span.SrcSpan)
  Size(location~ : @span.SrcSpan, value~ : V, short_form~ : Bool)
  Unit(location~ : @span.SrcSpan, value~ : BitArrayUnit)
} derive(Eq, Debug)

///|
pub(all) enum TodoKind {
  Keyword
  EmptyFunction(function_location~ : @span.SrcSpan)
  IncompleteUse
  EmptyBlock
} derive(Eq, Debug)

///|
pub(all) struct RecordBeingUpdated[A] {
  base : A
  location : @span.SrcSpan
} derive(Eq, Debug)

///|
pub(all) struct RecordUpdateArg[A] {
  label : String
  location : @span.SrcSpan
  value : A
} derive(Eq, Debug)

///|
/// `Constant<()>` without `Invalid` (analysis only).
pub(all) enum Constant {
  Int(location~ : @span.SrcSpan, value~ : String, int_value~ : BigInt)
  Float(location~ : @span.SrcSpan, value~ : String, float_value~ : Double)
  String(location~ : @span.SrcSpan, value~ : String)
  Tuple(location~ : @span.SrcSpan, elements~ : ArrayView[Constant])
  List(
    location~ : @span.SrcSpan,
    elements~ : ArrayView[Constant],
    tail~ : Constant?
  )
  /// `arguments` is `None` for a bare constructor (`Nil`), `Some([])` for
  /// `Nil()`.
  Record(
    location~ : @span.SrcSpan,
    arguments_start_position~ : @span.ByteOffset,
    module_~ : SpannedString?,
    name~ : String,
    arguments~ : ArrayView[CallArg[Constant]]?
  )
  RecordUpdate(
    location~ : @span.SrcSpan,
    constructor_location~ : @span.SrcSpan,
    module_~ : SpannedString?,
    name~ : String,
    record~ : RecordBeingUpdated[Constant],
    arguments~ : ArrayView[RecordUpdateArg[Constant]]
  )
  BitArray(
    location~ : @span.SrcSpan,
    segments~ : ArrayView[BitArraySegment[Constant]]
  )
  Var(location~ : @span.SrcSpan, module_~ : SpannedString?, name~ : String)
  BinaryOperator(
    location~ : @span.SrcSpan,
    operator_start~ : @span.ByteOffset,
    operator~ : BinOp,
    left~ : Constant,
    right~ : Constant
  )
  Todo(location~ : @span.SrcSpan, message~ : Constant?)
} derive(Eq, Debug)

///|
/// `parse::extra::ModuleExtra`: byte positions of the trivia the formatter
/// needs. Comment spans are the compiler's (after the slashes).
pub(all) struct ModuleExtra {
  module_comments : ArrayView[@span.SrcSpan]
  doc_comments : ArrayView[@span.SrcSpan]
  comments : ArrayView[@span.SrcSpan]
  empty_lines : ArrayView[@span.ByteOffset]
  new_lines : ArrayView[@span.ByteOffset]
  trailing_commas : ArrayView[@span.ByteOffset]
} derive(Eq, Debug)

///|
/// Create trivia metadata with no comments, line ends or trailing commas.
pub fn ModuleExtra::empty() -> ModuleExtra {
  {
    module_comments: [][:],
    doc_comments: [][:],
    comments: [][:],
    empty_lines: [][:],
    new_lines: [][:],
    trailing_commas: [][:],
  }
}

///|
/// The warnings `parse_module` emits: `DeprecatedSyntaxWarning` and
/// `DetachedDocComment`.
pub(all) enum Warning {
  DeprecatedListPrepend(location~ : @span.SrcSpan)
  DeprecatedListPattern(location~ : @span.SrcSpan)
  DeprecatedListCatchAllPattern(location~ : @span.SrcSpan)
  DeprecatedListSpreadAsVariablePattern(
    location~ : @span.SrcSpan,
    name~ : String
  )
  DeprecatedRecordSpreadPattern(location~ : @span.SrcSpan)
  DeprecatedEmptyClauseGuard(location~ : @span.SrcSpan)
  DeprecatedTargetShorthand(target~ : Target, location~ : @span.SrcSpan)
  DetachedDocComment(location~ : @span.SrcSpan)
} derive(Eq, Debug)
