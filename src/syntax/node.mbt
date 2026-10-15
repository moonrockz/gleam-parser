// The node model: a read-only view over the typed AST of a parse result.
// Every traversal in this package walks `children()` with an explicit
// stack, so no node depth overflows the native stack and no traversal
// spends fuel.

///|
/// A read-only reference to one node of a parse result. Each case points
/// into the typed AST (nothing is copied). Generic code uses `category`,
/// `kind`, `span`, `children` and `field`; typed code matches the cases.
///
/// Kinds and field names follow the JSON that `@ast.encode_*` writes
/// (`docs/ast-json.md`); `(category, kind)` identifies a node type. The
/// generic wrappers of the AST (call arguments, record update arguments,
/// the record of a record update, bit array segments and options) are one
/// case per payload type, with one category for all three.
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("pub fn main() {\n  1\n}\n")
///   let root = @syntax.NodeRef::of_result(r)
///   let def = root.children()[0]
///   inspect("\{def.category()}/\{def.kind()}", content="definition/function")
///   match def {
///     Definition(t) =>
///       match t.definition {
///         Function(f) =>
///           debug_inspect(f.name.map(n => n.name), content="Some(\"main\")")
///         _ => fail("not a function")
///       }
///     _ => fail("not a definition")
///   }
/// }
/// ```
pub(all) enum NodeRef {
  /// The root: the module with its CST (the CST gives the end offset).
  Module(@ast.Module, @cst.ModuleCst)
  Definition(@ast.TargetedDefinition)
  Statement(@ast.Statement)
  Expr(@ast.Expr)
  Pattern(@ast.Pattern)
  TypeAst(@ast.TypeAst)
  Constant(@ast.Constant)
  ClauseGuard(@ast.ClauseGuard)
  BitArraySize(@ast.BitArraySize)
  Clause(@ast.Clause)
  Arg(@ast.Arg)
  RecordConstructor(@ast.RecordConstructor)
  RecordConstructorArg(@ast.RecordConstructorArg)
  UseAssignment(@ast.UseAssignment)
  TailPattern(@ast.TailPattern)
  ExprArg(@ast.CallArg[@ast.Expr])
  PatternArg(@ast.CallArg[@ast.Pattern])
  ConstantArg(@ast.CallArg[@ast.Constant])
  ExprUpdateArg(@ast.RecordUpdateArg[@ast.Expr])
  ConstantUpdateArg(@ast.RecordUpdateArg[@ast.Constant])
  ExprRecord(@ast.RecordBeingUpdated[@ast.Expr])
  ConstantRecord(@ast.RecordBeingUpdated[@ast.Constant])
  ExprSegment(@ast.BitArraySegment[@ast.Expr])
  PatternSegment(@ast.BitArraySegment[@ast.Pattern])
  ConstantSegment(@ast.BitArraySegment[@ast.Constant])
  ExprOption(@ast.BitArrayOption[@ast.Expr])
  PatternOption(@ast.BitArrayOption[@ast.Pattern])
  ConstantOption(@ast.BitArrayOption[@ast.Constant])
} derive(Eq, Debug)

///|
fn[T : Eq] same_value(x : T, y : T) -> Bool {
  physical_equal(x, y) || x == y
}

