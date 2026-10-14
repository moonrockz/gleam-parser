///|
test "names, upnames, discard names and keywords" {
  @expect.expect_all(e => {
    e
    .expect(kinds("foo _bar Baz fooBar _ x1"))
    .to_equal([
      Name("foo"),
      DiscardName("_bar"),
      UpName("Baz"),
      Name("fooBar"),
      DiscardName("_"),
      Name("x1"),
    ])
    e
    .expect(kinds("pub fn type let use import as"))
    .to_equal([
      Keyword(Pub),
      Keyword(Fn),
      Keyword(Type),
      Keyword(Let),
      Keyword(Use),
      Keyword(Import),
      Keyword(As),
    ])
    e
    .expect(kinds("macro derive implement delegate auto test echo"))
    .to_equal([
      Keyword(Macro),
      Keyword(Derive),
      Keyword(Implement),
      Keyword(Delegate),
      Keyword(Auto),
      Keyword(Test),
      Keyword(Echo),
    ])
    e.expect(kinds("fn_ Fn")).to_equal([Name("fn_"), UpName("Fn")])
    e
    .expect(dump("ab Cd"))
    .to_equal([(Name("ab"), "ab", 0, 2), (UpName("Cd"), "Cd", 3, 5)])
  })
}

///|
fn int(value : String) -> @scanner.TokenKind {
  Int(value~, int_value=@scanner.parse_int_value(value).unwrap())
}

///|
fn float(value : String) -> @scanner.TokenKind {
  Float(value~, float_value=@scanner.parse_float_value(value).unwrap())
}

///|
test "integer literals in every radix, with separators and signs" {
  @expect.expect_all(e => {
    e
    .expect(kinds("1 42 1_000 0x1F 0XfF 0o17 0O7 0b101 0B1"))
    .to_equal([
      int("1"),
      int("42"),
      int("1_000"),
      int("0x1F"),
      int("0xfF"),
      int("0o17"),
      int("0o7"),
      int("0b101"),
      int("0b1"),
    ])
    e.expect(kinds("-1 -0x10")).to_equal([int("-1"), int("-0x10")])
    e.expect(dump("-1_0")).to_equal([(int("-1_0"), "-1_0", 0, 4)])
  })
}

///|
test "an uppercase radix letter is kept in the lexeme but lower in the value" {
  let s = stream("0XfF")
  @expect.expect_all(e => {
    e.expect(s.tokens[0].lexeme).to_equal("0XfF")
    e.expect(s.tokens[0].kind).to_equal(int("0xfF"))
  })
}

///|
test "float literals" {
  @expect.expect_all(e => {
    e
    .expect(kinds("1.5 1. 1.0e3 1.0e-3 1_0.5 -2.5"))
    .to_equal([
      float("1.5"),
      float("1."),
      float("1.0e3"),
      float("1.0e-3"),
      float("1_0.5"),
      float("-2.5"),
    ])
    e.expect(kinds("1.e3")).to_equal([float("1.e3")])
    e.expect(kinds("1.0E3")).to_equal([float("1.0"), UpName("E3")])
    e.expect(kinds("1.0e+3")).to_equal([Error, Plus, int("3")])
  })
}

///|
test "a minus directly after a name or number is an operator" {
  @expect.expect_all(e => {
    e.expect(kinds("x-1")).to_equal([Name("x"), Minus, int("1")])
    e.expect(kinds("1-1")).to_equal([int("1"), Minus, int("1")])
    e.expect(kinds("x -1")).to_equal([Name("x"), int("-1")])
    e.expect(kinds("x - 1")).to_equal([Name("x"), Minus, int("1")])
    e.expect(kinds("x--1")).to_equal([Name("x"), Minus, int("-1")])
    e.expect(kinds("Ab-1")).to_equal([UpName("Ab"), int("-1")])
  })
}

///|
test "tuple access after a dot lexes integers, not floats" {
  @expect.expect_all(e => {
    e.expect(kinds("t.1")).to_equal([Name("t"), Dot, int("1")])
    e.expect(kinds("t.1.2")).to_equal([Name("t"), Dot, int("1"), Dot, int("2")])
    e.expect(kinds("t.1.5")).to_equal([Name("t"), Dot, int("1"), Dot, int("5")])
    e.expect(kinds("a.b")).to_equal([Name("a"), Dot, Name("b")])
    e.expect(kinds("..1")).to_equal([DotDot, int("1")])
  })
}

///|
test "number errors: trailing underscore, empty radix, digit out of radix, missing exponent" {
  @expect.expect_all(e => {
    e.expect(error_kinds("1_000_ x")).to_equal(["NumTrailingUnderscore"])
    e
    .expect(stream("1_000_ x").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(5, 5))
    e.expect(kinds("1_000_ x")).to_equal([Error, Name("x")])
    e.expect(stream("1_000_ x").tokens[0].lexeme).to_equal("1_000_")
    e.expect(error_kinds("0x")).to_equal(["RadixIntNoValue"])
    e
    .expect(stream("0x").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(1, 1))
    e.expect(stream("0x").tokens[0].lexeme).to_equal("0x")
    e.expect(error_kinds("0b12")).to_equal(["DigitOutOfRadix"])
    e
    .expect(stream("0b12").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(3, 3))
    e.expect(stream("0b12").tokens[0].lexeme).to_equal("0b12")
    e.expect(error_kinds("0o18")).to_equal(["DigitOutOfRadix"])
    e.expect(error_kinds("1.0e x")).to_equal(["MissingExponent"])
    e
    .expect(stream("1.0e x").diagnostics[0].span)
    .to_equal(@span.SrcSpan::new(0, 4))
    e.expect(kinds("1.0e x")).to_equal([Error, Name("x")])
    e.expect(error_kinds("0xG")).to_equal(["RadixIntNoValue"])
    // `1__0`: the run stops before `__`, then the `_` is a trailing one.
    e.expect(error_kinds("1__0")).to_equal(["NumTrailingUnderscore"])
    e.expect(kinds("1__0")).to_equal([Error, DiscardName("_0")])
  })
}

///|
test "a float with a huge exponent is infinity and the scan stays lossless" {
  let text = "x = 1.0e99999999999 + y"
  let s = stream(text)
  @expect.expect_all(e => {
    e.expect(s.to_source()).to_equal(text)
    e.expect(s.diagnostics.length()).to_equal(0)
    e
    .expect(kinds(text))
    .to_equal([
      Name("x"),
      Equal,
      Float(value="1.0e99999999999", float_value=1.0 / 0.0),
      Plus,
      Name("y"),
    ])
    e
    .expect(kinds("-1.5e2147483648"))
    .to_equal([Float(value="-1.5e2147483648", float_value=-1.0 / 0.0)])
    e
    .expect(kinds("1.0e-99999999999"))
    .to_equal([Float(value="1.0e-99999999999", float_value=0.0)])
  })
}
