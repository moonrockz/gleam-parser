// Debug builds the same structural Repr as derive(Debug), with suspended
// descent and return. The core debug renderer applies its display depth limit
// after this complete representation has been built.

///|
async fn[A] repr_array_view(
  values : ArrayView[A],
  repr_value : async (A) -> @debug.Repr noraise + nocancel,
) -> @debug.Repr noraise + nocancel {
  let children = []
  for value in values {
    children.push(repr_value(value))
  }
  @debug.Repr::array(children)
}

///|
async fn[A] repr_option(
  value : A?,
  repr_value : async (A) -> @debug.Repr noraise + nocancel,
) -> @debug.Repr noraise + nocancel {
  match value {
    None => @debug.Repr::ctor("None", [])
    Some(v) => @debug.Repr::ctor("Some", [(None, repr_value(v))])
  }
}

///|
async fn repr_arg(
  runner : @work.Runner,
  value : Arg,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "names": @debug.Repr(value.names),
    "location": @debug.Repr(value.location),
    "annotation": repr_option(value.annotation, value => {
      repr_type_ast(runner, value)
    }),
  })
}

///|
async fn repr_type_ast(
  runner : @work.Runner,
  value : TypeAst,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Constructor(v0) =>
      @debug.Repr::ctor("Constructor", [
        (None, repr_type_ast_constructor(runner, v0)),
      ])
    Fn(v0) => @debug.Repr::ctor("Fn", [(None, repr_type_ast_fn(runner, v0))])
    Var(v0) => @debug.Repr::ctor("Var", [(None, @debug.Repr(v0))])
    Tuple(v0) =>
      @debug.Repr::ctor("Tuple", [(None, repr_type_ast_tuple(runner, v0))])
    Hole(v0) => @debug.Repr::ctor("Hole", [(None, @debug.Repr(v0))])
  }
}

///|
/// Build a complete structural debug representation without recursive calls.
pub impl @debug.Debug for TypeAst with fn to_repr(self) {
  let runner = @work.Runner()
  runner.run_total(() => repr_type_ast(runner, self))
}

///|
async fn repr_type_ast_constructor(
  runner : @work.Runner,
  value : TypeAstConstructor,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "name": @debug.Repr(value.name),
    "arguments": repr_array_view(value.arguments, value => {
      repr_type_ast(runner, value)
    }),
    "start_parentheses": @debug.Repr(value.start_parentheses),
  })
}

///|
async fn repr_type_ast_fn(
  runner : @work.Runner,
  value : TypeAstFn,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "arguments": repr_array_view(value.arguments, value => {
      repr_type_ast(runner, value)
    }),
    "return_": repr_type_ast(runner, value.return_),
  })
}

///|
async fn repr_type_ast_tuple(
  runner : @work.Runner,
  value : TypeAstTuple,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "elements": repr_array_view(value.elements, value => {
      repr_type_ast(runner, value)
    }),
  })
}

///|
async fn repr_statement(
  runner : @work.Runner,
  value : Statement,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Expression(v0) =>
      @debug.Repr::ctor("Expression", [(None, repr_expr(runner, v0))])
    Assignment(v0) =>
      @debug.Repr::ctor("Assignment", [(None, repr_assignment(runner, v0))])
    Use(v0) => @debug.Repr::ctor("Use", [(None, repr_use(runner, v0))])
    Assert(v0) => @debug.Repr::ctor("Assert", [(None, repr_assert(runner, v0))])
  }
}

///|
async fn repr_assignment(
  runner : @work.Runner,
  value : Assignment,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "value": repr_expr(runner, value.value),
    "pattern": repr_pattern(runner, value.pattern),
    "kind": repr_assignment_kind(runner, value.kind),
    "annotation": repr_option(value.annotation, value => {
      repr_type_ast(runner, value)
    }),
  })
}

