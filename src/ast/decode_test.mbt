///|
fn parse(text : String) -> Json raise {
  @json.parse(text)
}

///|
test "decode after encode gives the value back" {
  let sp = (a : Int32, b : Int32) => @span.SrcSpan::new(a, b)
  let e : @ast.Expr = Call(
    location=sp(0, 10),
    fun=Var(location=sp(0, 3), name="add"),
    arguments=[
        @ast.CallArg::{
          label: None,
          location: sp(4, 5),
          value: @ast.Expr::Int(
            location=sp(4, 5),
            value="1",
            int_value=BigInt::from_int(1),
          ),
          implicit: None,
        },
        @ast.CallArg::{
          label: Some("b"),
          location: sp(7, 9),
          value: @ast.Expr::Float(
            location=sp(7, 9),
            value="1.",
            float_value=1.0,
          ),
          implicit: Some(@ast.ImplicitCallArgOrigin::Pipe),
        },
      ][:],
    open_parenthesis=3,
  )
  let back = @ast.decode_expr(parse(@ast.canonical(@ast.encode_expr(e))))
  @expect.expect(back).to_equal(e)
}

///|
test "float_value is derived from the lexeme and big ints keep their digits" {
  let f = @ast.decode_expr(
    parse(
      "{\"kind\":\"float\",\"location\":{\"end\":5,\"start\":0},\"value\":\"1_0.5\"}",
    ),
  )
  guard f is Float(float_value~, ..) else { fail("expected a float") }
  @expect.expect(float_value).to_equal(10.5)
  let big = "123456789012345678901234567890"
  let i = @ast.decode_expr(
    parse(
      "{\"int_value\":\"-\{big}\",\"kind\":\"int\",\"location\":{\"end\":1,\"start\":0},\"value\":\"-\{big}\"}",
    ),
  )
  guard i is Int(int_value~, ..) else { fail("expected an int") }
  @expect.expect(int_value).to_equal(-BigInt::from_string(big))
}

///|
test "errors name the path and the problem" {
  let cases = [
    ("{\"kind\":\"nope\"}", "$.kind: unknown expression kind \"nope\""),
    (
      "{\"kind\":\"var\",\"location\":{\"end\":1,\"start\":0}}", "$.name: missing field",
    ),
    (
      "{\"kind\":\"var\",\"location\":{\"end\":\"x\",\"start\":0},\"name\":\"a\"}",
      "$.location.end: expected a number, found a STRING",
    ),
    (
      "{\"int_value\":\"1x\",\"kind\":\"int\",\"location\":{\"end\":1,\"start\":0},\"value\":\"1\"}",
      "$.int_value: not a decimal integer",
    ),
    (
      "{\"kind\":\"float\",\"location\":{\"end\":1,\"start\":0},\"value\":\"abc\"}",
      "$.value: not a float literal",
    ),
    (
      "{\"kind\":\"bin_op\",\"left\":{\"kind\":\"var\",\"location\":{\"end\":1,\"start\":0},\"name\":\"a\"},\"location\":{\"end\":5,\"start\":0},\"operator\":\"plus\",\"operator_start\":2,\"right\":{\"kind\":\"var\",\"location\":{\"end\":5,\"start\":4},\"name\":\"b\"}}",
      "$.operator: unknown operator \"plus\"",
    ),
    (
      "{\"clauses\":[{\"alternative_patterns\":[[{\"kind\":\"nope\"}]],\"guard\":null,\"location\":{\"end\":1,\"start\":0},\"pattern\":[],\"then\":{\"kind\":\"var\",\"location\":{\"end\":1,\"start\":0},\"name\":\"x\"}}],\"kind\":\"case\",\"location\":{\"end\":1,\"start\":0},\"subjects\":[]}",
      "$.clauses[0].alternative_patterns[0][0].kind: unknown pattern kind \"nope\"",
    ),
    ("[]", "$: expected an OBJECT, found an ARRAY"),
  ]
  @expect.expect_all(e => {
    for c in cases {
      let (text, expected) = c
      let got = try {
        @ast.decode_expr(parse(text)) |> ignore
        "no error"
      } catch {
        @ast.DecodeError(path~, message~) => "\{path}: \{message}"
        _ => "other error"
      }
      e.expect(got).to_equal(expected)
    }
  })
}

///|
test "a parsed module decodes with its extra and warnings" {
  let text =
    #|{"extra":{"comments":[],"doc_comments":[{"end":9,"start":3}],"empty_lines":[],"module_comments":[],"new_lines":[10],"trailing_commas":[]},"module":{"definitions":[{"definition":{"documentation":null,"kind":"module_constant","location":{"end":21,"start":11},"name":"x","name_location":{"end":18,"start":17},"annotation":null,"publicity":{"kind":"public"},"value":{"int_value":"1","kind":"int","location":{"end":21,"start":20},"value":"1"},"deprecation":{"kind":"not_deprecated"}},"target":null}]},"warnings":[{"kind":"detached_doc_comment","location":{"end":9,"start":3}}]}
  let p = @ast.decode_parsed(parse(text))
  @expect.expect_all(e => {
    e.expect(p.extra.doc_comments).to_equal([@span.SrcSpan::new(3, 9)])
    e
    .expect(p.warnings)
    .to_equal([
      @ast.Warning::DetachedDocComment(location=@span.SrcSpan::new(3, 9)),
    ])
    e.expect(p.module_.definitions.length()).to_equal(1)
    guard p.module_.definitions[0].definition is ModuleConstant(c) else {
      fail("expected a constant")
    }
    e.expect(c.name).to_equal("x")
    e
    .expect(@ast.canonical(@ast.encode_parsed(p)))
    .to_equal(
      // Canonical order differs from the hand-written text above.
      @ast.canonical(parse(text)),
    )
  })
}

