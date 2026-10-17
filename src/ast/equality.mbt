// Structural equality uses compiler-generated continuations. Keep each field
// here in step with types.mbt, including derived float_value fields that the
// canonical JSON intentionally omits.

///|
async fn[A] equal_array_view(
  left : ArrayView[A],
  right : ArrayView[A],
  equal_value : async (A, A) -> Bool noraise + nocancel,
) -> Bool noraise + nocancel {
  guard left.length() == right.length() else { return false }
  for i in 0..<left.length() {
    guard equal_value(left[i], right[i]) else { return false }
  }
  true
}

///|
async fn[A] equal_option(
  left : A?,
  right : A?,
  equal_value : async (A, A) -> Bool noraise + nocancel,
) -> Bool noraise + nocancel {
  match (left, right) {
    (None, None) => true
    (Some(a), Some(b)) => equal_value(a, b)
    _ => false
  }
}

///|
async fn equal_arg(
  runner : @work.Runner,
  left : Arg,
  right : Arg,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.names == right.names &&
  left.location == right.location &&
  equal_option(left.annotation, right.annotation, (left, right) => {
    equal_type_ast(runner, left, right)
  })
}

///|
async fn equal_type_ast(
  runner : @work.Runner,
  left : TypeAst,
  right : TypeAst,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (Constructor(a0), Constructor(b0)) =>
      equal_type_ast_constructor(runner, a0, b0)
    (Fn(a0), Fn(b0)) => equal_type_ast_fn(runner, a0, b0)
    (Var(a0), Var(b0)) => a0 == b0
    (Tuple(a0), Tuple(b0)) => equal_type_ast_tuple(runner, a0, b0)
    (Hole(a0), Hole(b0)) => a0 == b0
    _ => false
  }
}

///|
/// Compare every AST field without recursive machine-stack growth.
pub impl Eq for TypeAst with fn equal(left, right) {
  let runner = @work.Runner()
  runner.run_total(() => equal_type_ast(runner, left, right))
}

///|
async fn equal_type_ast_constructor(
  runner : @work.Runner,
  left : TypeAstConstructor,
  right : TypeAstConstructor,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  left.name == right.name &&
  equal_array_view(left.arguments, right.arguments, (left, right) => {
    equal_type_ast(runner, left, right)
  }) &&
  left.start_parentheses == right.start_parentheses
}

///|
async fn equal_type_ast_fn(
  runner : @work.Runner,
  left : TypeAstFn,
  right : TypeAstFn,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_array_view(left.arguments, right.arguments, (left, right) => {
    equal_type_ast(runner, left, right)
  }) &&
  equal_type_ast(runner, left.return_, right.return_)
}

///|
async fn equal_type_ast_tuple(
  runner : @work.Runner,
  left : TypeAstTuple,
  right : TypeAstTuple,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_array_view(left.elements, right.elements, (left, right) => {
    equal_type_ast(runner, left, right)
  })
}

///|
async fn equal_statement(
  runner : @work.Runner,
  left : Statement,
  right : Statement,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (Expression(a0), Expression(b0)) => equal_expr(runner, a0, b0)
    (Assignment(a0), Assignment(b0)) => equal_assignment(runner, a0, b0)
    (Use(a0), Use(b0)) => equal_use(runner, a0, b0)
    (Assert(a0), Assert(b0)) => equal_assert(runner, a0, b0)
    _ => false
  }
}

///|
async fn equal_assignment(
  runner : @work.Runner,
  left : Assignment,
  right : Assignment,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_expr(runner, left.value, right.value) &&
  equal_pattern(runner, left.pattern, right.pattern) &&
  equal_assignment_kind(runner, left.kind, right.kind) &&
  equal_option(left.annotation, right.annotation, (left, right) => {
    equal_type_ast(runner, left, right)
  })
}

