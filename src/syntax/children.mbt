// The children of a node, by field, in the JSON key order of
// docs/ast-json.md (the encoder's order in src/ast/encode.mbt).

///|
fn[T] optional(x : T?, f : (T) -> NodeRef) -> Array[NodeRef] {
  match x {
    Some(v) => [f(v)]
    None => []
  }
}

///|
fn[T] nodes(xs : ArrayView[T], f : (T) -> NodeRef) -> Array[NodeRef] {
  xs.map(f)
}

///|
fn[V] segment_entries(
  s : @ast.BitArraySegment[V],
  value : (V) -> NodeRef,
  option : (@ast.BitArrayOption[V]) -> NodeRef,
) -> Array[(String, Array[NodeRef])] {
  [("value", [value(s.value)]), ("options", nodes(s.options, option))]
}

///|
fn[V] option_entries(
  o : @ast.BitArrayOption[V],
  value : (V) -> NodeRef,
) -> Array[(String, Array[NodeRef])] {
  match o {
    Size(value=v, ..) => [("value", [value(v)])]
    _ => []
  }
}

///|
fn function_entries(f : @ast.Function) -> Array[(String, Array[NodeRef])] {
  [
    ("arguments", nodes(f.arguments, a => Arg(a))),
    ("body", nodes(f.body, s => Statement(s))),
    ("return_annotation", optional(f.return_annotation, t => TypeAst(t))),
  ]
}

///|
/// The node's fields in JSON order, each with its child nodes.
fn NodeRef::entries(self : NodeRef) -> Array[(String, Array[NodeRef])] {
  match self {
    Module(m, _) => [("definitions", nodes(m.definitions, d => Definition(d)))]
    Definition(t) =>
      match t.definition {
        Function(f) => function_entries(f)
        TypeAlias(a) => [("type_ast", [TypeAst(a.type_ast)])]
        CustomType(c) =>
          [("constructors", nodes(c.constructors, r => RecordConstructor(r)))]
        Import(_) => []
        ModuleConstant(c) =>
          [
            ("annotation", optional(c.annotation, t => TypeAst(t))),
            ("value", [Constant(c.value)]),
          ]
      }
    Statement(s) =>
      match s {
        Expression(e) => [("expression", [Expr(e)])]
        Assignment(a) =>
          [
            ("value", [Expr(a.value)]),
            ("pattern", [Pattern(a.pattern)]),
            (
              "assignment_kind",
              match a.kind {
                Assert(message=Some(m), ..) => [Expr(m)]
                _ => []
              },
            ),
            ("annotation", optional(a.annotation, t => TypeAst(t))),
          ]
        Use(u) =>
          [
            ("call", [Expr(u.call)]),
            ("assignments", nodes(u.assignments, a => UseAssignment(a))),
          ]
        Assert(a) =>
          [
            ("value", [Expr(a.value)]),
            ("message", optional(a.message, e => Expr(e))),
          ]
      }
    Expr(e) => expr_entries(e)
    Pattern(p) => pattern_entries(p)
    TypeAst(t) => type_entries(t)
    Constant(c) => constant_entries(c)
    ClauseGuard(g) => guard_entries(g)
    BitArraySize(z) =>
      match z {
        BinaryOperator(left~, right~, ..) =>
          [("left", [BitArraySize(left)]), ("right", [BitArraySize(right)])]
        Block(inner~, ..) => [("inner", [BitArraySize(inner)])]
        Int(..) | Variable(..) => []
      }
    Clause(c) => {
      let alternatives = []
      for alt in c.alternative_patterns {
        for p in alt {
          alternatives.push(Pattern(p))
        }
      }
      [
        ("pattern", nodes(c.pattern, p => Pattern(p))),
        ("alternative_patterns", alternatives),
        ("guard", optional(c.guard_, g => ClauseGuard(g))),
        ("then", [Expr(c.then)]),
      ]
    }
    Arg(a) => [("annotation", optional(a.annotation, t => TypeAst(t)))]
    RecordConstructor(r) =>
      [("arguments", nodes(r.arguments, a => RecordConstructorArg(a)))]
    RecordConstructorArg(a) => [("ast", [TypeAst(a.ast)])]
    UseAssignment(u) =>
      [
        ("pattern", [Pattern(u.pattern)]),
        ("annotation", optional(u.annotation, t => TypeAst(t))),
      ]
    TailPattern(t) => [("pattern", [Pattern(t.pattern)])]
    ExprArg(a) => [("value", [Expr(a.value)])]
    PatternArg(a) => [("value", [Pattern(a.value)])]
    ConstantArg(a) => [("value", [Constant(a.value)])]
    ExprUpdateArg(a) => [("value", [Expr(a.value)])]
    ConstantUpdateArg(a) => [("value", [Constant(a.value)])]
    ExprRecord(r) => [("base", [Expr(r.base)])]
    ConstantRecord(r) => [("base", [Constant(r.base)])]
    ExprSegment(s) => segment_entries(s, e => Expr(e), o => ExprOption(o))
    PatternSegment(s) =>
      segment_entries(s, p => Pattern(p), o => PatternOption(o))
    ConstantSegment(s) =>
      segment_entries(s, c => Constant(c), o => ConstantOption(o))
    ExprOption(o) => option_entries(o, e => Expr(e))
    PatternOption(o) => option_entries(o, p => Pattern(p))
    ConstantOption(o) => option_entries(o, c => Constant(c))
  }
}

