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