///|
async fn repr_assignment_kind(
  runner : @work.Runner,
  value : AssignmentKind,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Let => @debug.Repr::ctor("Let", [])
    Generated => @debug.Repr::ctor("Generated", [])
    Assert(location=v0, assert_keyword_start=v1, message=v2) =>
      @debug.Repr::ctor("Assert", [
        (Some("location"), @debug.Repr(v0)),
        (Some("assert_keyword_start"), @debug.Repr(v1)),
        (Some("message"), repr_option(v2, value => repr_expr(runner, value))),
      ])
  }
}

///|
async fn repr_use(
  runner : @work.Runner,
  value : Use,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "call": repr_expr(runner, value.call),
    "location": @debug.Repr(value.location),
    "right_hand_side_location": @debug.Repr(value.right_hand_side_location),
    "assignments_location": @debug.Repr(value.assignments_location),
    "assignments": repr_array_view(value.assignments, value => {
      repr_use_assignment(runner, value)
    }),
  })
}

///|
async fn repr_use_assignment(
  runner : @work.Runner,
  value : UseAssignment,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "pattern": repr_pattern(runner, value.pattern),
    "annotation": repr_option(value.annotation, value => {
      repr_type_ast(runner, value)
    }),
  })
}

///|
async fn repr_assert(
  runner : @work.Runner,
  value : Assert,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "value": repr_expr(runner, value.value),
    "message": repr_option(value.message, value => repr_expr(runner, value)),
  })
}

