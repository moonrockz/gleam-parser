///|
fn parse(text : String) -> Json raise {
  @json.parse(text)
}

///|
fn[A] decoding_error(
  json : Json,
  decode : (Json) -> A raise @ast.DecodeError,
) -> String {
  try {
    decode(json) |> ignore
    "no error"
  } catch {
    @ast.DecodeError(path~, message~) => "\{path}: \{message}"
  }
}

///|
test "bit array units fit the compiler's byte range" {
  @expect.expect_all(e => {
    for unit in [-1, 0, 1, 255, 256] {
      let text =
        $|{"kind":"bit_array","location":{"start":0,"end":1},"segments":[{"location":{"start":0,"end":1},"value":{"kind":"var","location":{"start":0,"end":1},"name":"x"},"options":[{"kind":"unit","location":{"start":0,"end":1},"value":\{unit}}]}]}
      let json = parse(text)
      if unit >= 0 && unit <= 255 {
        e
        .expect(@ast.canonical(@ast.encode_expr(@ast.decode_expr(json))))
        .to_equal(@ast.canonical(json))
      } else {
        let message = if unit < 0 {
          "expected a non-negative integer, found \{unit}"
        } else {
          "expected an integer in 0..255, found \{unit}"
        }
        e
        .expect(decoding_error(json, @ast.decode_expr))
        .to_equal("$.segments[0].options[0].value: \{message}")
      }
    }
  })
}

///|
test "positions reject negative and out-of-range integers at their JSON path" {
  @expect.expect_all(e => {
    for
      (number, message) in [
        ("-1", "expected a non-negative integer, found -1"),
        ("1.5", "expected an integer, found 1.5"),
        ("2147483648", "expected an integer, found 2147483648"),
      ] {
      let text =
        $|{"kind":"var","location":{"start":\{number},"end":0},"name":"x"}
      let got = try {
        @ast.decode_expr(parse(text)) |> ignore
        "no error"
      } catch {
        @ast.DecodeError(path~, message~) => "\{path}: \{message}"
        _ => "other error"
      }
      e.expect(got).to_equal("$.location.start: \{message}")
    }
    for start in [0, 2147483647] {
      // An end of zero is the compiler's sentinel for an inner EOF error.
      let value : @ast.Expr = Var(
        location=@span.SrcSpan::from_compiler(
          @span.ByteOffset::from_int(start).unwrap(),
          @span.ByteOffset::zero(),
        ).unwrap(),
        name="x",
      )
      e.expect(@ast.decode_expr(@ast.encode_expr(value))).to_equal(value)
    }
  })
}

///|
test "int_value uses canonical decimal digits" {
  @expect.expect_all(e => {
    for
      digits in [
        "", "-", "00", "01", "-01", "-0", "+1", "1_0", " 1", "1.0", "0x1",
      ] {
      let text =
        $|{"kind":"int","location":{"start":0,"end":1},"value":"1","int_value":"\{digits}"}
      e
      .expect(decoding_error(parse(text), @ast.decode_expr))
      .to_equal("$.int_value: not a canonical decimal integer")
    }
    for
      digits in [
        "0", "1", "-1", "123456789012345678901234567890", "-123456789012345678901234567890",
      ] {
      let text =
        $|{"kind":"int","location":{"start":0,"end":1},"value":"\{digits}","int_value":"\{digits}"}
      e
      .expect(@ast.canonical(@ast.encode_expr(@ast.decode_expr(parse(text)))))
      .to_equal(@ast.canonical(parse(text)))
    }
  })
}