///|
/// `a == b`, but fast for nodes taken from the same tree: nodes wrap the
/// AST values themselves, so the same node is usually the same object and
/// the structural comparison of whole subtrees is not needed.
fn same(a : NodeRef, b : NodeRef) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  match (a, b) {
    (Module(x, _), Module(y, _)) => same_value(x, y)
    (Definition(x), Definition(y)) => same_value(x, y)
    (Statement(x), Statement(y)) => same_value(x, y)
    (Expr(x), Expr(y)) => same_value(x, y)
    (Pattern(x), Pattern(y)) => same_value(x, y)
    (TypeAst(x), TypeAst(y)) => same_value(x, y)
    (Constant(x), Constant(y)) => same_value(x, y)
    (ClauseGuard(x), ClauseGuard(y)) => same_value(x, y)
    (BitArraySize(x), BitArraySize(y)) => same_value(x, y)
    (Clause(x), Clause(y)) => same_value(x, y)
    (Arg(x), Arg(y)) => same_value(x, y)
    (RecordConstructor(x), RecordConstructor(y)) => same_value(x, y)
    (RecordConstructorArg(x), RecordConstructorArg(y)) => same_value(x, y)
    (UseAssignment(x), UseAssignment(y)) => same_value(x, y)
    (TailPattern(x), TailPattern(y)) => same_value(x, y)
    (ExprArg(x), ExprArg(y)) => same_value(x, y)
    (PatternArg(x), PatternArg(y)) => same_value(x, y)
    (ConstantArg(x), ConstantArg(y)) => same_value(x, y)
    (ExprUpdateArg(x), ExprUpdateArg(y)) => same_value(x, y)
    (ConstantUpdateArg(x), ConstantUpdateArg(y)) => same_value(x, y)
    (ExprRecord(x), ExprRecord(y)) => same_value(x, y)
    (ConstantRecord(x), ConstantRecord(y)) => same_value(x, y)
    (ExprSegment(x), ExprSegment(y)) => same_value(x, y)
    (PatternSegment(x), PatternSegment(y)) => same_value(x, y)
    (ConstantSegment(x), ConstantSegment(y)) => same_value(x, y)
    (ExprOption(x), ExprOption(y)) => same_value(x, y)
    (PatternOption(x), PatternOption(y)) => same_value(x, y)
    (ConstantOption(x), ConstantOption(y)) => same_value(x, y)
    _ => false
  }
}

///|
/// The root node of `result`: its module. A parse always gives a module
/// (a definition with a syntax error is skipped), so there is always a
/// root. The AST is shared with `result`; nothing is copied.
///
/// ```mbt check
/// test {
///   let root = @syntax.NodeRef::of_result(@parser.parse_text("const x = 1\n"))
///   inspect(root.kind(), content="module")
///   inspect(root.children().length(), content="1")
/// }
/// ```
pub fn NodeRef::of_result(result : @parser.ParseResult) -> NodeRef {
  Module(result.module_, result.cst)
}

///|
/// The node type: `"module"`, `"definition"`, `"statement"`,
/// `"expression"`, `"pattern"`, `"type"`, `"constant"`, `"clause_guard"`,
/// `"bit_array_size"`, `"clause"`, `"arg"`, `"record_constructor"`,
/// `"record_constructor_arg"`, `"use_assignment"`, `"tail_pattern"`,
/// `"call_arg"`, `"record_update_arg"`, `"record_being_updated"`,
/// `"bit_array_segment"`, `"bit_array_option"`.
pub fn NodeRef::category(self : NodeRef) -> String {
  match self {
    Module(_, _) => "module"
    Definition(_) => "definition"
    Statement(_) => "statement"
    Expr(_) => "expression"
    Pattern(_) => "pattern"
    TypeAst(_) => "type"
    Constant(_) => "constant"
    ClauseGuard(_) => "clause_guard"
    BitArraySize(_) => "bit_array_size"
    Clause(_) => "clause"
    Arg(_) => "arg"
    RecordConstructor(_) => "record_constructor"
    RecordConstructorArg(_) => "record_constructor_arg"
    UseAssignment(_) => "use_assignment"
    TailPattern(_) => "tail_pattern"
    ExprArg(_) | PatternArg(_) | ConstantArg(_) => "call_arg"
    ExprUpdateArg(_) | ConstantUpdateArg(_) => "record_update_arg"
    ExprRecord(_) | ConstantRecord(_) => "record_being_updated"
    ExprSegment(_) | PatternSegment(_) | ConstantSegment(_) =>
      "bit_array_segment"
    ExprOption(_) | PatternOption(_) | ConstantOption(_) => "bit_array_option"
  }
}

///|
/// The JSON `kind` of the node's value, or its category for a value with
/// no `kind` (a clause, an argument, ...). A kind alone does not identify
/// a node type (`list` is an expression, a pattern and a constant):
/// compare `category()` too.
///
/// ```mbt check
/// test {
///   let e = @syntax.NodeRef::Expr(@parser.parse_expression_text("[1, 2]"))
///   let p = @syntax.NodeRef::Pattern(@parser.parse_pattern_text("[a, b]"))
///   inspect("\{e.category()}/\{e.kind()}", content="expression/list")
///   inspect("\{p.category()}/\{p.kind()}", content="pattern/list")
/// }
/// ```
pub fn NodeRef::kind(self : NodeRef) -> String {
  match self {
    Definition(t) => definition_kind(t.definition)
    Statement(s) => statement_kind(s)
    Expr(e) => expr_kind(e)
    Pattern(p) => pattern_kind(p)
    TypeAst(t) => type_kind(t)
    Constant(c) => constant_kind(c)
    ClauseGuard(g) => guard_kind(g)
    BitArraySize(z) => size_kind(z)
    ExprOption(o) => option_kind(o)
    PatternOption(o) => option_kind(o)
    ConstantOption(o) => option_kind(o)
    other => other.category()
  }
}

