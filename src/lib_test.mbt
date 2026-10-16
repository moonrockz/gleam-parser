///|
test "version() has three numeric parts" {
  let parts = @gleam.version().split(".").collect()
  @expect.expect(parts.length()).to_equal(3)
  for part in parts {
    @expect.expect(part.length() > 0).to_be_true()
  }
}

///|
test "native constructors work through root reexports" {
  let source = @gleam.SourceText("é\nx")
  let position = @gleam.Position(
    @gleam.LineNumber::new(2).unwrap(),
    @gleam.ColumnNumber::new(1).unwrap(),
  )
  let fuel = @gleam.Fuel(budget=@gleam.Budget::new(2).unwrap())
  let inner = fuel.spend(@gleam.Operation("expression"))
  let index : @gleam.TupleIndex = @gleam.TupleIndex(18446744073709551615UL)
  let result = @gleam.parse_text("const x = 1\n")
  let tree = @gleam.Tree(result)
  let root = @gleam.NodeRef::of_result(result)
  let cursor = @gleam.TreeCursor(root)
  let reader = @gleam.EventReader(root)
  @expect.expect_all(e => {
    e
    .expect(source.position_of(@gleam.ByteOffset::new(3).unwrap()))
    .to_equal(Some(position))
    e.expect(inner.left()).to_equal(1)
    e.expect(fuel.left()).to_equal(2)
    e.expect(index.to_uint64()).to_equal(18446744073709551615UL)
    e.expect(tree.node_at(@gleam.ByteOffset::zero()) is Some(_)).to_be_true()
    e.expect(cursor.depth().to_int()).to_equal(0)
    e.expect(reader.next() is Some(_)).to_be_true()
  })
}

///|
test "the root package parses, reports and renders" {
  let text = "pub fn main() {\n  1 +\n}\n\nconst x = 1\n"
  let r = @gleam.parse_text(text)
  let source = @gleam.SourceText(text)
  @expect.expect_all(e => {
    e.expect(r.module_.definitions.length()).to_equal(1)
    e.expect(r.has_errors()).to_be_true()
    e.expect(r.diagnostics[0].kind).to_equal("OpNakedRight")
    e.expect(r.cst.to_source()).to_equal(text)
    e
    .expect(
      @gleam.render_plain(r.diagnostics[0], source, "src/main.gleam").has_prefix(
        "error: Syntax error\n  ┌─ src/main.gleam:2:5\n",
      ),
    )
    .to_be_true()
    e
    .expect(
      @gleam.encode_diagnostics(r.diagnostics)
      .stringify()
      .has_prefix("[{\"code\":\"GL-PARSE-001\""),
    )
    .to_be_true()
    e.expect(@gleam.Dialect::gleam_1_19().name).to_equal("gleam-1.19")
    e
    .expect(@gleam.parse_module(@gleam.tokenize_text(text)).parsed())
    .to_equal(r.parsed())
  })
}
