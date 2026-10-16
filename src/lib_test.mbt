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
  let position = @gleam.Position(2, 1)
  let fuel = @gleam.Fuel(budget=@gleam.Budget::from_int(2).unwrap())
  let inner = fuel.spend(@gleam.Operation("expression"))
  let index : @gleam.TupleIndex = @gleam.TupleIndex(18446744073709551615UL)
  let result = @gleam.parse_text("const x = 1\n")
  let tree = @gleam.Tree(result)
  let root = @gleam.NodeRef::of_result(result)
  let cursor = @gleam.TreeCursor(root)
  let reader = @gleam.EventReader(root)
  @expect.expect_all(e => {
    e
    .expect(source.position_of(@gleam.ByteOffset::from_int(3).unwrap()))
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
test "raising coordinate constructors expose typed errors at the root" {
  let error = try {
    ignore(@gleam.SrcSpan(-1, 3))
    None
  } catch {
    error => Some(error)
  }
  let span = @gleam.SrcSpan(0, 3)
  @expect.expect_all(e => {
    e
    .expect(error)
    .to_equal(Some(@gleam.CoordinateError::InvalidByteOffset(-1)))
    e.expect(@gleam.SrcSpan::from_ints(0, 3)).to_equal(Some(span))
    e.expect(@gleam.Position::from_ints(0, 1)).to_equal(None)
  })
}

///|
fn[T] gp_optional_value(make : () -> T raise) -> T? {
  Some(make()) catch {
    _ => None
  }
}

///|
test "law: raising bounded constructors agree with their optional factories" {
  let mut unit_successes = 0
  let law = fn(value : Int32) -> Bool {
    if value >= 0 && value <= 255 {
      unit_successes += 1
    }
    gp_optional_value(() => @gleam.Budget(value)) ==
    @gleam.Budget::from_int(value) &&
    gp_optional_value(() => @gleam.BitArrayUnit(value)) ==
    @gleam.BitArrayUnit::from_int(value) &&
    gp_optional_value(() => @gleam.ChildIndex(value)) ==
    @gleam.ChildIndex::from_int(value) &&
    gp_optional_value(() => @gleam.NodeDepth(value)) ==
    @gleam.NodeDepth::from_int(value)
  }
  @quickcheck.check(law, count=200, seed=2303)
  @expect.expect_all(e => {
    e.expect(unit_successes > 0).to_be_true()
    for edge in [-2147483648, -1, 0, 1, 255, 256, 2147483647] {
      e.expect(law(edge)).to_be_true()
    }
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
