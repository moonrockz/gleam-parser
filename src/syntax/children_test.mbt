///|
fn labels(n : @syntax.NodeRef) -> String {
  n
  .children_with_fields()
  .map(x => "\{x.0.field}[\{x.0.index}]:\{x.1.kind()}")
  .join(" ")
}

///|
test "a function lists arguments, body and return annotation in JSON order" {
  let root = root_of(
    "pub fn add(a: Int, b) -> Int {\n  let c = a\n  c + b\n}\n",
  )
  let f = root.field("definitions")[0]
  @expect.expect_all(e => {
    e.expect(root.fields()).to_equal(["definitions"])
    e.expect(f.fields()).to_equal(["arguments", "body", "return_annotation"])
    e
    .expect(labels(f))
    .to_equal(
      "arguments[0]:arg arguments[1]:arg return_annotation[0]:constructor body[0]:assignment body[1]:expression",
    )
    e.expect(f.field("body").length()).to_equal(2)
    e.expect(f.field("no_such_field").length()).to_equal(0)
    e.expect(f.field_of(f.field("body")[1])).to_equal(Some("body"))
    e.expect(f.field_of(root)).to_equal(None)
  })
}

///|
test "children come in source order: a bin_op gives left then right, a call fun then arguments" {
  let call = @syntax.NodeRef::Expr(@parser.parse_expression_text("f(1 + 2, x)"))
  @expect.expect_all(e => {
    e
    .expect(labels(call))
    .to_equal("fun[0]:var arguments[0]:call_arg arguments[1]:call_arg")
    let sum = call.field("arguments")[0].field("value")[0]
    e.expect(labels(sum)).to_equal("left[0]:int right[0]:int")
    e
    .expect(call.children().map(c => c.kind()))
    .to_equal(["var", "call_arg", "call_arg"])
  })
}

///|
test "a case lists subjects then clauses; a clause lists patterns, alternatives, guard and then" {
  let c = @syntax.NodeRef::Expr(
    @parser.parse_expression_text(
      "case x, y {\n  1, a | 2, b if a == b -> 0\n  _, _ -> 1\n}",
    ),
  )
  let clause = c.field("clauses")[0]
  @expect.expect_all(e => {
    e.expect(c.fields()).to_equal(["subjects", "clauses"])
    e.expect(c.field("clauses").length()).to_equal(2)
    e
    .expect(clause.fields())
    .to_equal(["pattern", "alternative_patterns", "guard", "then"])
    e
    .expect(labels(clause))
    .to_equal(
      "pattern[0]:int pattern[1]:variable alternative_patterns[0]:int alternative_patterns[1]:variable guard[0]:binary_operator then[0]:int",
    )
  })
}

///|
test "wrappers with a location are nodes: segments, options, tails, update args" {
  let bits = @syntax.NodeRef::Expr(
    @parser.parse_expression_text("<<x:size(n), 1>>"),
  )
  let list = @syntax.NodeRef::Pattern(@parser.parse_pattern_text("[a, ..rest]"))
  let update = @syntax.NodeRef::Expr(
    @parser.parse_expression_text("R(..base, f: 1)"),
  )
  @expect.expect_all(e => {
    e
    .expect(labels(bits))
    .to_equal("segments[0]:bit_array_segment segments[1]:bit_array_segment")
    e
    .expect(labels(bits.field("segments")[0]))
    .to_equal("value[0]:var options[0]:size")
    e
    .expect(labels(bits.field("segments")[0].field("options")[0]))
    .to_equal("value[0]:var")
    e.expect(labels(list)).to_equal("elements[0]:variable tail[0]:tail_pattern")
    e
    .expect(labels(update))
    .to_equal(
      "constructor[0]:var record[0]:record_being_updated arguments[0]:record_update_arg",
    )
  })
}

///|
test "an assert kind's message is a child under assignment_kind" {
  let root = root_of("fn f() {\n  let assert Ok(x) = y as \"m\"\n}\n")
  let stmt = root.field("definitions")[0].field("body")[0]
  @expect.expect_all(e => {
    e
    .expect(stmt.fields())
    .to_equal(["value", "pattern", "assignment_kind", "annotation"])
    e
    .expect(labels(stmt))
    .to_equal("pattern[0]:constructor value[0]:var assignment_kind[0]:string")
  })
}

///|
test "the kind table has one row per node type with its fields" {
  let rows = @syntax.kind_table()
  let row = rows.filter(r => r.0 == "expression" && r.1 == "case")[0]
  @expect.expect_all(e => {
    e.expect(row.2).to_equal(["subjects", "clauses"])
    e
    .expect(rows.filter(r => r.1 == "list").map(r => r.0))
    .to_equal(["expression", "pattern", "constant"])
    e.expect(rows.filter(r => r.0 == "expression").length()).to_equal(21)
    e.expect(rows.filter(r => r.0 == "pattern").length()).to_equal(12)
    e.expect(rows.filter(r => r.0 == "constant").length()).to_equal(11)
    e.expect(rows.filter(r => r.0 == "type").length()).to_equal(5)
    e.expect(rows.filter(r => r.0 == "clause_guard").length()).to_equal(7)
    e.expect(rows.filter(r => r.0 == "bit_array_size").length()).to_equal(4)
    e.expect(rows.filter(r => r.0 == "bit_array_option").length()).to_equal(17)
    e.expect(rows.filter(r => r.0 == "definition").length()).to_equal(5)
    e.expect(rows.filter(r => r.0 == "statement").length()).to_equal(4)
  })
}
