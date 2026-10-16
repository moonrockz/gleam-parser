///|
fn parser_of(text : String, budget~ : Int32 = 100) -> Parser {
  Parser(@scanner.tokenize_text(text), {
    ..@config.Config::default(),
    fuel: @fuel.Budget::new(budget).unwrap(),
  })
}

///|
/// Run a parser step and keep its error as a value (`try?` is deprecated).
fn[A] attempt(f : () -> A raise ParseError) -> Result[A, ParseError] {
  try f() catch {
    e => Err(e)
  } noraise {
    v => Ok(v)
  }
}

///|
test "the cursor loads two tokens and an Error token is a hole" {
  // `;` is a lexical error: the compiler's parser sees None in that slot.
  let p = parser_of("a ; b")
  guard p.token0 is Some(a) && a.kind is Name("a") else { fail("token0") }
  @expect.expect(p.token1).to_equal(None)
  p.advance()
  @expect.expect(p.token0).to_equal(None)
  guard p.token1 is Some(b) && b.kind is Name("b") else { fail("token1") }
  p.advance()
  p.advance()
  @expect.expect_all(e => {
    e.expect(p.token0).to_equal(None)
    e.expect(p.token1).to_equal(None)
    e.expect(p.farthest).to_equal(@span.ByteOffset::new(5).unwrap())
    e.expect(p.here()).to_equal(@span.SrcSpan::new(5, 5).unwrap())
  })
}

///|
test "series_of records a trailing comma and rejects an extra one" {
  let p = parser_of("a, b, )")
  let names = p.series_of(q => q.maybe_name().map(n => n.1), Some(Comma))
  @expect.expect_all(e => {
    e.expect(names).to_equal(["a", "b"])
    e.expect(p.trailing_commas).to_equal([@span.ByteOffset::new(5).unwrap()])
    e
    .expect(p.maybe_one(RightParen))
    .to_equal(
      Some(
        (@span.ByteOffset::new(6).unwrap(), @span.ByteOffset::new(7).unwrap()),
      ),
    )
  })
  let extra = parser_of("a,, b")
  let r = attempt(() => {
    extra.series_of(q => q.maybe_name().map(n => n.1), Some(Comma))
  })
  guard r is Err(ParseError(error=ExtraSeparator, location~)) else {
    fail("expected ExtraSeparator, got \{@debug.to_string(r)}")
  }
  @expect.expect(location).to_equal(@span.SrcSpan::new(2, 3).unwrap())
}

///|
test "expect helpers give the compiler's errors" {
  let p = parser_of("= Foo _x")
  let eq = attempt(() => p.expect_name(Function))
  guard eq is Err(ParseError(error=ExpectedName, location=l1)) else {
    fail("expected ExpectedName")
  }
  let up = attempt(() => p.expect_name(Function))
  guard up is Err(ParseError(error=IncorrectName(Variable), location=l2)) else {
    fail("expected IncorrectName")
  }
  let discard = attempt(() => p.expect_name(Function))
  guard discard is Err(ParseError(error=IncorrectName(Function), location=l3)) else {
    fail("expected IncorrectName(Function)")
  }
  let eof = attempt(() => p.expect_name(Function))
  guard eof is Err(ParseError(error=UnexpectedEof, location=l4)) else {
    fail("expected UnexpectedEof")
  }
  @expect.expect_all(e => {
    e.expect(l1).to_equal(@span.SrcSpan::new(0, 1).unwrap())
    e.expect(l2).to_equal(@span.SrcSpan::new(2, 5).unwrap())
    e.expect(l3).to_equal(@span.SrcSpan::new(6, 8).unwrap())
    e.expect(l4).to_equal(@span.SrcSpan::new(0, 0).unwrap())
  })
  let reserved = parser_of("fn")
  let r = attempt(() => reserved.expect_assign_name())
  guard r is Err(ParseError(error=UnexpectedReservedWord, ..)) else {
    fail("expected UnexpectedReservedWord")
  }
  let q = parser_of("x")
  let unexpected = attempt(() => q.expect_one(Equal))
  guard unexpected
    is Err(
      ParseError(
        error=UnexpectedToken(token=Name("x"), expected~, hint=None),
        ..
      )
    ) else {
    fail("expected UnexpectedToken")
  }
  @expect.expect(expected).to_equal(["`=`"][:])
}

///|
test "nesting past the budget is TooMuchNesting at the current token, naming the operations" {
  let p = parser_of("x", budget=2)
  let r : Result[Unit, ParseError] = attempt(() => {
    p.nested(op_expression, () => {
      p.nested(op_expression, () => {
        p.nested(op_pattern, () => {
          raise ParseError(
            error=ExpectedExpr,
            location=@span.SrcSpan::new(9, 9).unwrap(),
          )
        })
      })
    })
  })
  // budget 2: the third nested entry fails
  guard r is Err(ParseError(error=TooMuchNesting(budget~, spent~), location~)) else {
    fail("expected TooMuchNesting")
  }
  @expect.expect_all(e => {
    e.expect(budget.units()).to_equal(2)
    e
    .expect(spent)
    .to_equal([{ operation: @fuel.Operation("expression"), levels: 2, }])
    e.expect(location).to_equal(@span.SrcSpan::new(0, 1).unwrap())
    // the fuel is back at the full budget after the error
    e.expect(p.fuel.val.left()).to_equal(2)
  })
}

///|
test "definition starts are column-1 keywords or attributes" {
  let p = parser_of("import a\n  fn b() {}\n@target(erlang)\npub fn c() {}\n}")
  let starts = []
  for i in 0..<p.tokens.length() {
    if p.at_definition_start(i) {
      starts.push(p.tokens[i].lexeme)
    }
  }
  @expect.expect(starts).to_equal(["import", "@", "pub"])
}

///|
test "seek reloads the lookahead" {
  let p = parser_of("a b c d")
  p.seek(2)
  guard p.token0 is Some(c) && c.kind is Name("c") else { fail("token0") }
  guard p.token1 is Some(d) && d.kind is Name("d") else { fail("token1") }
  @expect.expect(p.index0).to_equal(2)
}
