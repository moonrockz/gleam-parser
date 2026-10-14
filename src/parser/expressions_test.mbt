///|
fn expr_err(text : String) -> (String, @span.SrcSpan) {
  try @parser.parse_expression_text(text) catch {
    ParseError(error~, location~) => (error.kind(), location)
  } noraise {
    _ => ("ok", sp(0, 0))
  }
}

///|
test "operators reduce by precedence with the compiler's spans" {
  let e = @parser.parse_expression_text("1 + 2 * 3")
  guard e
    is BinOp(
      location~,
      operator=AddInt,
      operator_start=2,
      left=Int(..),
      right=BinOp(location=rl, operator=MultInt, operator_start=6, ..)
    ) else {
    fail("got \{@debug.to_string(e)}")
  }
  @expect.expect_all(x => {
    x.expect(location).to_equal(sp(0, 9))
    x.expect(rl).to_equal(sp(4, 9))
  })
}

///|
test "pipelines are flat and calls keep the open parenthesis" {
  let e = @parser.parse_expression_text("a |> b(1) |> c")
  guard e is Pipeline(expressions~) else { fail("got \{@debug.to_string(e)}") }
  guard expressions
    is [
      Var(name="a", ..),
      Call(
        location~,
        fun=Var(name="b", location=bl),
        arguments~,
        open_parenthesis=6
      ),
      Var(name="c", location=cl),
    ] else {
    fail("expressions \{@debug.to_string(expressions)}")
  }
  @expect.expect_all(x => {
    x.expect(e.location()).to_equal(sp(0, 14))
    x.expect(location).to_equal(sp(5, 9))
    x.expect(bl).to_equal(sp(5, 6))
    x.expect(arguments.length()).to_equal(1)
    x.expect(arguments[0].location).to_equal(sp(7, 8))
    x.expect(cl).to_equal(sp(13, 14))
  })
}

///|
test "a capture builds the compiler's anonymous function" {
  let e = @parser.parse_expression_text("f(_, 1)")
  guard e
    is Fn(
      location~,
      kind=Capture(hole~),
      end_of_head_byte_index=7,
      arguments~,
      body~,
      return_annotation=None
    ) else {
    fail("got \{@debug.to_string(e)}")
  }
  guard arguments
    is [
      {
        location: al,
        names: Named(name="_capture", location=nl),
        annotation: None,
      },
    ] else {
    fail("arguments \{@debug.to_string(arguments)}")
  }
  guard body
    is [
      Expression(Call(location=cl, arguments=call_args, open_parenthesis=1, ..)),
    ] else {
    fail("body \{@debug.to_string(body)}")
  }
  guard call_args
    is [
      {
        value: Var(name="_capture", location=vl),
        location: l0,
        label: None,
        implicit: None,
      },
      { location: l1, .. },
    ] else {
    fail("call args \{@debug.to_string(call_args)}")
  }
  @expect.expect_all(x => {
    x.expect(location).to_equal(sp(0, 7))
    x.expect(hole).to_equal(sp(2, 3))
    x.expect(al).to_equal(sp(2, 3))
    x.expect(nl).to_equal(sp(2, 3))
    x.expect(cl).to_equal(sp(0, 7))
    x.expect(vl).to_equal(sp(2, 3))
    x.expect(l0).to_equal(sp(2, 3))
    x.expect(l1).to_equal(sp(5, 6))
  })
}

///|
test "an anonymous function has the compiler's head and body spans" {
  let e = @parser.parse_expression_text("fn(a: Int, b) -> Int { a + b }")
  guard e
    is Fn(
      location~,
      kind=Anonymous(head~),
      end_of_head_byte_index=20,
      arguments~,
      body~,
      return_annotation=Some(_)
    ) else {
    fail("got \{@debug.to_string(e)}")
  }
  @expect.expect_all(x => {
    x.expect(location).to_equal(sp(0, 30))
    x.expect(head).to_equal(sp(0, 20))
    x.expect(arguments.length()).to_equal(2)
    x.expect(arguments[0].location).to_equal(sp(3, 9))
    x.expect(arguments[1].location).to_equal(sp(11, 12))
    x.expect(body.length()).to_equal(1)
  })
}