///|
async fn repr_expr(
  runner : @work.Runner,
  value : Expr,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Int(location=v0, value=v1, int_value=v2) =>
      @debug.Repr::ctor("Int", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
        (Some("int_value"), @debug.Repr(v2)),
      ])
    Float(location=v0, value=v1, float_value=v2) =>
      @debug.Repr::ctor("Float", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
        (Some("float_value"), @debug.Repr(v2)),
      ])
    String(location=v0, value=v1) =>
      @debug.Repr::ctor("String", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
      ])
    Block(location=v0, statements=v1) =>
      @debug.Repr::ctor("Block", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("statements"),
          repr_array_view(v1, value => repr_statement(runner, value)),
        ),
      ])
    Var(location=v0, name=v1) =>
      @debug.Repr::ctor("Var", [
        (Some("location"), @debug.Repr(v0)),
        (Some("name"), @debug.Repr(v1)),
      ])
    Fn(
      location=v0,
      kind=v1,
      end_of_head_byte_index=v2,
      arguments=v3,
      body=v4,
      return_annotation=v5
    ) =>
      @debug.Repr::ctor("Fn", [
        (Some("location"), @debug.Repr(v0)),
        (Some("kind"), @debug.Repr(v1)),
        (Some("end_of_head_byte_index"), @debug.Repr(v2)),
        (
          Some("arguments"),
          repr_array_view(v3, value => repr_arg(runner, value)),
        ),
        (
          Some("body"),
          repr_array_view(v4, value => repr_statement(runner, value)),
        ),
        (
          Some("return_annotation"),
          repr_option(v5, value => repr_type_ast(runner, value)),
        ),
      ])
    List(location=v0, elements=v1, tail=v2) =>
      @debug.Repr::ctor("List", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("elements"),
          repr_array_view(v1, value => repr_expr(runner, value)),
        ),
        (Some("tail"), repr_option(v2, value => repr_expr(runner, value))),
      ])
    Call(location=v0, fun=v1, arguments=v2, open_parenthesis=v3) =>
      @debug.Repr::ctor("Call", [
        (Some("location"), @debug.Repr(v0)),
        (Some("fun"), repr_expr(runner, v1)),
        (
          Some("arguments"),
          repr_array_view(v2, value => {
            repr_call_arg(runner, value, value => repr_expr(runner, value))
          }),
        ),
        (Some("open_parenthesis"), @debug.Repr(v3)),
      ])
    BinOp(location=v0, operator=v1, operator_start=v2, left=v3, right=v4) =>
      @debug.Repr::ctor("BinOp", [
        (Some("location"), @debug.Repr(v0)),
        (Some("operator"), @debug.Repr(v1)),
        (Some("operator_start"), @debug.Repr(v2)),
        (Some("left"), repr_expr(runner, v3)),
        (Some("right"), repr_expr(runner, v4)),
      ])
    Pipeline(expressions=v0) =>
      @debug.Repr::ctor("Pipeline", [
        (
          Some("expressions"),
          repr_array_view(v0, value => repr_expr(runner, value)),
        ),
      ])
    Case(location=v0, subjects=v1, clauses=v2) =>
      @debug.Repr::ctor("Case", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("subjects"),
          repr_array_view(v1, value => repr_expr(runner, value)),
        ),
        (
          Some("clauses"),
          repr_option(v2, value => {
            repr_array_view(value, value => repr_clause(runner, value))
          }),
        ),
      ])
    FieldAccess(location=v0, label_location=v1, label=v2, container=v3) =>
      @debug.Repr::ctor("FieldAccess", [
        (Some("location"), @debug.Repr(v0)),
        (Some("label_location"), @debug.Repr(v1)),
        (Some("label"), @debug.Repr(v2)),
        (Some("container"), repr_expr(runner, v3)),
      ])
    Tuple(location=v0, elements=v1) =>
      @debug.Repr::ctor("Tuple", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("elements"),
          repr_array_view(v1, value => repr_expr(runner, value)),
        ),
      ])
    TupleIndex(location=v0, index=v1, tuple=v2) =>
      @debug.Repr::ctor("TupleIndex", [
        (Some("location"), @debug.Repr(v0)),
        (Some("index"), @debug.Repr(v1)),
        (Some("tuple"), repr_expr(runner, v2)),
      ])
    Todo(kind=v0, location=v1, message=v2) =>
      @debug.Repr::ctor("Todo", [
        (Some("kind"), @debug.Repr(v0)),
        (Some("location"), @debug.Repr(v1)),
        (Some("message"), repr_option(v2, value => repr_expr(runner, value))),
      ])
    Panic(location=v0, message=v1) =>
      @debug.Repr::ctor("Panic", [
        (Some("location"), @debug.Repr(v0)),
        (Some("message"), repr_option(v1, value => repr_expr(runner, value))),
      ])
    Echo(location=v0, keyword_end=v1, expression=v2, message=v3) =>
      @debug.Repr::ctor("Echo", [
        (Some("location"), @debug.Repr(v0)),
        (Some("keyword_end"), @debug.Repr(v1)),
        (Some("expression"), repr_option(v2, value => repr_expr(runner, value))),
        (Some("message"), repr_option(v3, value => repr_expr(runner, value))),
      ])
    BitArray(location=v0, segments=v1) =>
      @debug.Repr::ctor("BitArray", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("segments"),
          repr_array_view(v1, value => {
            repr_bit_array_segment(runner, value, value => {
              repr_expr(runner, value)
            })
          }),
        ),
      ])
    RecordUpdate(
      location=v0,
      spread_start=v1,
      constructor_=v2,
      record=v3,
      arguments=v4
    ) =>
      @debug.Repr::ctor("RecordUpdate", [
        (Some("location"), @debug.Repr(v0)),
        (Some("spread_start"), @debug.Repr(v1)),
        (Some("constructor_"), repr_expr(runner, v2)),
        (
          Some("record"),
          repr_record_being_updated(runner, v3, value => {
            repr_expr(runner, value)
          }),
        ),
        (
          Some("arguments"),
          repr_array_view(v4, value => {
            repr_record_update_arg(runner, value, value => {
              repr_expr(runner, value)
            })
          }),
        ),
      ])
    NegateBool(location=v0, value=v1) =>
      @debug.Repr::ctor("NegateBool", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), repr_expr(runner, v1)),
      ])
    NegateInt(location=v0, value=v1) =>
      @debug.Repr::ctor("NegateInt", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), repr_expr(runner, v1)),
      ])
  }
}

///|
/// Build a complete structural debug representation without recursive calls.
pub impl @debug.Debug for Expr with fn to_repr(self) {
  let runner = @work.Runner()
  runner.run_total(() => repr_expr(runner, self))
}

