///|
test "spans, ints, floats, strings and options encode canonically" {
  let e : @ast.Expr = Int(
    location=sp(0, 2),
    value="0x1F",
    int_value=BigInt::from_int(31),
  )
  let f : @ast.Expr = Float(location=sp(0, 2), value="1.", float_value=1.0)
  let s : @ast.Expr = String(location=sp(0, 4), value="a\"b\\c\n\u{1F}é")
  @expect.expect_all(x => {
    x
    .expect(@ast.canonical(@ast.encode_expr(e)))
    .to_equal(
      (
        #|{"int_value":"31","kind":"int","location":{"end":2,"start":0},"value":"0x1F"}
      ),
    )
    x
    .expect(@ast.canonical(@ast.encode_expr(f)))
    .to_equal(
      (
        #|{"kind":"float","location":{"end":2,"start":0},"value":"1."}
      ),
    )
    x
    .expect(@ast.canonical(@ast.encode_expr(s)))
    .to_equal(
      (
        #|{"kind":"string","location":{"end":4,"start":0},"value":"a\"b\\c\n\u001fé"}
      ),
    )
    x
    .expect(@ast.canonical(@ast.encode_expr(Pipeline(expressions=[e, f][:]))))
    .to_equal(
      (
        #|{"expressions":[{"int_value":"31","kind":"int","location":{"end":2,"start":0},"value":"0x1F"},{"kind":"float","location":{"end":2,"start":0},"value":"1."}],"kind":"pipeline"}
      ),
    )
  })
}

///|
test "a big int keeps every digit" {
  let big = "123456789012345678901234567890"
  let e : @ast.Expr = Int(
    location=sp(0, 30),
    value=big,
    int_value=BigInt::from_string(big),
  )
  @expect.expect(@ast.canonical(@ast.encode_expr(e))).to_contain(
    "\"int_value\":\"\{big}\"",
  )
}

///|
test "enums with payload are objects with kind; payload-free enums are strings" {
  let td = @ast.TargetedDefinition::{
    definition: Import({
      documentation: None,
      location: sp(0, 15),
      module_location: sp(7, 15),
      module_: "gleam/io",
      as_name: Some({ name: Discard("_io"), location: sp(19, 22), }),
      unqualified_values: [
        @ast.UnqualifiedImport::{
          location: sp(0, 1),
          name: "x",
          name_position: 0,
          as_name: None,
        },
      ][:],
      unqualified_types: [][:],
    }),
    target: Some(JavaScript),
  }
  @expect.expect(@ast.canonical(@ast.encode_targeted_definition(td))).to_equal(
    (
      #|{"definition":{"as_name":{"location":{"end":22,"start":19},"name":{"kind":"discard","name":"_io"}},"documentation":null,"kind":"import","location":{"end":15,"start":0},"module":"gleam/io","module_location":{"end":15,"start":7},"unqualified_types":[],"unqualified_values":[{"as_name":null,"location":{"end":1,"start":0},"name":"x","name_position":0}]},"target":"javascript"}
    ),
  )
  let g : @ast.ClauseGuard = BinaryOperator(
    location=sp(0, 5),
    operator=And,
    operator_start=2,
    left=Var(location=sp(0, 1), name="a"),
    right=Constant(
      Int(location=sp(4, 5), value="1", int_value=BigInt::from_int(1)),
    ),
  )
  @expect.expect(@ast.canonical(@ast.encode_clause_guard(g))).to_equal(
    (
      #|{"kind":"binary_operator","left":{"kind":"var","location":{"end":1,"start":0},"name":"a"},"location":{"end":5,"start":0},"operator":"and","operator_start":2,"right":{"constant":{"int_value":"1","kind":"int","location":{"end":5,"start":4},"value":"1"},"kind":"constant"}}
    ),
  )
  let p : @ast.Publicity = Internal(attribute_location=None)
  @expect.expect(@ast.canonical(@ast.encode_publicity(p))).to_equal(
    (
      #|{"attribute_location":null,"kind":"internal"}
    ),
  )
}

///|
test "a parsed module encodes module, extra and warnings" {
  let parsed = @ast.Parsed::{
    module_: { definitions: [][:], },
    extra: {
      module_comments: [sp(4, 10)][:],
      doc_comments: [][:],
      comments: [][:],
      empty_lines: [11][:],
      new_lines: [10, 11][:],
      trailing_commas: [][:],
    },
    warnings: [
      @ast.Warning::DeprecatedTargetShorthand(
        target=@ast.Target::Erlang,
        location=sp(0, 3),
      ),
    ][:],
  }
  @expect.expect(@ast.canonical(@ast.encode_parsed(parsed))).to_equal(
    (
      #|{"extra":{"comments":[],"doc_comments":[],"empty_lines":[11],"module_comments":[{"end":10,"start":4}],"new_lines":[10,11],"trailing_commas":[]},"module":{"definitions":[]},"warnings":[{"kind":"deprecated_target_shorthand","location":{"end":3,"start":0},"target":"erlang"}]}
    ),
  )
}

///|
fn nested_json(n : Int32) -> Json {
  let mut j : Json = Json::number(1.0)
  for _ in 0..<n {
    j = Json::array([j, Json::object({ "k": Json::string("v") })])
  }
  j
}

///|
test "canonical writes a 20000-deep value on every target" {
  let text = @ast.canonical(nested_json(20000))
  @expect.expect(text.length()).to_equal(20000 * 12 + 1)
  @expect.expect(text.has_prefix("[[[")).to_be_true()
  @expect.expect(text.has_suffix("],{\"k\":\"v\"}],{\"k\":\"v\"}]")).to_be_true()
}
