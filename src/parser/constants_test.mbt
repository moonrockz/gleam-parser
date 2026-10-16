///|
fn constant_err(text : String) -> (String, @span.SrcSpan) {
  try @parser.parse_constant_text(text) catch {
    ParseError(error~, location~) => (error.kind(), location)
  } noraise {
    _ => ("ok", sp(0, 0))
  }
}

///|
test "constant records, lists with tails, tuples, operators" {
  let c = @parser.parse_constant_text("option.Some(x: 1, 2)")
  guard c
    is Record(
      location~,
      arguments_start_position=scalar_16_32,
      module_=Some(m),
      name="Some",
      arguments=Some(arguments)
    ) else {
    fail("got \{@debug.to_string(c)}")
  }
  @expect.expect(scalar_16_32.to_int()).to_equal(11)
  @expect.expect_all(e => {
    e.expect(location).to_equal(sp(0, 20))
    e.expect(m.name).to_equal("option")
    e.expect(m.location).to_equal(sp(0, 6))
    e.expect(arguments.length()).to_equal(2)
    e.expect(arguments[0].label).to_equal(Some("x"))
    e.expect(arguments[0].location).to_equal(sp(12, 16))
    e.expect(arguments[1].location).to_equal(sp(18, 19))
  })
  let bare = @parser.parse_constant_text("Nil")
  guard bare
    is Record(
      arguments=None,
      arguments_start_position=scalar_34_56,
      location=bl,
      ..
    ) else {
    fail("got \{@debug.to_string(bare)}")
  }
  @expect.expect(scalar_34_56.to_int()).to_equal(3)
  @expect.expect(bl).to_equal(sp(0, 3))
  let list = @parser.parse_constant_text("[1, 2, ..rest]")
  guard list is List(location=ll, elements~, tail=Some(Var(name="rest", ..))) else {
    fail("got \{@debug.to_string(list)}")
  }
  @expect.expect_all(e => {
    e.expect(ll).to_equal(sp(0, 14))
    e.expect(elements.length()).to_equal(2)
  })
  let ops = @parser.parse_constant_text("1 + 2 * 3 <> \"s\"")
  guard ops
    is BinaryOperator(
      operator=Concatenate,
      operator_start=scalar_50_22,
      location=ol,
      left=BinaryOperator(
        operator=AddInt,
        right=BinaryOperator(operator=MultInt, ..),
        ..
      ),
      ..
    ) else {
    fail("got \{@debug.to_string(ops)}")
  }
  @expect.expect(scalar_50_22.to_int()).to_equal(10)
  @expect.expect(ol).to_equal(sp(0, 16))
  let update = @parser.parse_constant_text("Point(..base, x: 1, y:)")
  guard update
    is RecordUpdate(
      location=ul,
      constructor_location~,
      record={ base: Var(name="base", ..), location: rl, },
      arguments=upd,
      ..
    ) else {
    fail("got \{@debug.to_string(update)}")
  }
  @expect.expect_all(e => {
    e.expect(ul).to_equal(sp(0, 23))
    e.expect(constructor_location).to_equal(sp(0, 5))
    e.expect(rl).to_equal(sp(6, 12))
    e.expect(upd.length()).to_equal(2)
    e.expect(upd[1].label).to_equal("y")
    e.expect(upd[1].location).to_equal(sp(20, 22))
  })
  let todo_ = @parser.parse_constant_text("todo as \"later\"")
  guard todo_ is Todo(location=tl, message=Some(String(value="later", ..))) else {
    fail("got \{@debug.to_string(todo_)}")
  }
  @expect.expect(tl).to_equal(sp(0, 15))
}

///|
test "constant bit arrays and qualified variables" {
  let c = @parser.parse_constant_text("<<1, x:16-little, \"a\":utf8>>")
  guard c is BitArray(location~, segments~) else {
    fail("got \{@debug.to_string(c)}")
  }
  guard segments
    is [
      _,
      {
        value: Var(name="x", module_=None, ..),
        options: [
          Size(value=Int(value="16", ..), short_form=true, ..),
          Little(..),
        ],
        ..
      },
      _,
    ] else {
    fail("segments \{@debug.to_string(segments)}")
  }
  @expect.expect(location).to_equal(sp(0, 28))
  let v = @parser.parse_constant_text("mod.value")
  guard v is Var(location=vl, module_=Some(m), name="value") else {
    fail("got \{@debug.to_string(v)}")
  }
  @expect.expect_all(e => {
    e.expect(vl).to_equal(sp(0, 9))
    e.expect(m.location).to_equal(sp(0, 3))
  })
}

///|
test "constant errors" {
  @expect.expect_all(e => {
    e.expect(constant_err("1 |> f")).to_equal(("UnexpectedToken", sp(2, 4)))
    e.expect(constant_err("\"a\" <>")).to_equal(("OpNakedRight", sp(4, 6)))
    e.expect(constant_err("fn() { 1 }")).to_equal(("NotConstType", sp(0, 2)))
    e.expect(constant_err("f(1)")).to_equal(("UnexpectedFunction", sp(0, 4)))
    e
    .expect(constant_err("mod.f(1)"))
    .to_equal(("UnexpectedFunction", sp(0, 8)))
    e
    .expect(constant_err("[..a]"))
    .to_equal(("ListSpreadWithoutElements", sp(0, 5)))
    e
    .expect(constant_err("[1, ..a, 2]"))
    .to_equal(("ListSpreadFollowedByElements", sp(4, 7)))
    e
    .expect(constant_err("[1, ..a, ..b]"))
    .to_equal(("ListSpreadWithAnotherSpread", sp(9, 11)))
    e
    .expect(constant_err("[1, ..]"))
    .to_equal(("ListSpreadWithoutTail", sp(4, 6)))
    e
    .expect(constant_err("Point(x: 1, ..base)"))
    .to_equal(("RecordUpdateAfterFields", sp(12, 18)))
    e
    .expect(constant_err("todo as"))
    .to_equal(("MissingConstantAsMessage", sp(5, 7)))
    e.expect(constant_err("")).to_equal(("ExpectedExpr", sp(0, 0)))
  })
}