///|
fn expr_entries(e : @ast.Expr) -> Array[(String, Array[NodeRef])] {
  match e {
    Block(statements~, ..) =>
      [("statements", nodes(statements, s => Statement(s)))]
    Fn(arguments~, body~, return_annotation~, ..) =>
      [
        ("arguments", nodes(arguments, a => Arg(a))),
        ("body", nodes(body, s => Statement(s))),
        ("return_annotation", optional(return_annotation, t => TypeAst(t))),
      ]
    List(elements~, tail~, ..) =>
      [
        ("elements", nodes(elements, x => Expr(x))),
        ("tail", optional(tail, x => Expr(x))),
      ]
    Call(fun~, arguments~, ..) =>
      [("fun", [Expr(fun)]), ("arguments", nodes(arguments, a => ExprArg(a)))]
    BinOp(left~, right~, ..) =>
      [("left", [Expr(left)]), ("right", [Expr(right)])]
    Pipeline(expressions~) =>
      [("expressions", nodes(expressions, x => Expr(x)))]
    Case(subjects~, clauses~, ..) =>
      [
        ("subjects", nodes(subjects, x => Expr(x))),
        (
          "clauses",
          match clauses {
            Some(cs) => nodes(cs, c => Clause(c))
            None => []
          },
        ),
      ]
    FieldAccess(container~, ..) => [("container", [Expr(container)])]
    Tuple(elements~, ..) => [("elements", nodes(elements, x => Expr(x)))]
    TupleIndex(tuple~, ..) => [("tuple", [Expr(tuple)])]
    Todo(message~, ..) | Panic(message~, ..) =>
      [("message", optional(message, x => Expr(x)))]
    Echo(expression~, message~, ..) =>
      [
        ("expression", optional(expression, x => Expr(x))),
        ("message", optional(message, x => Expr(x))),
      ]
    BitArray(segments~, ..) =>
      [("segments", nodes(segments, s => ExprSegment(s)))]
    RecordUpdate(constructor_~, record~, arguments~, ..) =>
      [
        ("constructor", [Expr(constructor_)]),
        ("record", [ExprRecord(record)]),
        ("arguments", nodes(arguments, a => ExprUpdateArg(a))),
      ]
    NegateBool(value~, ..) | NegateInt(value~, ..) => [("value", [Expr(value)])]
    Int(..) | Float(..) | String(..) | Var(..) => []
  }
}

///|
fn pattern_entries(p : @ast.Pattern) -> Array[(String, Array[NodeRef])] {
  match p {
    Assign(pattern~, ..) => [("pattern", [Pattern(pattern)])]
    BitArraySize(size) => [("size", [BitArraySize(size)])]
    List(elements~, tail~, ..) =>
      [
        ("elements", nodes(elements, x => Pattern(x))),
        ("tail", optional(tail, t => TailPattern(t))),
      ]
    Constructor(arguments~, ..) =>
      [("arguments", nodes(arguments, a => PatternArg(a)))]
    Tuple(elements~, ..) => [("elements", nodes(elements, x => Pattern(x)))]
    BitArray(segments~, ..) =>
      [("segments", nodes(segments, s => PatternSegment(s)))]
    Int(..)
    | Float(..)
    | String(..)
    | Variable(..)
    | Discard(..)
    | StringPrefix(..) => []
  }
}