///|
test "blocks, case, record update, field access, tuple index, echo, todo, negation" {
  let block = @parser.parse_expression_text("{ 1\n 2 }")
  guard block is Block(location=bl, statements~) else {
    fail("got \{@debug.to_string(block)}")
  }
  let empty_block = @parser.parse_expression_text("{}")
  guard empty_block
    is Block(
      statements=[Expression(Todo(kind=EmptyBlock, location=tl, ..))],
      ..
    ) else {
    fail("got \{@debug.to_string(empty_block)}")
  }
  let case_ = @parser.parse_expression_text(
    "case x, y {\n  1, 2 -> \"a\"\n  _, _ | 3, 4 if x > y -> \"b\"\n}",
  )
  guard case_ is Case(location=cl, subjects~, clauses=Some(clauses)) else {
    fail("got \{@debug.to_string(case_)}")
  }
  guard clauses[1]
    is {
      alternative_patterns,
      guard_: Some(BinaryOperator(operator=GtInt, ..)),
      location: c1,
      ..
    } else {
    fail("clause \{@debug.to_string(clauses[1])}")
  }
  let update = @parser.parse_expression_text("Point(..p, x: 1)")
  guard update
    is RecordUpdate(
      location=ul,
      spread_start=6,
      constructor_=Var(name="Point", ..),
      record={ base: Var(name="p", ..), location: rl, },
      arguments=upd
    ) else {
    fail("got \{@debug.to_string(update)}")
  }
  let access = @parser.parse_expression_text("a.b.0")
  guard access
    is TupleIndex(
      location=il,
      index=0,
      tuple=FieldAccess(location=fl, label_location=ll, label="b", ..)
    ) else {
    fail("got \{@debug.to_string(access)}")
  }
  let echo_ = @parser.parse_expression_text("echo x as \"m\"")
  guard echo_
    is Echo(
      location=el,
      keyword_end=4,
      expression=Some(Var(..)),
      message=Some(_)
    ) else {
    fail("got \{@debug.to_string(echo_)}")
  }
  let todo_ = @parser.parse_expression_text("todo as \"x\"")
  guard todo_ is Todo(kind=Keyword, location=tdl, message=Some(_)) else {
    fail("got \{@debug.to_string(todo_)}")
  }
  let neg = @parser.parse_expression_text("!-x")
  guard neg is NegateBool(location=nl, value=NegateInt(location=ml, ..)) else {
    fail("got \{@debug.to_string(neg)}")
  }
  let bits = @parser.parse_expression_text("<<1, x:size(n)-big, \"a\":utf8>>")
  guard bits is BitArray(location=bitl, segments~) else {
    fail("got \{@debug.to_string(bits)}")
  }
  guard segments[1]
    is {
      options: [Size(value=Var(name="n", ..), short_form=false, ..), Big(..)],
      ..
    } else {
    fail("segments \{@debug.to_string(segments)}")
  }
  let list = @parser.parse_expression_text("[1, 2, ..rest]")
  guard list is List(location=ltl, elements~, tail=Some(Var(name="rest", ..))) else {
    fail("got \{@debug.to_string(list)}")
  }
  let shorthand = @parser.parse_expression_text("f(x:, y: 2)")
  guard shorthand
    is Call(
      arguments=[
        {
          label: Some("x"),
          value: Var(name="x", location=sl),
          location: sl2,
          ..
        },
        _,
      ],
      ..
    ) else {
    fail("got \{@debug.to_string(shorthand)}")
  }
  @expect.expect_all(x => {
    x.expect(bl).to_equal(sp(0, 8))
    x.expect(statements.length()).to_equal(2)
    x.expect(tl).to_equal(sp(0, 2))
    x.expect(cl).to_equal(sp(0, 57))
    x.expect(subjects.length()).to_equal(2)
    x.expect(clauses.length()).to_equal(2)
    x.expect(alternative_patterns.length()).to_equal(1)
    x.expect(c1).to_equal(sp(28, 55))
    x.expect(ul).to_equal(sp(0, 16))
    x.expect(rl).to_equal(sp(6, 9))
    x.expect(upd.length()).to_equal(1)
    x.expect(upd[0].location).to_equal(sp(11, 15))
    x.expect(il).to_equal(sp(0, 5))
    x.expect(fl).to_equal(sp(0, 3))
    x.expect(ll).to_equal(sp(2, 3))
    x.expect(el).to_equal(sp(0, 13))
    x.expect(tdl).to_equal(sp(0, 11))
    x.expect(nl).to_equal(sp(0, 3))
    x.expect(ml).to_equal(sp(1, 3))
    x.expect(bitl).to_equal(sp(0, 30))
    x.expect(ltl).to_equal(sp(0, 14))
    x.expect(elements.length()).to_equal(2)
    x.expect(sl).to_equal(sp(2, 4))
    x.expect(sl2).to_equal(sp(2, 4))
  })
}