///|
fn definition_kind(d : @ast.Definition) -> String {
  match d {
    Function(_) => "function"
    TypeAlias(_) => "type_alias"
    CustomType(_) => "custom_type"
    Import(_) => "import"
    ModuleConstant(_) => "module_constant"
  }
}

///|
fn statement_kind(s : @ast.Statement) -> String {
  match s {
    Expression(_) => "expression"
    Assignment(_) => "assignment"
    Use(_) => "use"
    Assert(_) => "assert"
  }
}

///|
fn expr_kind(e : @ast.Expr) -> String {
  match e {
    Int(..) => "int"
    Float(..) => "float"
    String(..) => "string"
    Block(..) => "block"
    Var(..) => "var"
    Fn(..) => "fn"
    List(..) => "list"
    Call(..) => "call"
    BinOp(..) => "bin_op"
    Pipeline(..) => "pipeline"
    Case(..) => "case"
    FieldAccess(..) => "field_access"
    Tuple(..) => "tuple"
    TupleIndex(..) => "tuple_index"
    Todo(..) => "todo"
    Panic(..) => "panic"
    Echo(..) => "echo"
    BitArray(..) => "bit_array"
    RecordUpdate(..) => "record_update"
    NegateBool(..) => "negate_bool"
    NegateInt(..) => "negate_int"
  }
}

///|
fn pattern_kind(p : @ast.Pattern) -> String {
  match p {
    Int(..) => "int"
    Float(..) => "float"
    String(..) => "string"
    Variable(..) => "variable"
    BitArraySize(_) => "bit_array_size"
    Assign(..) => "assign"
    Discard(..) => "discard"
    List(..) => "list"
    Constructor(..) => "constructor"
    Tuple(..) => "tuple"
    BitArray(..) => "bit_array"
    StringPrefix(..) => "string_prefix"
  }
}

///|
fn type_kind(t : @ast.TypeAst) -> String {
  match t {
    Constructor(_) => "constructor"
    Fn(_) => "fn"
    Var(_) => "var"
    Tuple(_) => "tuple"
    Hole(_) => "hole"
  }
}

///|
fn constant_kind(c : @ast.Constant) -> String {
  match c {
    Int(..) => "int"
    Float(..) => "float"
    String(..) => "string"
    Tuple(..) => "tuple"
    List(..) => "list"
    Record(..) => "record"
    RecordUpdate(..) => "record_update"
    BitArray(..) => "bit_array"
    Var(..) => "var"
    BinaryOperator(..) => "binary_operator"
    Todo(..) => "todo"
  }
}

///|
fn guard_kind(g : @ast.ClauseGuard) -> String {
  match g {
    Block(..) => "block"
    BinaryOperator(..) => "binary_operator"
    Not(..) => "not"
    Var(..) => "var"
    TupleIndex(..) => "tuple_index"
    FieldAccess(..) => "field_access"
    Constant(_) => "constant"
  }
}

///|
fn size_kind(z : @ast.BitArraySize) -> String {
  match z {
    Int(..) => "int"
    Variable(..) => "variable"
    BinaryOperator(..) => "binary_operator"
    Block(..) => "block"
  }
}

///|
fn[V] option_kind(o : @ast.BitArrayOption[V]) -> String {
  match o {
    Bytes(..) => "bytes"
    Int(..) => "int"
    Float(..) => "float"
    Bits(..) => "bits"
    Utf8(..) => "utf8"
    Utf16(..) => "utf16"
    Utf32(..) => "utf32"
    Utf8Codepoint(..) => "utf8_codepoint"
    Utf16Codepoint(..) => "utf16_codepoint"
    Utf32Codepoint(..) => "utf32_codepoint"
    Signed(..) => "signed"
    Unsigned(..) => "unsigned"
    Big(..) => "big"
    Little(..) => "little"
    Native(..) => "native"
    Size(..) => "size"
    Unit(..) => "unit"
  }
}