///|
fn type_entries(t : @ast.TypeAst) -> Array[(String, Array[NodeRef])] {
  match t {
    Constructor(c) => [("arguments", nodes(c.arguments, x => TypeAst(x)))]
    Fn(f) =>
      [
        ("arguments", nodes(f.arguments, x => TypeAst(x))),
        ("return_", [TypeAst(f.return_)]),
      ]
    Tuple(x) => [("elements", nodes(x.elements, y => TypeAst(y)))]
    Var(_) | Hole(_) => []
  }
}

///|
fn constant_entries(c : @ast.Constant) -> Array[(String, Array[NodeRef])] {
  match c {
    Tuple(elements~, ..) => [("elements", nodes(elements, x => Constant(x)))]
    List(elements~, tail~, ..) =>
      [
        ("elements", nodes(elements, x => Constant(x))),
        ("tail", optional(tail, x => Constant(x))),
      ]
    Record(arguments~, ..) =>
      [
        (
          "arguments",
          match arguments {
            Some(xs) => nodes(xs, a => ConstantArg(a))
            None => []
          },
        ),
      ]
    RecordUpdate(record~, arguments~, ..) =>
      [
        ("record", [ConstantRecord(record)]),
        ("arguments", nodes(arguments, a => ConstantUpdateArg(a))),
      ]
    BitArray(segments~, ..) =>
      [("segments", nodes(segments, s => ConstantSegment(s)))]
    BinaryOperator(left~, right~, ..) =>
      [("left", [Constant(left)]), ("right", [Constant(right)])]
    Todo(message~, ..) => [("message", optional(message, x => Constant(x)))]
    Int(..) | Float(..) | String(..) | Var(..) => []
  }
}

///|
fn guard_entries(g : @ast.ClauseGuard) -> Array[(String, Array[NodeRef])] {
  match g {
    Block(value~, ..) => [("value", [ClauseGuard(value)])]
    BinaryOperator(left~, right~, ..) =>
      [("left", [ClauseGuard(left)]), ("right", [ClauseGuard(right)])]
    Not(expression~, ..) => [("expression", [ClauseGuard(expression)])]
    TupleIndex(tuple~, ..) => [("tuple", [ClauseGuard(tuple)])]
    FieldAccess(container~, ..) => [("container", [ClauseGuard(container)])]
    Constant(c) => [("constant", [Constant(c)])]
    Var(..) => []
  }
}

///|
/// The names of this node's fields that can hold nodes, in JSON order. A
/// field is listed also when it holds no node (a function with no return
/// annotation has an empty `return_annotation` field).
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("pub fn f(a) {\n  a\n}\n")
///   let f = @syntax.NodeRef::of_result(r).field("definitions")[0]
///   debug_inspect(
///     f.fields(),
///     content="[\"arguments\", \"body\", \"return_annotation\"]",
///   )
///   inspect(f.field("return_annotation").length(), content="0")
/// }
/// ```
pub fn NodeRef::fields(self : NodeRef) -> Array[String] {
  self.entries().map(e => e.0)
}

///|
/// The nodes in field `name` (a new array; empty for an absent or unknown
/// field).
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("pub fn f(a, b) {\n  a\n}\n")
///   let f = @syntax.NodeRef::of_result(r).field("definitions")[0]
///   inspect(f.field("arguments").length(), content="2")
///   inspect(f.field("no_such_field").length(), content="0")
/// }
/// ```
pub fn NodeRef::field(self : NodeRef, name : String) -> Array[NodeRef] {
  for e in self.entries() {
    if e.0 == name {
      return e.1
    }
  }
  []
}

///|
/// `xs` in the start order of `node(x)`; among equal starts, in their
/// order in `xs`. Most nodes list their fields in source order, so `xs`
/// comes back as it is when it is in order already, and is sorted only
/// otherwise.
fn[T] in_source_order(xs : Array[T], node : (T) -> NodeRef) -> Array[T] {
  let mut sorted = true
  for i in 1..<xs.length() {
    if node(xs[i - 1]).span().start > node(xs[i]).span().start {
      sorted = false
      break
    }
  }
  if sorted {
    return xs
  }
  // Array::sort_by is not stable, so the original position breaks ties.
  let keyed = xs.mapi((i, x) => (i, x))
  keyed.sort_by((a, b) => {
    let c = node(a.1).span().start.compare(node(b.1).span().start)
    if c != 0 {
      c
    } else {
      a.0.compare(b.0)
    }
  })
  keyed.map(x => x.1)
}