///|
async fn[A] repr_call_arg(
  runner : @work.Runner,
  value : CallArg[A],
  repr_value : async (A) -> @debug.Repr noraise + nocancel,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "label": @debug.Repr(value.label),
    "location": @debug.Repr(value.location),
    "value": repr_value(value.value),
    "implicit": @debug.Repr(value.implicit),
  })
}

///|
async fn repr_clause(
  runner : @work.Runner,
  value : Clause,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "pattern": repr_array_view(value.pattern, value => {
      repr_pattern(runner, value)
    }),
    "alternative_patterns": repr_array_view(value.alternative_patterns, value => {
      repr_array_view(value, value => repr_pattern(runner, value))
    }),
    "guard_": repr_option(value.guard_, value => {
      repr_clause_guard(runner, value)
    }),
    "then": repr_expr(runner, value.then),
  })
}

///|
async fn repr_clause_guard(
  runner : @work.Runner,
  value : ClauseGuard,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Block(location=v0, value=v1) =>
      @debug.Repr::ctor("Block", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), repr_clause_guard(runner, v1)),
      ])
    BinaryOperator(
      location=v0,
      operator=v1,
      operator_start=v2,
      left=v3,
      right=v4
    ) =>
      @debug.Repr::ctor("BinaryOperator", [
        (Some("location"), @debug.Repr(v0)),
        (Some("operator"), @debug.Repr(v1)),
        (Some("operator_start"), @debug.Repr(v2)),
        (Some("left"), repr_clause_guard(runner, v3)),
        (Some("right"), repr_clause_guard(runner, v4)),
      ])
    Not(location=v0, expression=v1) =>
      @debug.Repr::ctor("Not", [
        (Some("location"), @debug.Repr(v0)),
        (Some("expression"), repr_clause_guard(runner, v1)),
      ])
    Var(location=v0, name=v1) =>
      @debug.Repr::ctor("Var", [
        (Some("location"), @debug.Repr(v0)),
        (Some("name"), @debug.Repr(v1)),
      ])
    TupleIndex(location=v0, index=v1, tuple=v2) =>
      @debug.Repr::ctor("TupleIndex", [
        (Some("location"), @debug.Repr(v0)),
        (Some("index"), @debug.Repr(v1)),
        (Some("tuple"), repr_clause_guard(runner, v2)),
      ])
    FieldAccess(label_location=v0, index=v1, label=v2, container=v3) =>
      @debug.Repr::ctor("FieldAccess", [
        (Some("label_location"), @debug.Repr(v0)),
        (Some("index"), @debug.Repr(v1)),
        (Some("label"), @debug.Repr(v2)),
        (Some("container"), repr_clause_guard(runner, v3)),
      ])
    Constant(v0) =>
      @debug.Repr::ctor("Constant", [(None, repr_constant(runner, v0))])
  }
}

///|
/// Build a complete structural debug representation without recursive calls.
pub impl @debug.Debug for ClauseGuard with fn to_repr(self) {
  let runner = @work.Runner()
  runner.run_total(() => repr_clause_guard(runner, self))
}

