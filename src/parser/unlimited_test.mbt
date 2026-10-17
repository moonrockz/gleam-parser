///|
test "deep list expressions parse with default configuration" {
  let text = "pub fn deep() { " +
    "[".repeat(2000) +
    "1" +
    "]".repeat(2000) +
    " }"
  let result = @parser.parse_text(text)
  @expect.expect(result.has_errors()).to_be_false()
  @expect.expect(result.cst.to_source()).to_equal(text)
}

///|
test "deep parsed ASTs compare after a codec round trip" {
  let text = "pub fn deep() { " +
    "[".repeat(10000) +
    "1" +
    "]".repeat(10000) +
    " }"
  let result = @parser.parse_text(text)
  @expect.expect(result.has_errors()).to_be_false()
  let parsed = result.parsed()
  let decoded = @ast.decode_parsed(@ast.encode_parsed(parsed))
  @expect.expect(decoded == parsed).to_be_true()
  let different = @parser.parse_text(text.replace(old="1", new="2"))
  @expect.expect(different.has_errors()).to_be_false()
  @expect.expect(different.parsed() == parsed).to_be_false()
}

///|
test "mixed nesting preserves canonical ASTs and lossless source" {
  let text = "fn outer() { " +
    "fn() { case x { [y] -> [#(f({ ".repeat(600) +
    "1" +
    " }))] } }".repeat(600) +
    " }"
  let result = @parser.parse_text(text)
  @expect.expect(result.has_errors()).to_be_false()
  @expect.expect_all(s => {
    s.expect(result.cst.to_source()).to_equal(text)
    let json = @ast.encode_parsed(result.parsed())
    let decoded = @ast.decode_parsed(json)
    s.expect(decoded == result.parsed()).to_be_true()
    s
    .expect(@ast.canonical(@ast.encode_parsed(decoded)))
    .to_equal(@ast.canonical(json))
  })
}

///|
test "deep snippet parsers and every recursive grammar family stay stack safe" {
  let depth = 10000
  let pattern = @parser.parse_pattern_text(
    "[".repeat(depth) + "_" + "]".repeat(depth),
  )
  let type_ = @parser.parse_type_text("fn() -> ".repeat(depth) + "Int")
  let constant = @parser.parse_constant_text(
    "[".repeat(depth) + "1" + "]".repeat(depth),
  )
  let expression = @parser.parse_expression_text("!".repeat(depth) + "x")
  let statements = @parser.parse_statements_text(
    "let x = " + "[".repeat(depth) + "1" + "]".repeat(depth),
  )
  @expect.expect_all(s => {
    s
    .expect(@ast.decode_pattern(@ast.encode_pattern(pattern)) == pattern)
    .to_be_true()
    s
    .expect(@ast.decode_type_ast(@ast.encode_type_ast(type_)) == type_)
    .to_be_true()
    s
    .expect(@ast.decode_constant(@ast.encode_constant(constant)) == constant)
    .to_be_true()
    s
    .expect(@ast.decode_expr(@ast.encode_expr(expression)) == expression)
    .to_be_true()
    s.expect(statements.length()).to_equal(1)
  })
  let guard_ = @parser.parse_text(
    "fn f(x) { case x { _ if " + "!".repeat(depth) + "x -> 1 } }",
  )
  let size = @parser.parse_text(
    "fn f(x) { case x { <<a:size(" +
    "{".repeat(depth) +
    "1" +
    "}".repeat(depth) +
    ")>> -> a } }",
  )
  @expect.expect_all(s => {
    s.expect(guard_.has_errors()).to_be_false()
    s.expect(size.has_errors()).to_be_false()
    s
    .expect(
      @ast.decode_parsed(@ast.encode_parsed(guard_.parsed())) == guard_.parsed(),
    )
    .to_be_true()
    s
    .expect(
      @ast.decode_parsed(@ast.encode_parsed(size.parsed())) == size.parsed(),
    )
    .to_be_true()
  })
}

///|
test "deep syntax errors unwind and recover at the next definition" {
  let text = "fn broken() { " + "[".repeat(10000) + "}\nfn good() { 1 }\n"
  let result = @parser.parse_text(text)
  @expect.expect_all(s => {
    s.expect(result.diagnostics.map(d => d.kind)).to_equal(["UnexpectedToken"])
    s.expect(result.module_.definitions.length()).to_equal(1)
    s
    .expect(result.cst.definitions.map(d => d.kind))
    .to_equal([Skipped, Function])
    s.expect(result.cst.to_source()).to_equal(text)
  })
}

///|
test "deep AST debug output is available after parsing" {
  let result = @parser.parse_text(
    "fn f() { " + "[".repeat(10000) + "1" + "]".repeat(10000) + " }",
  )
  @expect.expect(result.has_errors()).to_be_false()
  let debug_text = @debug.to_string(result.parsed())
  @expect.expect_all(s => {
    s.expect(debug_text.contains("definitions:")).to_be_true()
    s.expect(debug_text.contains("...")).to_be_true()
  })
}