///|
/// All child nodes in source order (a new array), each with its step: its
/// field and its index in that field. Children that start at the same
/// place keep their field order. A clause's `alternative_patterns` is a
/// list of lists in the JSON; here its patterns are flattened, so the
/// index is the flat position.
///
/// ```mbt check
/// test {
///   let sum = @syntax.NodeRef::Expr(@parser.parse_expression_text("a + b"))
///   let labels = sum
///     .children_with_fields()
///     .map(x => "\{x.0.field}[\{x.0.index}]:\{x.1.kind()}")
///   inspect(labels.join(" "), content="left[0]:var right[0]:var")
/// }
/// ```
pub fn NodeRef::children_with_fields(
  self : NodeRef,
) -> Array[(PathStep, NodeRef)] {
  let all : Array[(PathStep, NodeRef)] = []
  for e in self.entries() {
    for i, c in e.1 {
      all.push(({ field: e.0, index: ChildIndex::from_int(i).unwrap(), }, c))
    }
  }
  in_source_order(all, x => x.1)
}

///|
/// All child nodes in source order (a new array). Use `field_of` to get
/// the field of one child, and `children_with_fields` (or
/// `Tree::field_of`) to get the field of each child.
///
/// ```mbt check
/// test {
///   let call = @syntax.NodeRef::Expr(@parser.parse_expression_text("f(x, y)"))
///   debug_inspect(
///     call.children().map(c => c.kind()),
///     content="[\"var\", \"call_arg\", \"call_arg\"]",
///   )
/// }
/// ```
pub fn NodeRef::children(self : NodeRef) -> Array[NodeRef] {
  let all = []
  for e in self.entries() {
    all.append(e.1)
  }
  in_source_order(all, x => x)
}

///|
/// The field of this node that holds `child`, or `None` when `child` is
/// not a child of this node. It looks through all the fields on each call;
/// to get the field of every child, use `children_with_fields` or
/// `Tree::field_of`.
///
/// ```mbt check
/// test {
///   let sum = @syntax.NodeRef::Expr(@parser.parse_expression_text("a + b"))
///   let right = sum.field("right")[0]
///   debug_inspect(sum.field_of(right), content="Some(\"right\")")
///   debug_inspect(right.field_of(sum), content="None")
/// }
/// ```
pub fn NodeRef::field_of(self : NodeRef, child : NodeRef) -> String? {
  for e in self.entries() {
    if e.1.any(c => same(c, child)) {
      return Some(e.0)
    }
  }
  None
}

