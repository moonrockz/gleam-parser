///|
fn clause_error(text : String) -> (String, @span.SrcSpan) {
  try @parser.parse_expression_text(text) catch {
    ParseError(error~, location~) => (error.kind(), location)
  } noraise {
    _ => ("ok", sp(0, 0))
  }
}

///|
test "guards: operators, not, field access, tuple index, module constant, block" {
  let e = @parser.parse_expression_text(
    "case x {\n  a if a.0 == 1 && !b.c || mod.Const(1) == { 2 } -> 1\n}",
  )
  guard e is Case(clauses=Some([{ guard_: Some(g), .. }]), ..) else {
    fail("got \{@debug.to_string(e)}")
  }
  guard g
    is BinaryOperator(
      operator=Or,
      location=gl,
      left=BinaryOperator(
        operator=And,
        left=BinaryOperator(
          operator=Eq,
          left=TupleIndex(
            location=tl,
            index=scalar_26_46,
            tuple=Var(name="a", ..)
          ),
          ..
        ),
        right=Not(
          expression=FieldAccess(
            label="c",
            label_location=fl,
            container=Var(name="b", ..),
            ..
          ),
          ..
        ),
        ..
      ),
      right=BinaryOperator(
        operator=Eq,
        left=Constant(Record(name="Const", module_=Some(_), ..)),
        right=Block(location=bl, value=Constant(Int(..))),
        ..
      ),
      ..
    ) else {
    fail("guard \{@debug.to_string(g)}")
  }
  @expect.expect(scalar_26_46.to_uint64()).to_equal(0UL)
  @expect.expect_all(x => {
    x.expect(gl).to_equal(sp(17, 57))
    x.expect(tl).to_equal(sp(17, 19))
    x.expect(fl).to_equal(sp(31, 32))
    x.expect(bl).to_equal(sp(52, 57))
  })
}

///|
test "guard errors" {
  @expect.expect_all(x => {
    x
    .expect(clause_error("case x { _ if {} -> 1 }"))
    .to_equal(("EmptyGuardBlock", sp(14, 16)))
    x
    .expect(clause_error("case x { _ if f() -> 1 }"))
    .to_equal(("CallInClauseGuard", sp(14, 17)))
    x
    .expect(clause_error("case x { _ if a.b(1) -> 1 }"))
    .to_equal(("CallInClauseGuard", sp(14, 20)))
    x
    .expect(clause_error("case x { _ if a |> b -> 1 }"))
    .to_equal(("UnexpectedToken", sp(16, 18)))
    x
    .expect(clause_error("case x { _ if a.1_0 -> 1 }"))
    .to_equal(("ok", sp(0, 0)))
    // `a.B` is a module constant; a name after a tuple index is not.
    x
    .expect(clause_error("case x { _ if a.B -> 1 }"))
    .to_equal(("ok", sp(0, 0)))
    x
    .expect(clause_error("case x { _ if a.1.B -> 1 }"))
    .to_equal(("IncorrectName", sp(18, 19)))
    x
    .expect(clause_error("case x { _ if ! -> 1 }"))
    .to_equal(("ExpectedValue", sp(14, 14)))
    x
    .expect(clause_error("case x { _ if a <> -> 1 }"))
    .to_equal(("OpNakedRight", sp(16, 18)))
    x.expect(clause_error("case x { _ if -> 1 }")).to_equal(("ok", sp(0, 0)))
  })
}