///|
async fn repr_pattern(
  runner : @work.Runner,
  value : Pattern,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Int(location=v0, value=v1, int_value=v2) =>
      @debug.Repr::ctor("Int", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
        (Some("int_value"), @debug.Repr(v2)),
      ])
    Float(location=v0, value=v1, float_value=v2) =>
      @debug.Repr::ctor("Float", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
        (Some("float_value"), @debug.Repr(v2)),
      ])
    String(location=v0, value=v1) =>
      @debug.Repr::ctor("String", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
      ])
    Variable(location=v0, name=v1) =>
      @debug.Repr::ctor("Variable", [
        (Some("location"), @debug.Repr(v0)),
        (Some("name"), @debug.Repr(v1)),
      ])
    BitArraySize(v0) =>
      @debug.Repr::ctor("BitArraySize", [
        (None, repr_bit_array_size(runner, v0)),
      ])
    Assign(name=v0, location=v1, pattern=v2) =>
      @debug.Repr::ctor("Assign", [
        (Some("name"), @debug.Repr(v0)),
        (Some("location"), @debug.Repr(v1)),
        (Some("pattern"), repr_pattern(runner, v2)),
      ])
    Discard(name=v0, location=v1) =>
      @debug.Repr::ctor("Discard", [
        (Some("name"), @debug.Repr(v0)),
        (Some("location"), @debug.Repr(v1)),
      ])
    List(location=v0, elements=v1, tail=v2) =>
      @debug.Repr::ctor("List", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("elements"),
          repr_array_view(v1, value => repr_pattern(runner, value)),
        ),
        (
          Some("tail"),
          repr_option(v2, value => repr_tail_pattern(runner, value)),
        ),
      ])
    Constructor(
      location=v0,
      name_location=v1,
      name=v2,
      arguments=v3,
      module_=v4,
      spread=v5
    ) =>
      @debug.Repr::ctor("Constructor", [
        (Some("location"), @debug.Repr(v0)),
        (Some("name_location"), @debug.Repr(v1)),
        (Some("name"), @debug.Repr(v2)),
        (
          Some("arguments"),
          repr_array_view(v3, value => {
            repr_call_arg(runner, value, value => repr_pattern(runner, value))
          }),
        ),
        (Some("module_"), @debug.Repr(v4)),
        (Some("spread"), @debug.Repr(v5)),
      ])
    Tuple(location=v0, elements=v1) =>
      @debug.Repr::ctor("Tuple", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("elements"),
          repr_array_view(v1, value => repr_pattern(runner, value)),
        ),
      ])
    BitArray(location=v0, segments=v1) =>
      @debug.Repr::ctor("BitArray", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("segments"),
          repr_array_view(v1, value => {
            repr_bit_array_segment(runner, value, value => {
              repr_pattern(runner, value)
            })
          }),
        ),
      ])
    StringPrefix(
      location=v0,
      left_location=v1,
      left_side_assignment=v2,
      right_location=v3,
      left_side_string=v4,
      right_side_assignment=v5
    ) =>
      @debug.Repr::ctor("StringPrefix", [
        (Some("location"), @debug.Repr(v0)),
        (Some("left_location"), @debug.Repr(v1)),
        (Some("left_side_assignment"), @debug.Repr(v2)),
        (Some("right_location"), @debug.Repr(v3)),
        (Some("left_side_string"), @debug.Repr(v4)),
        (Some("right_side_assignment"), @debug.Repr(v5)),
      ])
  }
}

///|
/// Build a complete structural debug representation without recursive calls.
pub impl @debug.Debug for Pattern with fn to_repr(self) {
  let runner = @work.Runner()
  runner.run_total(() => repr_pattern(runner, self))
}

///|
async fn repr_tail_pattern(
  runner : @work.Runner,
  value : TailPattern,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "pattern": repr_pattern(runner, value.pattern),
  })
}

///|
async fn repr_bit_array_size(
  runner : @work.Runner,
  value : BitArraySize,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Int(location=v0, value=v1, int_value=v2) =>
      @debug.Repr::ctor("Int", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
        (Some("int_value"), @debug.Repr(v2)),
      ])
    Variable(location=v0, name=v1) =>
      @debug.Repr::ctor("Variable", [
        (Some("location"), @debug.Repr(v0)),
        (Some("name"), @debug.Repr(v1)),
      ])
    BinaryOperator(location=v0, operator=v1, left=v2, right=v3) =>
      @debug.Repr::ctor("BinaryOperator", [
        (Some("location"), @debug.Repr(v0)),
        (Some("operator"), @debug.Repr(v1)),
        (Some("left"), repr_bit_array_size(runner, v2)),
        (Some("right"), repr_bit_array_size(runner, v3)),
      ])
    Block(location=v0, inner=v1) =>
      @debug.Repr::ctor("Block", [
        (Some("location"), @debug.Repr(v0)),
        (Some("inner"), repr_bit_array_size(runner, v1)),
      ])
  }
}