///|
/// Every node type: (category, kind, fields), one row per kind, the
/// fields in JSON order. The kinds and field names are the vocabulary of
/// `docs/ast-json.md`; a struct without a `kind` uses its category.
///
/// ```mbt check
/// test {
///   let rows = @syntax.kind_table()
///   let row = rows.filter(r => r.0 == "expression" && r.1 == "call")[0]
///   debug_inspect(row.2, content="[\"fun\", \"arguments\"]")
/// }
/// ```
pub fn kind_table() -> Array[(String, String, Array[String])] {
  let function_fields = ["arguments", "body", "return_annotation"]
  let no_fields : Array[String] = []
  let rows : Array[(String, String, Array[String])] = [
    ("module", "module", ["definitions"]),
    ("definition", "function", function_fields),
    ("definition", "type_alias", ["type_ast"]),
    ("definition", "custom_type", ["constructors"]),
    ("definition", "import", no_fields),
    ("definition", "module_constant", ["annotation", "value"]),
    ("statement", "expression", ["expression"]),
    (
      "statement",
      "assignment",
      ["value", "pattern", "assignment_kind", "annotation"],
    ),
    ("statement", "use", ["call", "assignments"]),
    ("statement", "assert", ["value", "message"]),
    ("expression", "int", no_fields),
    ("expression", "float", no_fields),
    ("expression", "string", no_fields),
    ("expression", "block", ["statements"]),
    ("expression", "var", no_fields),
    ("expression", "fn", function_fields),
    ("expression", "list", ["elements", "tail"]),
    ("expression", "call", ["fun", "arguments"]),
    ("expression", "bin_op", ["left", "right"]),
    ("expression", "pipeline", ["expressions"]),
    ("expression", "case", ["subjects", "clauses"]),
    ("expression", "field_access", ["container"]),
    ("expression", "tuple", ["elements"]),
    ("expression", "tuple_index", ["tuple"]),
    ("expression", "todo", ["message"]),
    ("expression", "panic", ["message"]),
    ("expression", "echo", ["expression", "message"]),
    ("expression", "bit_array", ["segments"]),
    ("expression", "record_update", ["constructor", "record", "arguments"]),
    ("expression", "negate_bool", ["value"]),
    ("expression", "negate_int", ["value"]),
    ("pattern", "int", no_fields),
    ("pattern", "float", no_fields),
    ("pattern", "string", no_fields),
    ("pattern", "variable", no_fields),
    ("pattern", "bit_array_size", ["size"]),
    ("pattern", "assign", ["pattern"]),
    ("pattern", "discard", no_fields),
    ("pattern", "list", ["elements", "tail"]),
    ("pattern", "constructor", ["arguments"]),
    ("pattern", "tuple", ["elements"]),
    ("pattern", "bit_array", ["segments"]),
    ("pattern", "string_prefix", no_fields),
    ("type", "constructor", ["arguments"]),
    ("type", "fn", ["arguments", "return_"]),
    ("type", "var", no_fields),
    ("type", "tuple", ["elements"]),
    ("type", "hole", no_fields),
    ("constant", "int", no_fields),
    ("constant", "float", no_fields),
    ("constant", "string", no_fields),
    ("constant", "tuple", ["elements"]),
    ("constant", "list", ["elements", "tail"]),
    ("constant", "record", ["arguments"]),
    ("constant", "record_update", ["record", "arguments"]),
    ("constant", "bit_array", ["segments"]),
    ("constant", "var", no_fields),
    ("constant", "binary_operator", ["left", "right"]),
    ("constant", "todo", ["message"]),
    ("clause_guard", "block", ["value"]),
    ("clause_guard", "binary_operator", ["left", "right"]),
    ("clause_guard", "not", ["expression"]),
    ("clause_guard", "var", no_fields),
    ("clause_guard", "tuple_index", ["tuple"]),
    ("clause_guard", "field_access", ["container"]),
    ("clause_guard", "constant", ["constant"]),
    ("bit_array_size", "int", no_fields),
    ("bit_array_size", "variable", no_fields),
    ("bit_array_size", "binary_operator", ["left", "right"]),
    ("bit_array_size", "block", ["inner"]),
    ("clause", "clause", ["pattern", "alternative_patterns", "guard", "then"]),
    ("arg", "arg", ["annotation"]),
    ("record_constructor", "record_constructor", ["arguments"]),
    ("record_constructor_arg", "record_constructor_arg", ["ast"]),
    ("use_assignment", "use_assignment", ["pattern", "annotation"]),
    ("tail_pattern", "tail_pattern", ["pattern"]),
    ("call_arg", "call_arg", ["value"]),
    ("record_update_arg", "record_update_arg", ["value"]),
    ("record_being_updated", "record_being_updated", ["base"]),
    ("bit_array_segment", "bit_array_segment", ["value", "options"]),
    ("bit_array_option", "bytes", no_fields),
    ("bit_array_option", "int", no_fields),
    ("bit_array_option", "float", no_fields),
    ("bit_array_option", "bits", no_fields),
    ("bit_array_option", "utf8", no_fields),
    ("bit_array_option", "utf16", no_fields),
    ("bit_array_option", "utf32", no_fields),
    ("bit_array_option", "utf8_codepoint", no_fields),
    ("bit_array_option", "utf16_codepoint", no_fields),
    ("bit_array_option", "utf32_codepoint", no_fields),
    ("bit_array_option", "signed", no_fields),
    ("bit_array_option", "unsigned", no_fields),
    ("bit_array_option", "big", no_fields),
    ("bit_array_option", "little", no_fields),
    ("bit_array_option", "native", no_fields),
    ("bit_array_option", "size", ["value"]),
    ("bit_array_option", "unit", no_fields),
  ]
  rows
}