///|
test "a case with no clauses and an empty case" {
  let e = @parser.parse_expression_text("case x")
  guard e is Case(location~, clauses=None, ..) else {
    fail("got \{@debug.to_string(e)}")
  }
  @expect.expect(location).to_equal(sp(0, 6))
}

///|
test "expression errors have the compiler's kinds and spans" {
  @expect.expect_all(x => {
    x.expect(expr_err("if x {}")).to_equal(("IfExpression", sp(0, 2)))
    x.expect(expr_err("(1)")).to_equal(("ExprLparStart", sp(0, 0)))
    x.expect(expr_err("1 +")).to_equal(("OpNakedRight", sp(2, 3)))
    x.expect(expr_err("f(_, _)")).to_equal(("TooManyArgHoles", sp(0, 7)))
    x.expect(expr_err("f(_x)")).to_equal(("UnexpectedToken", sp(2, 4)))
    x.expect(expr_err("fn()")).to_equal(("ExpectedFunctionBody", sp(0, 4)))
    x
    .expect(expr_err("fn name() { 1 }"))
    .to_equal(("UnexpectedToken", sp(3, 7)))
    // `{}` is a block, so this is a case with one subject and no clauses.
    x.expect(expr_err("case {}")).to_equal(("ok", sp(0, 0)))
    x.expect(expr_err("case x { 1 -> }")).to_equal(("ExpectedExpr", sp(11, 13)))
    x
    .expect(expr_err("case x { | 1 -> 2 }"))
    .to_equal(("UnexpectedToken", sp(9, 10)))
    x
    .expect(expr_err("[1, ..x, 2]"))
    .to_equal(("ListSpreadFollowedByElements", sp(4, 7)))
    x
    .expect(expr_err("[..x]"))
    .to_equal(("ListSpreadWithoutElements", sp(0, 5)))
    x.expect(expr_err("[1, ..]")).to_equal(("ListSpreadWithoutTail", sp(4, 6)))
    x
    .expect(expr_err("[1, ..a, ..b]"))
    .to_equal(("ListSpreadWithAnotherSpread", sp(9, 11)))
    x
    .expect(expr_err("Point(x: 1, ..r)"))
    .to_equal(("RecordUpdateAfterFields", sp(12, 15)))
    x.expect(expr_err("#(1,,2)")).to_equal(("ExtraSeparator", sp(4, 5)))
    x.expect(expr_err("#1")).to_equal(("UnexpectedToken", sp(1, 2)))
    x.expect(expr_err("a.")).to_equal(("ok", sp(0, 0)))
    x.expect(expr_err("a.1_0")).to_equal(("ok", sp(0, 0)))
    // The lexer reads `-1` as one Int token; its digits are not a u64.
    x.expect(expr_err("a.-1")).to_equal(("InvalidTupleAccess", sp(0, 4)))
    x.expect(expr_err("!")).to_equal(("ExpectedExpr", sp(0, 0)))
    x.expect(expr_err("fn(a a) { a }")).to_equal(("UnexpectedLabel", sp(3, 4)))
    x
    .expect(expr_err("fn(a): Int { a }"))
    .to_equal(("UnexpectedToken", sp(5, 6)))
    x
    .expect(expr_err("fn<a>(x) { x }"))
    .to_equal(("FunctionDefinitionAngleGenerics", sp(2, 3)))
  })
  // `#1`: the compiler adds the comment hint.
  try @parser.parse_expression_text("#1") catch {
    ParseError(error=UnexpectedToken(hint~, ..), ..) =>
      @expect.expect(hint).to_equal(
        Some(
          "Maybe you meant to create a comment?\nComments in Gleam start with `//`, not `#`",
        ),
      )
    other => fail("expected UnexpectedToken, got \{@debug.to_string(other)}")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "a field access with no label" {
  let dot = @parser.parse_expression_text("a.")
  guard dot is FieldAccess(location~, label_location~, label="", ..) else {
    fail("got \{@debug.to_string(dot)}")
  }
  @expect.expect_all(x => {
    x.expect(location).to_equal(sp(0, 2))
    x.expect(label_location).to_equal(sp(1, 2))
  })
}