///|
async fn equal_assignment_kind(
  runner : @work.Runner,
  left : AssignmentKind,
  right : AssignmentKind,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (Let, Let) => true
    (Generated, Generated) => true
    (
      Assert(location=a0, assert_keyword_start=a1, message=a2),
      Assert(location=b0, assert_keyword_start=b1, message=b2),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      equal_option(a2, b2, (left, right) => equal_expr(runner, left, right))
    _ => false
  }
}

///|
async fn equal_use(
  runner : @work.Runner,
  left : Use,
  right : Use,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  equal_expr(runner, left.call, right.call) &&
  left.location == right.location &&
  left.right_hand_side_location == right.right_hand_side_location &&
  left.assignments_location == right.assignments_location &&
  equal_array_view(left.assignments, right.assignments, (left, right) => {
    equal_use_assignment(runner, left, right)
  })
}

///|
async fn equal_use_assignment(
  runner : @work.Runner,
  left : UseAssignment,
  right : UseAssignment,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_pattern(runner, left.pattern, right.pattern) &&
  equal_option(left.annotation, right.annotation, (left, right) => {
    equal_type_ast(runner, left, right)
  })
}

///|
async fn equal_assert(
  runner : @work.Runner,
  left : Assert,
  right : Assert,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_expr(runner, left.value, right.value) &&
  equal_option(left.message, right.message, (left, right) => {
    equal_expr(runner, left, right)
  })
}