///|
test "float nodes require a complete Gleam float lexeme" {
  @expect.expect_all(e => {
    for
      value in [
        "1", "1e3", ".5", "+1.0", "1.0E3", "1.0e+3", "_1.0", "1_.0", "1.0_", "1__0.5",
        "1.0e", "1.0e_", "inf", "NaN", " 1.0", "1.0 ", "1.0 // comment",
      ] {
      let text =
        $|{"kind":"float","location":{"start":0,"end":1},"value":"\{value}"}
      let json = parse(text)
      e
      .expect(decoding_error(json, @ast.decode_expr))
      .to_equal("$.value: not a float literal")
      e
      .expect(decoding_error(json, @ast.decode_pattern))
      .to_equal("$.value: not a float literal")
      e
      .expect(decoding_error(json, @ast.decode_constant))
      .to_equal("$.value: not a float literal")
    }
    // The lexer permits a separator before fractional or exponent digits.
    for
      value in [
        "0.", "-0.0", "1.5", "1.e3", "1_0.5", "1._2", "1.0e_2", "1.0e-3", "1.0e99999999999",
        "1.0e-99999999999",
      ] {
      let text =
        $|{"kind":"float","location":{"start":0,"end":1},"value":"\{value}"}
      let json = parse(text)
      e
      .expect(@ast.canonical(@ast.encode_expr(@ast.decode_expr(json))))
      .to_equal(@ast.canonical(json))
      e
      .expect(@ast.canonical(@ast.encode_pattern(@ast.decode_pattern(json))))
      .to_equal(@ast.canonical(json))
      e
      .expect(@ast.canonical(@ast.encode_constant(@ast.decode_constant(json))))
      .to_equal(@ast.canonical(json))
    }
  })
}