///|
/// Build a complete structural debug representation without recursive calls.
pub impl @debug.Debug for BitArraySize with fn to_repr(self) {
  let runner = @work.Runner()
  runner.run_total(() => repr_bit_array_size(runner, self))
}

///|
async fn[V] repr_bit_array_segment(
  runner : @work.Runner,
  value : BitArraySegment[V],
  repr_value : async (V) -> @debug.Repr noraise + nocancel,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "location": @debug.Repr(value.location),
    "value": repr_value(value.value),
    "options": repr_array_view(value.options, value => {
      repr_bit_array_option(runner, value, value => repr_value(value))
    }),
  })
}

///|
async fn[V] repr_bit_array_option(
  runner : @work.Runner,
  value : BitArrayOption[V],
  repr_value : async (V) -> @debug.Repr noraise + nocancel,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Bytes(location=v0) =>
      @debug.Repr::ctor("Bytes", [(Some("location"), @debug.Repr(v0))])
    Int(location=v0) =>
      @debug.Repr::ctor("Int", [(Some("location"), @debug.Repr(v0))])
    Float(location=v0) =>
      @debug.Repr::ctor("Float", [(Some("location"), @debug.Repr(v0))])
    Bits(location=v0) =>
      @debug.Repr::ctor("Bits", [(Some("location"), @debug.Repr(v0))])
    Utf8(location=v0) =>
      @debug.Repr::ctor("Utf8", [(Some("location"), @debug.Repr(v0))])
    Utf16(location=v0) =>
      @debug.Repr::ctor("Utf16", [(Some("location"), @debug.Repr(v0))])
    Utf32(location=v0) =>
      @debug.Repr::ctor("Utf32", [(Some("location"), @debug.Repr(v0))])
    Utf8Codepoint(location=v0) =>
      @debug.Repr::ctor("Utf8Codepoint", [(Some("location"), @debug.Repr(v0))])
    Utf16Codepoint(location=v0) =>
      @debug.Repr::ctor("Utf16Codepoint", [(Some("location"), @debug.Repr(v0))])
    Utf32Codepoint(location=v0) =>
      @debug.Repr::ctor("Utf32Codepoint", [(Some("location"), @debug.Repr(v0))])
    Signed(location=v0) =>
      @debug.Repr::ctor("Signed", [(Some("location"), @debug.Repr(v0))])
    Unsigned(location=v0) =>
      @debug.Repr::ctor("Unsigned", [(Some("location"), @debug.Repr(v0))])
    Big(location=v0) =>
      @debug.Repr::ctor("Big", [(Some("location"), @debug.Repr(v0))])
    Little(location=v0) =>
      @debug.Repr::ctor("Little", [(Some("location"), @debug.Repr(v0))])
    Native(location=v0) =>
      @debug.Repr::ctor("Native", [(Some("location"), @debug.Repr(v0))])
    Size(location=v0, value=v1, short_form=v2) =>
      @debug.Repr::ctor("Size", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), repr_value(v1)),
        (Some("short_form"), @debug.Repr(v2)),
      ])
    Unit(location=v0, value=v1) =>
      @debug.Repr::ctor("Unit", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
      ])
  }
}

///|
async fn[A] repr_record_being_updated(
  runner : @work.Runner,
  value : RecordBeingUpdated[A],
  repr_value : async (A) -> @debug.Repr noraise + nocancel,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "base": repr_value(value.base),
    "location": @debug.Repr(value.location),
  })
}

///|
async fn[A] repr_record_update_arg(
  runner : @work.Runner,
  value : RecordUpdateArg[A],
  repr_value : async (A) -> @debug.Repr noraise + nocancel,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  @debug.Repr::record({
    "label": @debug.Repr(value.label),
    "location": @debug.Repr(value.location),
    "value": repr_value(value.value),
  })
}