///|
/// A guard's span. The compiler's `TupleIndex` guard location covers
/// `.index` only, and a binary operator built on it starts there too, so
/// the span starts at the leftmost node of the guard's left spine (a loop,
/// not a recursion).
fn guard_span(g : @ast.ClauseGuard) -> @span.SrcSpan {
  let own = g.location()
  let mut start = own.start
  let mut cur = g
  while true {
    let s = cur.location().start
    if s < start {
      start = s
    }
    match cur {
      BinaryOperator(left~, ..) => cur = left
      TupleIndex(tuple~, ..) => cur = tuple
      FieldAccess(container~, ..) => cur = container
      Block(..) | Not(..) | Var(..) | Constant(_) => break
    }
  }
  @span.SrcSpan::new(start, own.end)
}

///|
fn later(a : Int32, b : Int32) -> Int32 {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn[V] option_span(o : @ast.BitArrayOption[V]) -> @span.SrcSpan {
  match o {
    Bytes(location~)
    | Int(location~)
    | Float(location~)
    | Bits(location~)
    | Utf8(location~)
    | Utf16(location~)
    | Utf32(location~)
    | Utf8Codepoint(location~)
    | Utf16Codepoint(location~)
    | Utf32Codepoint(location~)
    | Signed(location~)
    | Unsigned(location~)
    | Big(location~)
    | Little(location~)
    | Native(location~)
    | Size(location~, ..)
    | Unit(location~, ..) => location
  }
}

///|
/// The node's span, in UTF-8 byte offsets (the end is exclusive). A node's
/// span contains its children's spans. The module spans from 0 to the end
/// of its last token. A definition spans from its head to its last child:
/// `end_position` for a function or a custom type, the value of a
/// constant, the type of an alias (the compiler's `location` covers the
/// head only). A clause guard starts at the leftmost node of its left
/// spine (the compiler locates a `TupleIndex` guard at `.index` only).
/// Every other node has the AST's `location`. A pipeline runs from its
/// first to its last expression. A `pattern as name` runs from the
/// pattern's start to the name's end.
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("pub fn main() {\n  1\n}\n")
///   let def = @syntax.NodeRef::of_result(r).children()[0]
///   debug_inspect(def.span(), content="{ start: 0, end: 21 }")
/// }
/// ```
pub fn NodeRef::span(self : NodeRef) -> @span.SrcSpan {
  match self {
    Module(_, cst) =>
      match cst.tokens {
        [] => @span.SrcSpan::new(0, 0)
        [.., last] => @span.SrcSpan::new(0, last.span.end)
      }
    Definition(t) =>
      match t.definition {
        Function(f) => {
          // An external function has no body: `end_position` ends the head,
          // and the return annotation may lie after it.
          let mut end = if f.end_position > f.location.end {
            f.end_position
          } else {
            f.location.end
          }
          if f.return_annotation is Some(r) {
            end = later(end, r.location().end)
          }
          for a in f.arguments {
            end = later(end, a.location.end)
          }
          @span.SrcSpan::new(f.location.start, end)
        }
        CustomType(c) => @span.SrcSpan::new(c.location.start, c.end_position)
        TypeAlias(a) =>
          @span.SrcSpan::new(
            a.location.start,
            later(a.location.end, a.type_ast.location().end),
          )
        ModuleConstant(c) => {
          // The compiler's location covers `const name` only.
          let mut end = later(c.location.end, c.value.location().end)
          if c.annotation is Some(t) {
            end = later(end, t.location().end)
          }
          @span.SrcSpan::new(c.location.start, end)
        }
        Import(i) => i.location
      }
    Statement(s) => s.location()
    Expr(e) => e.location()
    Pattern(p) => p.location()
    TypeAst(t) => t.location()
    Constant(c) => c.location()
    ClauseGuard(g) => guard_span(g)
    BitArraySize(z) => z.location()
    Clause(c) => c.location
    Arg(a) => a.location
    RecordConstructor(r) => r.location
    RecordConstructorArg(a) => a.location
    UseAssignment(u) => u.location
    TailPattern(t) => t.location
    ExprArg(a) => a.location
    PatternArg(a) => a.location
    ConstantArg(a) => a.location
    ExprUpdateArg(a) => a.location
    ConstantUpdateArg(a) => a.location
    ExprRecord(r) => r.location
    ConstantRecord(r) => r.location
    ExprSegment(s) => s.location
    PatternSegment(s) => s.location
    ConstantSegment(s) => s.location
    ExprOption(o) => option_span(o)
    PatternOption(o) => option_span(o)
    ConstantOption(o) => option_span(o)
  }
}