///|
test "decode after encode gives the value back" {
  let sp = (a : Int32, b : Int32) => @span.SrcSpan::from_ints(a, b).unwrap()
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
    open_parenthesis=@span.ByteOffset::from_int(3).unwrap(),
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
      "{\"kind\":\"var\",\"location\":{\"end\":2,\"start\":3},\"name\":\"a\"}", "$.location.end: span end precedes start",
    ),
    (
      "{\"int_value\":\"1x\",\"kind\":\"int\",\"location\":{\"end\":1,\"start\":0},\"value\":\"1\"}",
      "$.int_value: not a canonical decimal integer",
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
    e
    .expect(p.extra.doc_comments)
    .to_equal([@span.SrcSpan::from_ints(3, 9).unwrap()])
    e
    .expect(p.warnings)
    .to_equal([
      @ast.Warning::DetachedDocComment(
        location=@span.SrcSpan::from_ints(3, 9).unwrap(),
      ),
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
test "tuple and guard indexes reject negatives, fractions and overflow" {
  @expect.expect_all(e => {
    for index in ["-1", "1.5", "18446744073709551616"] {
      let tuple =
        $|{"kind":"tuple_index","location":{"start":0,"end":1},"index":\{index},"tuple":{"kind":"var","location":{"start":0,"end":1},"name":"x"}}
      let field =
        $|{"kind":"field_access","label_location":{"start":0,"end":1},"index":\{index},"label":"a","container":{"kind":"var","location":{"start":0,"end":1},"name":"x"}}
      let expected = "$.index: expected an unsigned 64-bit integer, found \{index}"
      e
      .expect(decoding_error(parse(tuple), @ast.decode_expr))
      .to_equal(expected)
      e
      .expect(decoding_error(parse(tuple), @ast.decode_clause_guard))
      .to_equal(expected)
      e
      .expect(decoding_error(parse(field), @ast.decode_clause_guard))
      .to_equal(expected)
    }
  })
}

///|
test "law: negative positions and indexes always fail decoding" {
  @quickcheck.check(
    (seed : Int32) => {
      let negative = -(seed % 2147483647).abs() - 1
      let position =
        $|{"kind":"var","location":{"start":0,"end":\{negative}},"name":"x"}
      let index =
        $|{"kind":"tuple_index","location":{"start":0,"end":1},"index":\{negative},"tuple":{"kind":"var","location":{"start":0,"end":1},"name":"x"}}
      let extra =
        $|{"comments":[],"doc_comments":[],"module_comments":[],"empty_lines":[],"new_lines":[\{negative}],"trailing_commas":[]}
      decoding_error(parse(position), @ast.decode_expr).has_prefix(
        "$.location.end:",
      ) &&
      decoding_error(parse(index), @ast.decode_expr).has_prefix("$.index:") &&
      decoding_error(parse(extra), @ast.decode_extra).has_prefix(
        "$.new_lines[0]:",
      )
    },
    count=100,
    seed=2047,
  )
}

///|
test "tuple and guard indexes are 64-bit like the compiler's u64" {
  let sp = (a : Int32, b : Int32) => @span.SrcSpan::from_ints(a, b).unwrap()
  for index in [4294967296UL, 18446744073709551615UL, 0UL] {
    let e : @ast.Expr = TupleIndex(
      location=sp(0, 5),
      index=@ast.TupleIndex(index),
      tuple=Var(location=sp(0, 1), name="t"),
    )
    let text = @ast.canonical(@ast.encode_expr(e))
    @expect.expect_all(x => {
      x.expect(text).to_contain("\"index\":\{index}")
      x.expect(@ast.decode_expr(parse(text))).to_equal(e)
    })
    let g : @ast.ClauseGuard = TupleIndex(
      location=sp(0, 5),
      index=@ast.TupleIndex(index),
      tuple=Var(location=sp(0, 1), name="t"),
    )
    @expect.expect(
      @ast.decode_clause_guard(
        parse(@ast.canonical(@ast.encode_clause_guard(g))),
      ),
    ).to_equal(g)
    let f : @ast.ClauseGuard = FieldAccess(
      label_location=sp(2, 3),
      index=Some(@ast.TupleIndex(index)),
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
  let sp = @span.SrcSpan::from_ints(0, 1).unwrap()
  let mut e : @ast.Expr = Int(
    location=sp,
    value="1",
    int_value=BigInt::from_int(1),
  )
  for _ in 0..<n {
    e = BinOp(
      location=sp,
      operator=AddInt,
      operator_start=@span.ByteOffset::from_int(0).unwrap(),
      left=e,
      right=Int(location=sp, value="1", int_value=BigInt::from_int(1)),
    )
  }
  e
}

///|
/// A list nested `n` deep: `[[[...1...]]]`.
fn nested_list(n : Int32) -> @ast.Expr {
  let sp = @span.SrcSpan::from_ints(0, 1).unwrap()
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

///|
fn sp0() -> @span.SrcSpan {
  @span.SrcSpan::from_ints(0, 1).unwrap()
}

///|
fn var_x() -> @ast.Expr {
  Var(location=sp0(), name="x")
}

///|
/// Wrap `inner` `n` times with `wrap`, in a loop (no recursion in the
/// test).
fn[A] spine(n : Int32, leaf : A, wrap : (A) -> A) -> A {
  let mut v = leaf
  for _ in 0..<n {
    v = wrap(v)
  }
  v
}

///|
fn stmt(inner : @ast.Expr, s : @ast.Statement) -> @ast.Expr {
  ignore(inner)
  Block(location=sp0(), statements=[s][:])
}

///|
/// Every child edge of the expression encoder, each as a 2000-deep spine:
/// a bug that recurses on one edge (an encoder that re-enters `run`, a
/// continuation called directly) overflows wasm or js here.
test "every expression child edge round-trips 2000 deep through the Json value on every target" {
  let sp = sp0()
  let wraps : Array[(String, (@ast.Expr) -> @ast.Expr)] = [
    ("todo message", e => Todo(kind=Keyword, location=sp, message=Some(e))),
    ("panic message", e => Panic(location=sp, message=Some(e))),
    (
      "echo expression",
      e => {
        Echo(
          location=sp,
          keyword_end=@span.ByteOffset::from_int(0).unwrap(),
          expression=Some(e),
          message=None,
        )
      },
    ),
    (
      "call argument",
      e => {
        Call(
          location=sp,
          fun=var_x(),
          arguments=[
              (
                { label: None, location: sp, value: e, implicit: None, } :
                @ast.CallArg[@ast.Expr]),
            ][:],
          open_parenthesis=@span.ByteOffset::from_int(0).unwrap(),
        )
      },
    ),
    (
      "record update argument",
      e => {
        RecordUpdate(
          location=sp,
          spread_start=@span.ByteOffset::from_int(0).unwrap(),
          constructor_=var_x(),
          record=(
            { base: var_x(), location: sp, } :
            @ast.RecordBeingUpdated[@ast.Expr]),
          arguments=[
              (
                { label: "a", location: sp, value: e, } :
                @ast.RecordUpdateArg[@ast.Expr]),
            ][:],
        )
      },
    ),
    (
      "record being updated",
      e => {
        RecordUpdate(
          location=sp,
          spread_start=@span.ByteOffset::from_int(0).unwrap(),
          constructor_=var_x(),
          record=(
            { base: e, location: sp, } : @ast.RecordBeingUpdated[@ast.Expr]),
          arguments=[][:],
        )
      },
    ),
    (
      "bit array size option",
      e => {
        BitArray(
          location=sp,
          segments=[
              (
                {
                  location: sp,
                  value: var_x(),
                  options: [@ast.Size(location=sp, value=e, short_form=false)][:],
                } : @ast.BitArraySegment[@ast.Expr]),
            ][:],
        )
      },
    ),
    (
      "bit array segment value",
      e => {
        BitArray(
          location=sp,
          segments=[
              (
                { location: sp, value: e, options: [][:], } :
                @ast.BitArraySegment[@ast.Expr]),
            ][:],
        )
      },
    ),
    (
      "case clause then",
      e => {
        Case(
          location=sp,
          subjects=[var_x()][:],
          clauses=Some(
            [
              (
                {
                  location: sp,
                  pattern: [@ast.Pattern::Discard(name="_", location=sp)][:],
                  alternative_patterns: [][:],
                  guard_: None,
                  then: e,
                } : @ast.Clause),
            ][:],
          ),
        )
      },
    ),
    ("case subject", e => Case(location=sp, subjects=[e][:], clauses=None)),
    ("block statement", e => stmt(e, @ast.Expression(e))),
    (
      "fn body",
      e => {
        Fn(
          location=sp,
          kind=Anonymous(head=sp),
          end_of_head_byte_index=@span.ByteOffset::from_int(0).unwrap(),
          arguments=[][:],
          body=[@ast.Expression(e)][:],
          return_annotation=None,
        )
      },
    ),
    (
      "assignment value",
      e => {
        stmt(
          e,
          @ast.Assignment({
            location: sp,
            value: e,
            pattern: @ast.Pattern::Discard(name="_", location=sp),
            kind: Let,
            annotation: None,
          }),
        )
      },
    ),
    (
      "assert message of let assert",
      e => {
        stmt(
          e,
          @ast.Assignment({
            location: sp,
            value: var_x(),
            pattern: @ast.Pattern::Discard(name="_", location=sp),
            kind: Assert(
              location=sp,
              assert_keyword_start=@span.ByteOffset::from_int(0).unwrap(),
              message=Some(e),
            ),
            annotation: None,
          }),
        )
      },
    ),
    (
      "use call",
      e => {
        stmt(
          e,
          @ast.Use({
            call: e,
            location: sp,
            right_hand_side_location: sp,
            assignments_location: sp,
            assignments: [][:],
          }),
        )
      },
    ),
    (
      "assert statement message",
      e => {
        stmt(
          e,
          @ast.Assert({ location: sp, value: var_x(), message: Some(e), }),
        )
      },
    ),
    ("tuple", e => Tuple(location=sp, elements=[e][:])),
    ("pipeline", e => Pipeline(expressions=[var_x(), e][:])),
    (
      "field access",
      e => FieldAccess(location=sp, label_location=sp, label="f", container=e),
    ),
    (
      "tuple index",
      e => TupleIndex(location=sp, index=@ast.TupleIndex(0), tuple=e),
    ),
    ("negate bool", e => NegateBool(location=sp, value=e)),
    ("list tail", e => List(location=sp, elements=[][:], tail=Some(e))),
  ]
  @expect.expect_all(x => {
    for w in wraps {
      let (name, wrap) = w
      let deep = spine(2000, var_x(), wrap)
      let text = @ast.canonical(@ast.encode_expr(deep))
      let back = @ast.canonical(
        @ast.encode_expr(@ast.decode_expr(@ast.encode_expr(deep))),
      ) catch {
        @ast.DecodeError(path~, message~) => "\{path}: \{message}"
      }
      x.expect((name, back == text)).to_equal((name, true))
    }
  })
}

///|
/// The child edges of patterns, types, constants, guards and bit array
/// sizes, each as a 2000-deep spine inside one definition or expression.
test "every other node kind round-trips 2000 deep through the Json value on every target" {
  let sp = sp0()
  let deep_pattern : @ast.Pattern = spine(
    2000,
    Discard(name="_", location=sp),
    p => List(location=sp, elements=[p][:], tail=None),
  )
  let deep_pattern_tail : @ast.Pattern = spine(
    2000,
    Discard(name="_", location=sp),
    p => {
      List(
        location=sp,
        elements=[][:],
        tail=Some({ location: sp, pattern: p, }),
      )
    },
  )
  let deep_pattern_arg : @ast.Pattern = spine(
    2000,
    Discard(name="_", location=sp),
    p => {
      Constructor(
        location=sp,
        name_location=sp,
        name="C",
        arguments=[
            (
              { label: None, location: sp, value: p, implicit: None, } :
              @ast.CallArg[@ast.Pattern]),
          ][:],
        module_=None,
        spread=None,
      )
    },
  )
  let deep_size : @ast.Pattern = BitArraySize(
    spine(2000, Variable(location=sp, name="n"), s => {
      Block(location=sp, inner=s)
    }),
  )
  let deep_guard : @ast.ClauseGuard = spine(2000, Var(location=sp, name="g"), g => {
    Block(location=sp, value=g)
  })
  let deep_type : @ast.TypeAst = spine(
    2000,
    Var({ location: sp, name: "a", }),
    t => Tuple({ location: sp, elements: [t][:], }),
  )
  let deep_type_fn : @ast.TypeAst = spine(
    2000,
    Var({ location: sp, name: "a", }),
    t => Fn({ location: sp, arguments: [][:], return_: t, }),
  )
  let deep_constant : @ast.Constant = spine(
    2000,
    Var(location=sp, module_=None, name="c"),
    c => List(location=sp, elements=[c][:], tail=None),
  )
  let deep_constant_arg : @ast.Constant = spine(
    2000,
    Var(location=sp, module_=None, name="c"),
    c => {
      Record(
        location=sp,
        arguments_start_position=@span.ByteOffset::from_int(0).unwrap(),
        module_=None,
        name="R",
        arguments=Some(
          [
            (
              { label: None, location: sp, value: c, implicit: None, } :
              @ast.CallArg[@ast.Constant]),
          ][:],
        ),
      )
    },
  )
  let cases : Array[(String, Json)] = [
    ("pattern list", @ast.encode_pattern(deep_pattern)),
    ("pattern list tail", @ast.encode_pattern(deep_pattern_tail)),
    ("pattern constructor argument", @ast.encode_pattern(deep_pattern_arg)),
    ("bit array size", @ast.encode_pattern(deep_size)),
    ("clause guard", @ast.encode_clause_guard(deep_guard)),
    ("type tuple", @ast.encode_type_ast(deep_type)),
    ("type fn return", @ast.encode_type_ast(deep_type_fn)),
    ("constant list", @ast.encode_constant(deep_constant)),
    ("constant record argument", @ast.encode_constant(deep_constant_arg)),
    (
      "module constant value",
      @ast.encode_definition(
        @ast.ModuleConstant({
          documentation: None,
          location: sp,
          publicity: Public,
          name: "c",
          name_location: sp,
          annotation: Some(deep_type),
          value: deep_constant,
          deprecation: NotDeprecated,
        }),
      ),
    ),
  ]
  @expect.expect_all(x => {
    for c in cases {
      let (name, json) = c
      let text = @ast.canonical(json)
      let back = try {
        match name {
          "clause guard" =>
            @ast.canonical(
              @ast.encode_clause_guard(@ast.decode_clause_guard(json)),
            )
          "type tuple" | "type fn return" =>
            @ast.canonical(@ast.encode_type_ast(@ast.decode_type_ast(json)))
          "constant list" | "constant record argument" =>
            @ast.canonical(@ast.encode_constant(@ast.decode_constant(json)))
          "module constant value" =>
            @ast.canonical(@ast.encode_definition(@ast.decode_definition(json)))
          _ => @ast.canonical(@ast.encode_pattern(@ast.decode_pattern(json)))
        }
      } catch {
        @ast.DecodeError(path~, message~) => "\{path}: \{message}"
      }
      x.expect((name, back == text)).to_equal((name, true))
    }
  })
}