///|
async fn equal_expr(
  runner : @work.Runner,
  left : Expr,
  right : Expr,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (
      Int(location=a0, value=a1, int_value=a2),
      Int(location=b0, value=b1, int_value=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (
      Float(location=a0, value=a1, float_value=a2),
      Float(location=b0, value=b1, float_value=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (String(location=a0, value=a1), String(location=b0, value=b1)) =>
      a0 == b0 && a1 == b1
    (Block(location=a0, statements=a1), Block(location=b0, statements=b1)) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_statement(runner, left, right)
      })
    (Var(location=a0, name=a1), Var(location=b0, name=b1)) =>
      a0 == b0 && a1 == b1
    (
      Fn(
        location=a0,
        kind=a1,
        end_of_head_byte_index=a2,
        arguments=a3,
        body=a4,
        return_annotation=a5
      ),
      Fn(
        location=b0,
        kind=b1,
        end_of_head_byte_index=b2,
        arguments=b3,
        body=b4,
        return_annotation=b5
      ),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      a2 == b2 &&
      equal_array_view(a3, b3, (left, right) => equal_arg(runner, left, right)) &&
      equal_array_view(a4, b4, (left, right) => {
        equal_statement(runner, left, right)
      }) &&
      equal_option(a5, b5, (left, right) => equal_type_ast(runner, left, right))
    (
      List(location=a0, elements=a1, tail=a2),
      List(location=b0, elements=b1, tail=b2),
    ) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => equal_expr(runner, left, right)) &&
      equal_option(a2, b2, (left, right) => equal_expr(runner, left, right))
    (
      Call(location=a0, fun=a1, arguments=a2, open_parenthesis=a3),
      Call(location=b0, fun=b1, arguments=b2, open_parenthesis=b3),
    ) =>
      a0 == b0 &&
      equal_expr(runner, a1, b1) &&
      equal_array_view(a2, b2, (left, right) => {
        equal_call_arg(runner, left, right, (left, right) => {
          equal_expr(runner, left, right)
        })
      }) &&
      a3 == b3
    (
      BinOp(location=a0, operator=a1, operator_start=a2, left=a3, right=a4),
      BinOp(location=b0, operator=b1, operator_start=b2, left=b3, right=b4),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      a2 == b2 &&
      equal_expr(runner, a3, b3) &&
      equal_expr(runner, a4, b4)
    (Pipeline(expressions=a0), Pipeline(expressions=b0)) =>
      equal_array_view(a0, b0, (left, right) => equal_expr(runner, left, right))
    (
      Case(location=a0, subjects=a1, clauses=a2),
      Case(location=b0, subjects=b1, clauses=b2),
    ) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => equal_expr(runner, left, right)) &&
      equal_option(a2, b2, (left, right) => {
        equal_array_view(left, right, (left, right) => {
          equal_clause(runner, left, right)
        })
      })
    (
      FieldAccess(location=a0, label_location=a1, label=a2, container=a3),
      FieldAccess(location=b0, label_location=b1, label=b2, container=b3),
    ) => a0 == b0 && a1 == b1 && a2 == b2 && equal_expr(runner, a3, b3)
    (Tuple(location=a0, elements=a1), Tuple(location=b0, elements=b1)) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => equal_expr(runner, left, right))
    (
      TupleIndex(location=a0, index=a1, tuple=a2),
      TupleIndex(location=b0, index=b1, tuple=b2),
    ) => a0 == b0 && a1 == b1 && equal_expr(runner, a2, b2)
    (
      Todo(kind=a0, location=a1, message=a2),
      Todo(kind=b0, location=b1, message=b2),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      equal_option(a2, b2, (left, right) => equal_expr(runner, left, right))
    (Panic(location=a0, message=a1), Panic(location=b0, message=b1)) =>
      a0 == b0 &&
      equal_option(a1, b1, (left, right) => equal_expr(runner, left, right))
    (
      Echo(location=a0, keyword_end=a1, expression=a2, message=a3),
      Echo(location=b0, keyword_end=b1, expression=b2, message=b3),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      equal_option(a2, b2, (left, right) => equal_expr(runner, left, right)) &&
      equal_option(a3, b3, (left, right) => equal_expr(runner, left, right))
    (BitArray(location=a0, segments=a1), BitArray(location=b0, segments=b1)) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_bit_array_segment(runner, left, right, (left, right) => {
          equal_expr(runner, left, right)
        })
      })
    (
      RecordUpdate(
        location=a0,
        spread_start=a1,
        constructor_=a2,
        record=a3,
        arguments=a4
      ),
      RecordUpdate(
        location=b0,
        spread_start=b1,
        constructor_=b2,
        record=b3,
        arguments=b4
      ),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      equal_expr(runner, a2, b2) &&
      equal_record_being_updated(runner, a3, b3, (left, right) => {
        equal_expr(runner, left, right)
      }) &&
      equal_array_view(a4, b4, (left, right) => {
        equal_record_update_arg(runner, left, right, (left, right) => {
          equal_expr(runner, left, right)
        })
      })
    (NegateBool(location=a0, value=a1), NegateBool(location=b0, value=b1)) =>
      a0 == b0 && equal_expr(runner, a1, b1)
    (NegateInt(location=a0, value=a1), NegateInt(location=b0, value=b1)) =>
      a0 == b0 && equal_expr(runner, a1, b1)
    _ => false
  }
}

///|
/// Compare every AST field without recursive machine-stack growth.
pub impl Eq for Expr with fn equal(left, right) {
  let runner = @work.Runner()
  runner.run_total(() => equal_expr(runner, left, right))
}

///|
async fn[A] equal_call_arg(
  runner : @work.Runner,
  left : CallArg[A],
  right : CallArg[A],
  equal_value : async (A, A) -> Bool noraise + nocancel,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.label == right.label &&
  left.location == right.location &&
  equal_value(left.value, right.value) &&
  left.implicit == right.implicit
}

///|
async fn equal_clause(
  runner : @work.Runner,
  left : Clause,
  right : Clause,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_array_view(left.pattern, right.pattern, (left, right) => {
    equal_pattern(runner, left, right)
  }) &&
  equal_array_view(left.alternative_patterns, right.alternative_patterns, (
    left,
    right,
  ) => {
    equal_array_view(left, right, (left, right) => {
      equal_pattern(runner, left, right)
    })
  }) &&
  equal_option(left.guard_, right.guard_, (left, right) => {
    equal_clause_guard(runner, left, right)
  }) &&
  equal_expr(runner, left.then, right.then)
}

///|
async fn equal_clause_guard(
  runner : @work.Runner,
  left : ClauseGuard,
  right : ClauseGuard,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (Block(location=a0, value=a1), Block(location=b0, value=b1)) =>
      a0 == b0 && equal_clause_guard(runner, a1, b1)
    (
      BinaryOperator(
        location=a0,
        operator=a1,
        operator_start=a2,
        left=a3,
        right=a4
      ),
      BinaryOperator(
        location=b0,
        operator=b1,
        operator_start=b2,
        left=b3,
        right=b4
      ),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      a2 == b2 &&
      equal_clause_guard(runner, a3, b3) &&
      equal_clause_guard(runner, a4, b4)
    (Not(location=a0, expression=a1), Not(location=b0, expression=b1)) =>
      a0 == b0 && equal_clause_guard(runner, a1, b1)
    (Var(location=a0, name=a1), Var(location=b0, name=b1)) =>
      a0 == b0 && a1 == b1
    (
      TupleIndex(location=a0, index=a1, tuple=a2),
      TupleIndex(location=b0, index=b1, tuple=b2),
    ) => a0 == b0 && a1 == b1 && equal_clause_guard(runner, a2, b2)
    (
      FieldAccess(label_location=a0, index=a1, label=a2, container=a3),
      FieldAccess(label_location=b0, index=b1, label=b2, container=b3),
    ) => a0 == b0 && a1 == b1 && a2 == b2 && equal_clause_guard(runner, a3, b3)
    (Constant(a0), Constant(b0)) => equal_constant(runner, a0, b0)
    _ => false
  }
}

///|
/// Compare every AST field without recursive machine-stack growth.
pub impl Eq for ClauseGuard with fn equal(left, right) {
  let runner = @work.Runner()
  runner.run_total(() => equal_clause_guard(runner, left, right))
}

///|
async fn equal_pattern(
  runner : @work.Runner,
  left : Pattern,
  right : Pattern,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (
      Int(location=a0, value=a1, int_value=a2),
      Int(location=b0, value=b1, int_value=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (
      Float(location=a0, value=a1, float_value=a2),
      Float(location=b0, value=b1, float_value=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (String(location=a0, value=a1), String(location=b0, value=b1)) =>
      a0 == b0 && a1 == b1
    (Variable(location=a0, name=a1), Variable(location=b0, name=b1)) =>
      a0 == b0 && a1 == b1
    (BitArraySize(a0), BitArraySize(b0)) => equal_bit_array_size(runner, a0, b0)
    (
      Assign(name=a0, location=a1, pattern=a2),
      Assign(name=b0, location=b1, pattern=b2),
    ) => a0 == b0 && a1 == b1 && equal_pattern(runner, a2, b2)
    (Discard(name=a0, location=a1), Discard(name=b0, location=b1)) =>
      a0 == b0 && a1 == b1
    (
      List(location=a0, elements=a1, tail=a2),
      List(location=b0, elements=b1, tail=b2),
    ) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_pattern(runner, left, right)
      }) &&
      equal_option(a2, b2, (left, right) => {
        equal_tail_pattern(runner, left, right)
      })
    (
      Constructor(
        location=a0,
        name_location=a1,
        name=a2,
        arguments=a3,
        module_=a4,
        spread=a5
      ),
      Constructor(
        location=b0,
        name_location=b1,
        name=b2,
        arguments=b3,
        module_=b4,
        spread=b5
      ),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      a2 == b2 &&
      equal_array_view(a3, b3, (left, right) => {
        equal_call_arg(runner, left, right, (left, right) => {
          equal_pattern(runner, left, right)
        })
      }) &&
      a4 == b4 &&
      a5 == b5
    (Tuple(location=a0, elements=a1), Tuple(location=b0, elements=b1)) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_pattern(runner, left, right)
      })
    (BitArray(location=a0, segments=a1), BitArray(location=b0, segments=b1)) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_bit_array_segment(runner, left, right, (left, right) => {
          equal_pattern(runner, left, right)
        })
      })
    (
      StringPrefix(
        location=a0,
        left_location=a1,
        left_side_assignment=a2,
        right_location=a3,
        left_side_string=a4,
        right_side_assignment=a5
      ),
      StringPrefix(
        location=b0,
        left_location=b1,
        left_side_assignment=b2,
        right_location=b3,
        left_side_string=b4,
        right_side_assignment=b5
      ),
    ) => a0 == b0 && a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5
    _ => false
  }
}

