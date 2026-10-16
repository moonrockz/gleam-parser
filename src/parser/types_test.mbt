///|
test "type forms: constructor with arguments, variable, tuple, hole, fn, qualified" {
  let t = @parser.parse_type_text("Result(a, #(Int, _))")
  guard t
    is Constructor(
      {
        location,
        name: Unqualified(name="Result", location=nl),
        arguments,
        start_parentheses: Some(scalar_10_33),
      }
    ) else {
    fail("expected a constructor, got \{@debug.to_string(t)}")
  }
  @expect.expect(scalar_10_33.to_int()).to_equal(6)
  guard arguments
    is [Var({ location: al, name: "a", }), Tuple({ location: tl, elements, })] else {
    fail("arguments \{@debug.to_string(arguments)}")
  }
  guard elements
    is [
      Constructor({ start_parentheses: None, location: il, .. }),
      Hole({ location: hl, name: "_", }),
    ] else {
    fail("elements \{@debug.to_string(elements)}")
  }
  @expect.expect_all(e => {
    e.expect(location).to_equal(sp(0, 20))
    e.expect(nl).to_equal(sp(0, 6))
    e.expect(al).to_equal(sp(7, 8))
    e.expect(tl).to_equal(sp(10, 19))
    e.expect(il).to_equal(sp(12, 15))
    e.expect(hl).to_equal(sp(17, 18))
  })
  let f = @parser.parse_type_text("fn(a, b) -> option.Option(a)")
  guard f
    is Fn(
      {
        location: fl,
        arguments: fargs,
        return_: Constructor(
          {
            name: Qualified(
              module_="option",
              module_location~,
              dot_location=scalar_45_28,
              name=Some(n)
            ),
            location: rl,
            ..
          }
        ),
      }
    ) else {
    fail("expected fn type, got \{@debug.to_string(f)}")
  }
  @expect.expect(scalar_45_28.to_int()).to_equal(19)
  @expect.expect_all(e => {
    e.expect(fl).to_equal(sp(0, 28))
    e.expect(fargs.length()).to_equal(2)
    e.expect(module_location).to_equal(sp(12, 18))
    e.expect(n.name).to_equal("Option")
    e.expect(n.location).to_equal(sp(19, 25))
    e.expect(rl).to_equal(sp(12, 28))
  })
}

///|
test "a qualified type without a name keeps the dot position" {
  let t = @parser.parse_type_text("mod.")
  guard t
    is Constructor(
      {
        name: Qualified(name=None, dot_location=scalar_71_49, ..),
        location,
        ..
      }
    ) else {
    fail("got \{@debug.to_string(t)}")
  }
  @expect.expect(scalar_71_49.to_int()).to_equal(4)
  @expect.expect(location).to_equal(sp(0, 4))
}

///|
test "type errors" {
  fn type_err(text : String) -> (String, @span.SrcSpan) {
    try @parser.parse_type_text(text) catch {
      ParseError(error~, location~) => (error.kind(), location)
    } noraise {
      _ => ("ok", sp(0, 0))
    }
  }

  @expect.expect_all(e => {
    e.expect(type_err("fn(a) ->")).to_equal(("ExpectedType", sp(6, 8)))
    e
    .expect(type_err("List<Int>"))
    .to_equal(("TypeUsageAngleGenerics", sp(4, 5)))
    e.expect(type_err("mod.(a)")).to_equal(("ExpectedUpName", sp(4, 5)))
    e.expect(type_err("#(Int")).to_equal(("UnexpectedEof", sp(0, 0)))
    e.expect(type_err("Int Int")).to_equal(("UnexpectedToken", sp(4, 7)))
    e.expect(type_err("")).to_equal(("ExpectedType", sp(0, 0)))
  })
}
