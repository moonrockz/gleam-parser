///|
fn op(text : String, prec : Int32) -> OpEntry {
  let t = @scanner.tokenize_text(text).tokens[0]
  { token: t, precedence: prec, }
}

///|
/// A reduction over strings, to see the shape handle_operator builds.
fn reduce_text(operator : @scanner.Token, estack : Array[String]) -> Unit {
  guard estack.pop() is Some(right) && estack.pop() is Some(left) else {
    return
  }
  estack.push("(\{left} \{operator.lexeme} \{right})")
}

///|
test "handle_operator reduces left-associatively by precedence" {
  let opstack : Array[OpEntry] = []
  let estack = ["1"]
  ignore(handle_operator(Some(op("+", 7)), opstack, estack, reduce_text))
  estack.push("2")
  ignore(handle_operator(Some(op("*", 8)), opstack, estack, reduce_text))
  estack.push("3")
  ignore(handle_operator(Some(op("-", 7)), opstack, estack, reduce_text))
  estack.push("4")
  let result = handle_operator(None, opstack, estack, reduce_text)
  @expect.expect(result).to_equal(Some("((1 + (2 * 3)) - 4)"))
}

///|
test "precedence tables follow the compiler" {
  @expect.expect_all(e => {
    e.expect(precedence(Pipe)).to_equal(Some(6))
    e.expect(precedence(VbarVbar)).to_equal(Some(1))
    e.expect(precedence(AmperAmper)).to_equal(Some(2))
    e.expect(precedence(EqualEqual)).to_equal(Some(3))
    e.expect(precedence(LessEqualDot)).to_equal(Some(4))
    e.expect(precedence(Concatenate)).to_equal(Some(5))
    e.expect(precedence(MinusDot)).to_equal(Some(7))
    e.expect(precedence(Percent)).to_equal(Some(8))
    e.expect(precedence(Equal)).to_equal(None)
    e.expect(guard_precedence(Plus)).to_equal(Some(6))
    e.expect(guard_precedence(Star)).to_equal(Some(7))
    e.expect(guard_precedence(Pipe)).to_equal(None)
    e
    .expect(token_to_binop(GreaterEqualDot))
    .to_equal(Some(@ast.BinOp::GtEqFloat))
    e.expect(token_to_binop(Vbar)).to_equal(None)
    e
    .expect(token_to_int_operator(Percent))
    .to_equal(Some(@ast.IntOperator::Remainder))
    e.expect(int_operator_precedence(Add)).to_equal(7)
    e.expect(int_operator_precedence(Divide)).to_equal(8)
  })
}

///|
test "expression reduction flattens pipelines and builds bin ops" {
  let a : @ast.Expr = Var(
    location=sp(
      @span.ByteOffset::from_int(0).unwrap(),
      @span.ByteOffset::from_int(1).unwrap(),
    ),
    name="a",
  )
  let b : @ast.Expr = Var(
    location=sp(
      @span.ByteOffset::from_int(5).unwrap(),
      @span.ByteOffset::from_int(6).unwrap(),
    ),
    name="b",
  )
  let c : @ast.Expr = Var(
    location=sp(
      @span.ByteOffset::from_int(10).unwrap(),
      @span.ByteOffset::from_int(11).unwrap(),
    ),
    name="c",
  )
  let pipe = @scanner.tokenize_text("a |> b |> c").tokens
  let estack = [a, b]
  reduce_expression(pipe[1], estack)
  estack.push(c)
  reduce_expression(pipe[3], estack)
  guard estack is [Pipeline(expressions~)] else { fail("pipeline") }
  @expect.expect(expressions.length()).to_equal(3)
  let plus = @scanner.tokenize_text("a + b").tokens[1]
  let stack2 = [a, b]
  reduce_expression(plus, stack2)
  guard stack2
    is [BinOp(operator=AddInt, operator_start=scalar_72_58, location~, ..)] else {
    fail("bin op")
  }
  @expect.expect(scalar_72_58.to_int()).to_equal(2)
  @expect.expect(location).to_equal(
    sp(
      @span.ByteOffset::from_int(0).unwrap(),
      @span.ByteOffset::from_int(6).unwrap(),
    ),
  )
}