///|
test "tuple and guard indexes are 64-bit like the compiler's u64" {
  let sp = (a : Int32, b : Int32) => @span.SrcSpan::new(a, b)
  for index in [4294967296UL, 18446744073709551615UL, 0UL] {
    let e : @ast.Expr = TupleIndex(
      location=sp(0, 5),
      index~,
      tuple=Var(location=sp(0, 1), name="t"),
    )
    let text = @ast.canonical(@ast.encode_expr(e))
    @expect.expect_all(x => {
      x.expect(text).to_contain("\"index\":\{index}")
      x.expect(@ast.decode_expr(parse(text))).to_equal(e)
    })
    let g : @ast.ClauseGuard = TupleIndex(
      location=sp(0, 5),
      index~,
      tuple=Var(location=sp(0, 1), name="t"),
    )
    @expect.expect(
      @ast.decode_clause_guard(
        parse(@ast.canonical(@ast.encode_clause_guard(g))),
      ),
    ).to_equal(g)
    let f : @ast.ClauseGuard = FieldAccess(
      label_location=sp(2, 3),
      index=Some(index),
      label="a",
      container=Var(location=sp(0, 1), name="t"),
    )
    @expect.expect(
      @ast.decode_clause_guard(
        parse(@ast.canonical(@ast.encode_clause_guard(f))),
      ),
    ).to_equal(f)
  }
}

///|
fn chain(n : Int32) -> @ast.Expr {
  let sp = @span.SrcSpan::new(0, 1)
  let mut e : @ast.Expr = Int(
    location=sp,
    value="1",
    int_value=BigInt::from_int(1),
  )
  for _ in 0..<n {
    e = BinOp(
      location=sp,
      operator=AddInt,
      operator_start=0,
      left=e,
      right=Int(location=sp, value="1", int_value=BigInt::from_int(1)),
    )
  }
  e
}

///|
/// A list nested `n` deep: `[[[...1...]]]`.
fn nested_list(n : Int32) -> @ast.Expr {
  let sp = @span.SrcSpan::new(0, 1)
  let mut e : @ast.Expr = Int(
    location=sp,
    value="1",
    int_value=BigInt::from_int(1),
  )
  for _ in 0..<n {
    e = List(location=sp, elements=[e][:], tail=None)
  }
  e
}

///|
/// Deep values are compared through their canonical text: the derived
/// `Eq` of the AST recurses and is not safe at this depth on wasm.
fn same_text(a : @ast.Expr, b : @ast.Expr) -> Bool {
  @ast.canonical(@ast.encode_expr(a)) == @ast.canonical(@ast.encode_expr(b))
}

///|
test "a 2000-term operator chain round-trips through the Json value on every target" {
  let deep = chain(2000)
  let back = @ast.decode_expr(@ast.encode_expr(deep))
  @expect.expect(same_text(deep, back)).to_be_true()
}

///|
test "a 2000-deep list round-trips through the Json value on every target" {
  let deep = nested_list(2000)
  let back = @ast.decode_expr(@ast.encode_expr(deep))
  @expect.expect(same_text(deep, back)).to_be_true()
}

///|
test "a 500-deep list round-trips through canonical text on every target" {
  // `@json.parse` recurses and has its own default nesting limit (1024 JSON
  // levels; a list node is two), so the text round trip stays under it;
  // the codec itself has no limit.
  let deep = nested_list(500)
  let text = @ast.canonical(@ast.encode_expr(deep))
  let back = @ast.decode_expr(@json.parse(text))
  @expect.expect(@ast.canonical(@ast.encode_expr(back))).to_equal(text)
}

///|
test "an error 2000 levels deep renders its path" {
  // Built in a loop (no recursion in the test): 2000 list objects around
  // a leaf of unknown kind.
  let sp : Json = Json::object({
    "end": Json::number(1.0),
    "start": Json::number(0.0),
  })
  let mut j : Json = Json::object({ "kind": Json::string("nope") })
  for _ in 0..<2000 {
    j = Json::object({
      "kind": Json::string("list"),
      "location": sp,
      "elements": Json::array([j]),
      "tail": Json::null(),
    })
  }
  let got = try {
    @ast.decode_expr(j) |> ignore
    "no error"
  } catch {
    @ast.DecodeError(path~, message~) => "\{path}: \{message}"
  }
  let expected = StringBuilder()
  expected.write_string("$")
  for _ in 0..<2000 {
    expected.write_string(".elements[0]")
  }
  expected.write_string(".kind: unknown expression kind \"nope\"")
  @expect.expect(got).to_equal(expected.to_string())
}
