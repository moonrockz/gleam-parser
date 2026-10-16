///|
test "a start node's path is empty" {
  @expect.expect_all(s => {
    let path = @syntax.NodePath::root()
    s.expect(path.depth()).to_equal(@syntax.NodeDepth::new(0).unwrap())
    s.expect(path.steps()).to_equal([])
    s.expect(path.last()).to_equal(None)
    s.expect(path.parent()).to_equal(None)
    s.expect(path.to_string()).to_equal("")
  })
}

///|
test "a path names each field and index from the start node" {
  @expect.expect_all(s => {
    let path = @syntax.NodePath::root()
      .child("definitions", @syntax.ChildIndex::new(0).unwrap())
      .child("body", @syntax.ChildIndex::new(1).unwrap())
      .child("value", @syntax.ChildIndex::new(0).unwrap())
      .child("arguments", @syntax.ChildIndex::new(1).unwrap())
    s.expect(path.depth()).to_equal(@syntax.NodeDepth::new(4).unwrap())
    s
    .expect(path.to_string())
    .to_equal("definitions[0].body[1].value[0].arguments[1]")
    s
    .expect(path.last())
    .to_equal(
      Some({ field: "arguments", index: @syntax.ChildIndex::new(1).unwrap(), }),
    )
    s
    .expect(path.parent().map(p => p.to_string()))
    .to_equal(Some("definitions[0].body[1].value[0]"))
  })
}

///|
test "a child path does not change its parent" {
  @expect.expect_all(s => {
    let parent = @syntax.NodePath::root().child(
      "definitions",
      @syntax.ChildIndex::new(0).unwrap(),
    )
    let a = parent.child("body", @syntax.ChildIndex::new(0).unwrap())
    let b = parent.child("arguments", @syntax.ChildIndex::new(0).unwrap())
    let steps = parent.steps()
    steps.clear()
    s.expect(parent.to_string()).to_equal("definitions[0]")
    s.expect(a.to_string()).to_equal("definitions[0].body[0]")
    s.expect(b.to_string()).to_equal("definitions[0].arguments[0]")
  })
}

///|
test "a path resolves to its node, or to None where a step does not exist" {
  let root = root_of("pub fn add(a, b) {\n  a + b\n}\n")
  @expect.expect_all(s => {
    let path = @syntax.NodePath::root()
      .child("definitions", @syntax.ChildIndex::new(0).unwrap())
      .child("body", @syntax.ChildIndex::new(0).unwrap())
      .child("expression", @syntax.ChildIndex::new(0).unwrap())
      .child("right", @syntax.ChildIndex::new(0).unwrap())
    s
    .expect(path.resolve(root).map(n => "\{n.category()}/\{n.kind()}"))
    .to_equal(Some("expression/var"))
    s
    .expect(
      @syntax.NodePath::root()
      .child("definitions", @syntax.ChildIndex::new(1).unwrap())
      .resolve(root),
    )
    .to_equal(None)
    s
    .expect(
      @syntax.NodePath::root()
      .child("nothing", @syntax.ChildIndex::new(0).unwrap())
      .resolve(root),
    )
    .to_equal(None)
  })
}

///|
test "a path's debug form lists its steps from the start node" {
  let path = @syntax.NodePath::root()
    .child("definitions", @syntax.ChildIndex::new(0).unwrap())
    .child("body", @syntax.ChildIndex::new(0).unwrap())
  debug_inspect(
    path,
    content=(
      #|{
      #|  steps: [
      #|    { field: "definitions", index: ChildIndex(0) },
      #|    { field: "body", index: ChildIndex(0) },
      #|  ],
      #|}
    ),
  )
  debug_inspect(@syntax.NodePath::root(), content="{ steps: [] }")
}

///|
test "an appended path resolves from the node where the first part ends" {
  let root = root_of("pub fn add(a, b) {\n  a + b\n}\n")
  let to_expression = @syntax.NodePath::from_steps([
    { field: "definitions", index: @syntax.ChildIndex::new(0).unwrap(), },
    { field: "body", index: @syntax.ChildIndex::new(0).unwrap(), },
    { field: "expression", index: @syntax.ChildIndex::new(0).unwrap(), },
  ])
  let to_right = @syntax.NodePath::root().child(
    "right",
    @syntax.ChildIndex::new(0).unwrap(),
  )
  let whole = to_expression.append(to_right)
  @expect.expect_all(s => {
    s
    .expect(whole.to_string())
    .to_equal("definitions[0].body[0].expression[0].right[0]")
    s
    .expect(whole.resolve(root))
    .to_equal(to_expression.resolve(root).bind(n => to_right.resolve(n)))
    s.expect(whole.resolve(root).map(n => n.kind())).to_equal(Some("var"))
  })
}