///|
async fn repr_constant(
  runner : @work.Runner,
  value : Constant,
) -> @debug.Repr noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match value {
    Int(location=v0, value=v1, int_value=v2) =>
      @debug.Repr::ctor("Int", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
        (Some("int_value"), @debug.Repr(v2)),
      ])
    Float(location=v0, value=v1, float_value=v2) =>
      @debug.Repr::ctor("Float", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
        (Some("float_value"), @debug.Repr(v2)),
      ])
    String(location=v0, value=v1) =>
      @debug.Repr::ctor("String", [
        (Some("location"), @debug.Repr(v0)),
        (Some("value"), @debug.Repr(v1)),
      ])
    Tuple(location=v0, elements=v1) =>
      @debug.Repr::ctor("Tuple", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("elements"),
          repr_array_view(v1, value => repr_constant(runner, value)),
        ),
      ])
    List(location=v0, elements=v1, tail=v2) =>
      @debug.Repr::ctor("List", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("elements"),
          repr_array_view(v1, value => repr_constant(runner, value)),
        ),
        (Some("tail"), repr_option(v2, value => repr_constant(runner, value))),
      ])
    Record(
      location=v0,
      arguments_start_position=v1,
      module_=v2,
      name=v3,
      arguments=v4
    ) =>
      @debug.Repr::ctor("Record", [
        (Some("location"), @debug.Repr(v0)),
        (Some("arguments_start_position"), @debug.Repr(v1)),
        (Some("module_"), @debug.Repr(v2)),
        (Some("name"), @debug.Repr(v3)),
        (
          Some("arguments"),
          repr_option(v4, value => {
            repr_array_view(value, value => {
              repr_call_arg(runner, value, value => repr_constant(runner, value))
            })
          }),
        ),
      ])
    RecordUpdate(
      location=v0,
      constructor_location=v1,
      module_=v2,
      name=v3,
      record=v4,
      arguments=v5
    ) =>
      @debug.Repr::ctor("RecordUpdate", [
        (Some("location"), @debug.Repr(v0)),
        (Some("constructor_location"), @debug.Repr(v1)),
        (Some("module_"), @debug.Repr(v2)),
        (Some("name"), @debug.Repr(v3)),
        (
          Some("record"),
          repr_record_being_updated(runner, v4, value => {
            repr_constant(runner, value)
          }),
        ),
        (
          Some("arguments"),
          repr_array_view(v5, value => {
            repr_record_update_arg(runner, value, value => {
              repr_constant(runner, value)
            })
          }),
        ),
      ])
    BitArray(location=v0, segments=v1) =>
      @debug.Repr::ctor("BitArray", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("segments"),
          repr_array_view(v1, value => {
            repr_bit_array_segment(runner, value, value => {
              repr_constant(runner, value)
            })
          }),
        ),
      ])
    Var(location=v0, module_=v1, name=v2) =>
      @debug.Repr::ctor("Var", [
        (Some("location"), @debug.Repr(v0)),
        (Some("module_"), @debug.Repr(v1)),
        (Some("name"), @debug.Repr(v2)),
      ])
    BinaryOperator(
      location=v0,
      operator_start=v1,
      operator=v2,
      left=v3,
      right=v4
    ) =>
      @debug.Repr::ctor("BinaryOperator", [
        (Some("location"), @debug.Repr(v0)),
        (Some("operator_start"), @debug.Repr(v1)),
        (Some("operator"), @debug.Repr(v2)),
        (Some("left"), repr_constant(runner, v3)),
        (Some("right"), repr_constant(runner, v4)),
      ])
    Todo(location=v0, message=v1) =>
      @debug.Repr::ctor("Todo", [
        (Some("location"), @debug.Repr(v0)),
        (
          Some("message"),
          repr_option(v1, value => repr_constant(runner, value)),
        ),
      ])
  }
}

///|
/// Build a complete structural debug representation without recursive calls.
pub impl @debug.Debug for Constant with fn to_repr(self) {
  let runner = @work.Runner()
  runner.run_total(() => repr_constant(runner, self))
}
