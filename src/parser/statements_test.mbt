///|
fn stmt_err(text : String) -> (String, @span.SrcSpan) {
  try @parser.parse_statements_text(text) catch {
    ParseError(error~, location~) => (error.kind(), location)
  } noraise {
    _ => ("ok", sp(0, 0))
  }
}

///|
test "let, let assert with message, use, assert" {
  let s = @parser.parse_statements_text(
    "let x: Int = 1\nlet assert Ok(y) = f() as \"m\"\nuse a, b <- g(1)\nuse <- h\nassert x == 1 as \"n\"\ny",
  )
  guard s
    is [
      Assignment(a0),
      Assignment(a1),
      Use(u0),
      Use(u1),
      Assert(as0),
      Expression(Var(..)),
    ] else {
    fail("got \{@debug.to_string(s)}")
  }
  guard a1.kind
    is Assert(location=kl, assert_keyword_start=scalar_26_61, message=Some(_)) else {
    fail("kind \{@debug.to_string(a1.kind)}")
  }
  @expect.expect(scalar_26_61.to_int()).to_equal(19)
  @expect.expect_all(e => {
    e.expect(a0.location).to_equal(sp(0, 14))
    e.expect(a0.kind).to_equal(@ast.AssignmentKind::Let)
    e.expect(a0.annotation is Some(_)).to_be_true()
    e.expect(a1.location).to_equal(sp(15, 44))
    e.expect(kl).to_equal(sp(15, 25))
    e.expect(u0.location).to_equal(sp(45, 61))
    e.expect(u0.assignments_location).to_equal(sp(49, 53))
    e.expect(u0.right_hand_side_location).to_equal(sp(57, 61))
    e.expect(u0.assignments.length()).to_equal(2)
    e.expect(u1.assignments.length()).to_equal(0)
    e.expect(u1.assignments_location).to_equal(sp(62, 65))
    e.expect(u1.location).to_equal(sp(62, 70))
    e.expect(as0.location).to_equal(sp(71, 91))
    e.expect(as0.message is Some(_)).to_be_true()
  })
}

///|
test "statement errors" {
  @expect.expect_all(e => {
    e.expect(stmt_err("x = 1")).to_equal(("NoLetBinding", sp(2, 3)))
    e.expect(stmt_err("x: Int = 1")).to_equal(("NoLetBinding", sp(1, 2)))
    e.expect(stmt_err("[x] = [1]")).to_equal(("NoLetBinding", sp(4, 5)))
    e.expect(stmt_err("let x =")).to_equal(("ExpectedValue", sp(6, 7)))
    e.expect(stmt_err("let x = _y")).to_equal(("IncorrectName", sp(8, 10)))
    e.expect(stmt_err("let x")).to_equal(("ExpectedEqual", sp(4, 5)))
    e.expect(stmt_err("let = 1")).to_equal(("UnexpectedToken", sp(4, 5)))
    e
    .expect(stmt_err("const x = 1"))
    .to_equal(("ConstantInsideFunction", sp(0, 5)))
    e.expect(stmt_err("use a <-")).to_equal(("UnexpectedEof", sp(0, 0)))
    e.expect(stmt_err("use , <- f")).to_equal(("ExpectedPattern", sp(4, 4)))
    e.expect(stmt_err("")).to_equal(("ExpectedExpr", sp(0, 0)))
  })
}

///|
test "a snippet parser reports a lexical error before the parse error that follows it" {
  // Compiler snapshot `semicolons`: "Remove this semicolon" at 1:8 (the
  // scanner gives the compiler's zero-width span for `;`).
  @expect.expect(stmt_err("{ 2 + 3; - -5; }")).to_equal(("LexError", sp(7, 7)))
}