///|
/// Compare every AST field without recursive machine-stack growth.
pub impl Eq for Pattern with fn equal(left, right) {
  let runner = @work.Runner()
  runner.run_total(() => equal_pattern(runner, left, right))
}

///|
async fn equal_tail_pattern(
  runner : @work.Runner,
  left : TailPattern,
  right : TailPattern,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_pattern(runner, left.pattern, right.pattern)
}

///|
async fn equal_bit_array_size(
  runner : @work.Runner,
  left : BitArraySize,
  right : BitArraySize,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (
      Int(location=a0, value=a1, int_value=a2),
      Int(location=b0, value=b1, int_value=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (Variable(location=a0, name=a1), Variable(location=b0, name=b1)) =>
      a0 == b0 && a1 == b1
    (
      BinaryOperator(location=a0, operator=a1, left=a2, right=a3),
      BinaryOperator(location=b0, operator=b1, left=b2, right=b3),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      equal_bit_array_size(runner, a2, b2) &&
      equal_bit_array_size(runner, a3, b3)
    (Block(location=a0, inner=a1), Block(location=b0, inner=b1)) =>
      a0 == b0 && equal_bit_array_size(runner, a1, b1)
    _ => false
  }
}

///|
/// Compare every AST field without recursive machine-stack growth.
pub impl Eq for BitArraySize with fn equal(left, right) {
  let runner = @work.Runner()
  runner.run_total(() => equal_bit_array_size(runner, left, right))
}

///|
async fn[V] equal_bit_array_segment(
  runner : @work.Runner,
  left : BitArraySegment[V],
  right : BitArraySegment[V],
  equal_value : async (V, V) -> Bool noraise + nocancel,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.location == right.location &&
  equal_value(left.value, right.value) &&
  equal_array_view(left.options, right.options, (left, right) => {
    equal_bit_array_option(runner, left, right, (left, right) => {
      equal_value(left, right)
    })
  })
}

///|
async fn[V] equal_bit_array_option(
  runner : @work.Runner,
  left : BitArrayOption[V],
  right : BitArrayOption[V],
  equal_value : async (V, V) -> Bool noraise + nocancel,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (Bytes(location=a0), Bytes(location=b0)) => a0 == b0
    (Int(location=a0), Int(location=b0)) => a0 == b0
    (Float(location=a0), Float(location=b0)) => a0 == b0
    (Bits(location=a0), Bits(location=b0)) => a0 == b0
    (Utf8(location=a0), Utf8(location=b0)) => a0 == b0
    (Utf16(location=a0), Utf16(location=b0)) => a0 == b0
    (Utf32(location=a0), Utf32(location=b0)) => a0 == b0
    (Utf8Codepoint(location=a0), Utf8Codepoint(location=b0)) => a0 == b0
    (Utf16Codepoint(location=a0), Utf16Codepoint(location=b0)) => a0 == b0
    (Utf32Codepoint(location=a0), Utf32Codepoint(location=b0)) => a0 == b0
    (Signed(location=a0), Signed(location=b0)) => a0 == b0
    (Unsigned(location=a0), Unsigned(location=b0)) => a0 == b0
    (Big(location=a0), Big(location=b0)) => a0 == b0
    (Little(location=a0), Little(location=b0)) => a0 == b0
    (Native(location=a0), Native(location=b0)) => a0 == b0
    (
      Size(location=a0, value=a1, short_form=a2),
      Size(location=b0, value=b1, short_form=b2),
    ) => a0 == b0 && equal_value(a1, b1) && a2 == b2
    (Unit(location=a0, value=a1), Unit(location=b0, value=b1)) =>
      a0 == b0 && a1 == b1
    _ => false
  }
}

///|
async fn[A] equal_record_being_updated(
  runner : @work.Runner,
  left : RecordBeingUpdated[A],
  right : RecordBeingUpdated[A],
  equal_value : async (A, A) -> Bool noraise + nocancel,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  equal_value(left.base, right.base) && left.location == right.location
}

///|
async fn[A] equal_record_update_arg(
  runner : @work.Runner,
  left : RecordUpdateArg[A],
  right : RecordUpdateArg[A],
  equal_value : async (A, A) -> Bool noraise + nocancel,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  left.label == right.label &&
  left.location == right.location &&
  equal_value(left.value, right.value)
}

///|
async fn equal_constant(
  runner : @work.Runner,
  left : Constant,
  right : Constant,
) -> Bool noraise + nocancel {
  runner.pause()
  defer runner.pause()
  match (left, right) {
    (
      Int(location=a0, value=a1, int_value=a2),
      Int(location=b0, value=b1, int_value=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (
      Float(location=a0, value=a1, float_value=a2),
      Float(location=b0, value=b1, float_value=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (String(location=a0, value=a1), String(location=b0, value=b1)) =>
      a0 == b0 && a1 == b1
    (Tuple(location=a0, elements=a1), Tuple(location=b0, elements=b1)) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_constant(runner, left, right)
      })
    (
      List(location=a0, elements=a1, tail=a2),
      List(location=b0, elements=b1, tail=b2),
    ) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_constant(runner, left, right)
      }) &&
      equal_option(a2, b2, (left, right) => equal_constant(runner, left, right))
    (
      Record(
        location=a0,
        arguments_start_position=a1,
        module_=a2,
        name=a3,
        arguments=a4
      ),
      Record(
        location=b0,
        arguments_start_position=b1,
        module_=b2,
        name=b3,
        arguments=b4
      ),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      a2 == b2 &&
      a3 == b3 &&
      equal_option(a4, b4, (left, right) => {
        equal_array_view(left, right, (left, right) => {
          equal_call_arg(runner, left, right, (left, right) => {
            equal_constant(runner, left, right)
          })
        })
      })
    (
      RecordUpdate(
        location=a0,
        constructor_location=a1,
        module_=a2,
        name=a3,
        record=a4,
        arguments=a5
      ),
      RecordUpdate(
        location=b0,
        constructor_location=b1,
        module_=b2,
        name=b3,
        record=b4,
        arguments=b5
      ),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      a2 == b2 &&
      a3 == b3 &&
      equal_record_being_updated(runner, a4, b4, (left, right) => {
        equal_constant(runner, left, right)
      }) &&
      equal_array_view(a5, b5, (left, right) => {
        equal_record_update_arg(runner, left, right, (left, right) => {
          equal_constant(runner, left, right)
        })
      })
    (BitArray(location=a0, segments=a1), BitArray(location=b0, segments=b1)) =>
      a0 == b0 &&
      equal_array_view(a1, b1, (left, right) => {
        equal_bit_array_segment(runner, left, right, (left, right) => {
          equal_constant(runner, left, right)
        })
      })
    (
      Var(location=a0, module_=a1, name=a2),
      Var(location=b0, module_=b1, name=b2),
    ) => a0 == b0 && a1 == b1 && a2 == b2
    (
      BinaryOperator(
        location=a0,
        operator_start=a1,
        operator=a2,
        left=a3,
        right=a4
      ),
      BinaryOperator(
        location=b0,
        operator_start=b1,
        operator=b2,
        left=b3,
        right=b4
      ),
    ) =>
      a0 == b0 &&
      a1 == b1 &&
      a2 == b2 &&
      equal_constant(runner, a3, b3) &&
      equal_constant(runner, a4, b4)
    (Todo(location=a0, message=a1), Todo(location=b0, message=b1)) =>
      a0 == b0 &&
      equal_option(a1, b1, (left, right) => equal_constant(runner, left, right))
    _ => false
  }
}

///|
/// Compare every AST field without recursive machine-stack growth.
pub impl Eq for Constant with fn equal(left, right) {
  let runner = @work.Runner()
  runner.run_total(() => equal_constant(runner, left, right))
}
