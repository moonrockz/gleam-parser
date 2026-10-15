///|
fn root_of(text : String) -> @syntax.NodeRef {
  @syntax.NodeRef::of_result(@parser.parse_text(text))
}

///|
fn sp(start : Int32, end : Int32) -> @span.SrcSpan {
  @span.SrcSpan::new(start, end)
}

///|
test "the root is the module and its span covers every token" {
  let text = "import gleam/io\n\npub fn main() {\n  io.println(\"hi\")\n}\n"
  let root = root_of(text)
  @expect.expect_all(e => {
    e.expect(root.category()).to_equal("module")
    e.expect(root.kind()).to_equal("module")
    // The last token is the closing brace at byte 52.
    e.expect(root.span()).to_equal(sp(0, 53))
    e.expect(root_of("").span()).to_equal(sp(0, 0))
  })
}

///|
test "a definition's kind is the JSON kind and its span reaches end_position" {
  let text = "pub fn main() {\n  1\n}\n\nconst x = 1\n\ntype T {\n  A\n}\n\ntype U =\n  Int\n\nimport gleam/io\n"
  let root = root_of(text)
  guard root is Module(m, _) else { fail("module") }
  let defs = m.definitions.map(d => @syntax.NodeRef::Definition(d))
  @expect.expect_all(e => {
    e
    .expect(defs.map(d => d.kind()))
    .to_equal([
      "function", "module_constant", "custom_type", "type_alias", "import",
    ])
    e.expect(defs.map(d => d.category())).to_equal(Array::make(5, "definition"))
    // `pub fn main() {\n  1\n}` is bytes 0..21: the head ends at 13, the
    // body at 21. A constant spans its head `const x` and its value.
    e.expect(defs[0].span()).to_equal(sp(0, 21))
    e.expect(defs[1].span()).to_equal(sp(23, 34))
    e.expect(defs[2].span()).to_equal(sp(36, 50))
    e.expect(defs[4].span()).to_equal(sp(68, 83))
  })
}

///|
test "expression, pattern, type and constant kinds are the JSON kinds" {
  let e1 = @syntax.NodeRef::Expr(@parser.parse_expression_text("a + b"))
  let p1 = @syntax.NodeRef::Pattern(@parser.parse_pattern_text("[x, ..rest]"))
  let t1 = @syntax.NodeRef::TypeAst(@parser.parse_type_text("fn(a) -> b"))
  let c1 = @syntax.NodeRef::Constant(@parser.parse_constant_text("<<1>>"))
  @expect.expect_all(e => {
    e.expect("\{e1.category()}/\{e1.kind()}").to_equal("expression/bin_op")
    e.expect("\{p1.category()}/\{p1.kind()}").to_equal("pattern/list")
    e.expect("\{t1.category()}/\{t1.kind()}").to_equal("type/fn")
    e.expect("\{c1.category()}/\{c1.kind()}").to_equal("constant/bit_array")
    e.expect(e1.span()).to_equal(sp(0, 5))
  })
}

///|
test "a pipeline spans its first to its last expression; an assign pattern its inner pattern to its name" {
  let pipe = @syntax.NodeRef::Expr(@parser.parse_expression_text("a |> f |> g"))
  let assign = @syntax.NodeRef::Pattern(@parser.parse_pattern_text("[x] as y"))
  @expect.expect_all(e => {
    e.expect(pipe.kind()).to_equal("pipeline")
    e.expect(pipe.span()).to_equal(sp(0, 11))
    e.expect(assign.kind()).to_equal("assign")
    e.expect(assign.span()).to_equal(sp(0, 8))
  })
}

///|
test "wrapper nodes have the category of their shape and the kind of their payload" {
  let call = @parser.parse_expression_text("f(x)")
  guard call is Call(arguments~, ..) else { fail("call") }
  let arg = @syntax.NodeRef::ExprArg(arguments[0])
  let bits = @parser.parse_expression_text("<<x:size(8)>>")
  guard bits is BitArray(segments~, ..) else { fail("bit array") }
  let seg = @syntax.NodeRef::ExprSegment(segments[0])
  let opt = @syntax.NodeRef::ExprOption(segments[0].options[0])
  @expect.expect_all(e => {
    e.expect("\{arg.category()}/\{arg.kind()}").to_equal("call_arg/call_arg")
    e.expect(arg.span()).to_equal(sp(2, 3))
    e
    .expect("\{seg.category()}/\{seg.kind()}")
    .to_equal("bit_array_segment/bit_array_segment")
    e
    .expect("\{opt.category()}/\{opt.kind()}")
    .to_equal("bit_array_option/size")
    e.expect(opt.span()).to_equal(sp(4, 11))
  })
}
