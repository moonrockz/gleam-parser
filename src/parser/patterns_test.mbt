///|
fn pattern_err(text : String) -> (String, @span.SrcSpan) {
  try @parser.parse_pattern_text(text) catch {
    ParseError(error~, location~) => (error.kind(), location)
  } noraise {
    _ => ("ok", sp(0, 0))
  }
}

///|
test "list pattern with a tail" {
  let p = @parser.parse_pattern_text("[first, ..rest]")
  guard p
    is List(
      location~,
      elements~,
      tail=Some({ location: tl, pattern: Variable(location=vl, name="rest"), })
    ) else {
    fail("got \{@debug.to_string(p)}")
  }
  guard elements is [Variable(location=fl, name="first")] else {
    fail("elements \{@debug.to_string(elements)}")
  }
  @expect.expect_all(e => {
    e.expect(location).to_equal(sp(0, 15))
    e.expect(fl).to_equal(sp(1, 6))
    e.expect(tl).to_equal(sp(8, 14))
    e.expect(vl).to_equal(sp(10, 14))
  })
}

///|
test "a spread with no name is an implicit discard at the closing bracket" {
  let p = @parser.parse_pattern_text("[a, ..]")
  guard p
    is List(
      tail=Some({ location: tl, pattern: Discard(location=dl, name="_"), }),
      ..
    ) else {
    fail("got \{@debug.to_string(p)}")
  }
  @expect.expect_all(e => {
    e.expect(tl).to_equal(sp(4, 7))
    e.expect(dl).to_equal(sp(6, 7))
  })
}

///|
test "constructor patterns: qualified, labelled, shorthand, spread, as" {
  let p = @parser.parse_pattern_text("option.Some(x: 1, y:, ..) as whole")
  guard p
    is Assign(
      name="whole",
      location=al,
      pattern=Constructor(
        location~,
        name_location~,
        name="Some",
        arguments~,
        module_=Some(m),
        spread=Some(spread)
      )
    ) else {
    fail("got \{@debug.to_string(p)}")
  }
  guard arguments
    is [
      { label: Some("x"), location: l1, value: Int(value="1", ..), .. },
      {
        label: Some("y"),
        location: l2,
        value: Variable(name="y", location=vl),
        ..
      },
    ] else {
    fail("arguments \{@debug.to_string(arguments)}")
  }
  @expect.expect_all(e => {
    e.expect(al).to_equal(sp(29, 34))
    e.expect(location).to_equal(sp(0, 25))
    e.expect(name_location).to_equal(sp(7, 11))
    e.expect(m.name).to_equal("option")
    e.expect(m.location).to_equal(sp(0, 6))
    e.expect(spread).to_equal(sp(22, 24))
    e.expect(l1).to_equal(sp(12, 16))
    e.expect(l2).to_equal(sp(18, 20))
    e.expect(vl).to_equal(sp(18, 20))
  })
}

///|
test "string prefix patterns" {
  let p = @parser.parse_pattern_text("\"pre\" as p <> rest")
  guard p
    is StringPrefix(
      location~,
      left_location~,
      left_side_assignment=Some(a),
      right_location~,
      left_side_string="pre",
      right_side_assignment=Variable("rest")
    ) else {
    fail("got \{@debug.to_string(p)}")
  }
  @expect.expect_all(e => {
    e.expect(location).to_equal(sp(0, 18))
    e.expect(left_location).to_equal(sp(0, 10))
    e.expect(a.name).to_equal("p")
    e.expect(a.name_start_position).to_equal(@span.ByteOffset::new(9).unwrap())
    e.expect(a.location).to_equal(sp(5, 10))
    e.expect(right_location).to_equal(sp(14, 18))
  })
  let q = @parser.parse_pattern_text("\"whole\" as w")
  guard q
    is Assign(name="w", location=wl, pattern=String(location=sl, value="whole")) else {
    fail("got \{@debug.to_string(q)}")
  }
  @expect.expect_all(e => {
    e.expect(wl).to_equal(sp(11, 12))
    e.expect(sl).to_equal(sp(0, 7))
  })
}

///|
test "tuple, bit array and literal patterns" {
  let p = @parser.parse_pattern_text("#(1, 2.5, <<x:size(8)-unit(2), _:bits>>)")
  guard p is Tuple(location~, elements~) else {
    fail("got \{@debug.to_string(p)}")
  }
  guard elements
    is [Int(..), Float(value="2.5", ..), BitArray(location=bl, segments~)] else {
    fail("elements \{@debug.to_string(elements)}")
  }
  guard segments
    is [
      {
        value: Variable(name="x", ..),
        options: [
          Size(
            value=BitArraySize(Int(value="8", ..)),
            short_form=false,
            location=sl
          ),
          Unit(value=scalar_144_22, location=ul),
        ],
        location: segl,
      },
      { options: [Bits(..)], .. },
    ] else {
    fail("segments \{@debug.to_string(segments)}")
  }
  @expect.expect(scalar_144_22.to_int()).to_equal(2)
  @expect.expect_all(e => {
    e.expect(location).to_equal(sp(0, 40))
    e.expect(bl).to_equal(sp(10, 39))
    e.expect(segl).to_equal(sp(12, 29))
    e.expect(sl).to_equal(sp(14, 21))
    e.expect(ul).to_equal(sp(22, 29))
  })
}

///|
test "pattern errors have the compiler's kinds and spans" {
  @expect.expect_all(e => {
    e
    .expect(pattern_err("a <> b"))
    .to_equal(("ConcatPatternVariableLeftHandSide", sp(0, 1)))
    e
    .expect(pattern_err("\"a\" <> b <> \"c\""))
    .to_equal(("ConcatPatternVariableWithSuffix", sp(9, 15)))
    e
    .expect(pattern_err("[..rest, x]"))
    .to_equal(("ListPatternSpreadFollowedByElements", sp(1, 7)))
    e
    .expect(pattern_err("[a, ..[b]]"))
    .to_equal(("InvalidTailPattern", sp(6, 9)))
    e
    .expect(pattern_err("<<<<1>>>>"))
    .to_equal(("NestedBitArrayPattern", sp(2, 7)))
    e
    .expect(pattern_err("mod.thing"))
    .to_equal(("InvalidModuleTypePattern", sp(0, 9)))
    e.expect(pattern_err("Some(")).to_equal(("UnexpectedEof", sp(0, 0)))
    e.expect(pattern_err("#(a,, b)")).to_equal(("ExtraSeparator", sp(4, 5)))
  })
}

///|
test "deprecated pattern syntax parses and warns" {
  // Checked through parse_text in Task 5; here the pattern itself parses.
  let p = @parser.parse_pattern_text("[first..rest]")
  guard p is List(tail=Some(_), ..) else { fail("got \{@debug.to_string(p)}") }
}
