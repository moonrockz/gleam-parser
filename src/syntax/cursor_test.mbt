///|
/// Where a cursor is: category/kind, field and depth.
fn at(c : @syntax.TreeCursor) -> String {
  let f = match c.field_name() {
    Some(f) => f
    None => "-"
  }
  "\{c.node().category()}/\{c.node().kind()} \{f} \{c.depth()}"
}

///|
let two_defs : String = "pub fn f(x) {\n  x\n}\n\nconst y = 1\n"

///|
test "a cursor starts at its node with depth 0 and no field" {
  let c = @syntax.TreeCursor(root_of(two_defs))
  @expect.expect(at(c)).to_equal("module/module - 0")
}

///|
test "goto_first_child, goto_next_sibling and goto_parent move and report fields" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(root_of(two_defs))
    let seen = []
    s.expect(c.goto_first_child()).to_equal(true)
    seen.push(at(c))
    s.expect(c.goto_first_child()).to_equal(true)
    seen.push(at(c))
    s.expect(c.goto_next_sibling()).to_equal(true)
    seen.push(at(c))
    s.expect(c.goto_parent()).to_equal(true)
    seen.push(at(c))
    s.expect(c.goto_next_sibling()).to_equal(true)
    seen.push(at(c))
    s
    .expect(seen)
    .to_equal([
      "definition/function definitions 1", "arg/arg arguments 2", "statement/expression body 2",
      "definition/function definitions 1", "definition/module_constant definitions 1",
    ])
  })
}

///|
test "goto_last_child and goto_previous_sibling" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(root_of(two_defs))
    s.expect(c.goto_last_child()).to_equal(true)
    s.expect(at(c)).to_equal("definition/module_constant definitions 1")
    s.expect(c.goto_previous_sibling()).to_equal(true)
    s.expect(at(c)).to_equal("definition/function definitions 1")
  })
}

///|
test "a move that has nowhere to go returns false and leaves the cursor in place" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(root_of(two_defs))
    s.expect(c.goto_parent()).to_equal(false)
    s.expect(c.goto_next_sibling()).to_equal(false)
    s.expect(c.goto_previous_sibling()).to_equal(false)
    s.expect(at(c)).to_equal("module/module - 0")
    ignore(c.goto_first_child())
    s.expect(c.goto_previous_sibling()).to_equal(false)
    ignore(c.goto_first_child())
    // An argument without an annotation is a leaf.
    s.expect(c.goto_first_child()).to_equal(false)
    s.expect(c.goto_last_child()).to_equal(false)
    s
    .expect(c.goto_first_child_for(@span.ByteOffset::from_int(9).unwrap()))
    .to_equal(false)
    s.expect(at(c)).to_equal("arg/arg arguments 2")
  })
}

///|
test "goto_first_child_for picks the first child that contains or follows the offset" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(root_of(two_defs))
    // Inside the function head.
    s
    .expect(c.goto_first_child_for(@span.ByteOffset::from_int(5).unwrap()))
    .to_equal(true)
    s.expect(at(c)).to_equal("definition/function definitions 1")
    ignore(c.goto_parent())
    // On the blank line between the definitions (byte 20).
    s
    .expect(c.goto_first_child_for(@span.ByteOffset::from_int(20).unwrap()))
    .to_equal(true)
    s.expect(at(c)).to_equal("definition/module_constant definitions 1")
    ignore(c.goto_parent())
    // After the last child.
    s
    .expect(c.goto_first_child_for(@span.ByteOffset::from_int(100).unwrap()))
    .to_equal(false)
    s.expect(at(c)).to_equal("module/module - 0")
  })
}

///|
test "reset moves the cursor to a new start node" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(root_of(two_defs))
    ignore(c.goto_first_child())
    let function = c.node()
    ignore(c.goto_first_child())
    c.reset(function)
    s.expect(at(c)).to_equal("definition/function - 0")
    s.expect(c.goto_parent()).to_equal(false)
  })
}

///|
test "a copy moves independently of its cursor" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(root_of(two_defs))
    ignore(c.goto_first_child())
    let d = c.copy()
    ignore(d.goto_next_sibling())
    ignore(d.goto_first_child())
    s.expect(at(c)).to_equal("definition/function definitions 1")
    s.expect(at(d)).to_equal("constant/int value 2")
    ignore(c.goto_parent())
    s.expect(at(d)).to_equal("constant/int value 2")
  })
}

///|
/// The tags a full navigation (first child, next sibling, parent) enters.
/// It fails unless the navigation ends back at the start node.
fn navigate(root : @syntax.NodeRef) -> Array[String] raise {
  let c = @syntax.TreeCursor(root)
  let out = [tag(c.node())]
  while true {
    if c.goto_first_child() {
      out.push(tag(c.node()))
      continue
    }
    while !c.goto_next_sibling() {
      if !c.goto_parent() {
        if c.depth() != @syntax.NodeDepth::from_int(0).unwrap() ||
          tag(c.node()) != tag(root) {
          fail("the navigation did not end at its start node")
        }
        return out
      }
    }
    out.push(tag(c.node()))
  }
  out
}

///|
test "a full cursor navigation enters children() pre-order" {
  let root = root_of(body_source)
  @expect.expect(navigate(root)).to_equal(preorder(root))
}

///|
test "a cursor handles 3000 nested lists" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(deep_list(3000))
    while c.goto_first_child() {

    }
    s.expect(at(c)).to_equal("expression/int elements 3000")
    while c.goto_parent() {

    }
    s.expect(c.depth()).to_equal(@syntax.NodeDepth::from_int(0).unwrap())
    s.expect(navigate(deep_list(3000)).length()).to_equal(3001)
  })
}

///|
test "a cursor reports the path of its node" {
  @expect.expect_all(s => {
    let c = @syntax.TreeCursor(root_of(two_defs))
    s.expect(c.path().to_string()).to_equal("")
    ignore(c.goto_first_child())
    ignore(c.goto_last_child())
    ignore(c.goto_first_child())
    s
    .expect(c.path().to_string())
    .to_equal("definitions[0].body[0].expression[0]")
    s.expect(c.path().depth()).to_equal(c.depth())
  })
}

///|
test "among children with equal spans goto_first_child_for picks the first" {
  let sp = @span.SrcSpan::from_ints(2, 4).unwrap()
  let first : @ast.Expr = Int(
    location=sp,
    value="0",
    int_value=BigInt::from_int(0),
  )
  let second : @ast.Expr = Int(
    location=sp,
    value="1",
    int_value=BigInt::from_int(1),
  )
  let list = @syntax.NodeRef::Expr(
    List(
      location=@span.SrcSpan::from_ints(0, 6).unwrap(),
      elements=[first, second][:],
      tail=None,
    ),
  )
  let c = @syntax.TreeCursor(list)
  @expect.expect_all(s => {
    s
    .expect(c.goto_first_child_for(@span.ByteOffset::from_int(2).unwrap()))
    .to_be_true()
    s.expect(c.node()).to_equal(@syntax.NodeRef::Expr(first))
  })
}

///|
test "goto_node_at moves below the current node only, and stays when the node does not contain p" {
  let tree = tree_of("pub fn add(a, b) {\n  a + b\n}\n")
  let cursor = @syntax.TreeCursor(tree.root())
  @expect.expect_all(s => {
    // The `+` in `a + b` is byte 23.
    s
    .expect(cursor.goto_node_at(@span.ByteOffset::from_int(23).unwrap()))
    .to_be_true()
    s.expect(cursor.node().kind()).to_equal("bin_op")
    s
    .expect(cursor.path().to_string())
    .to_equal("definitions[0].body[0].expression[0]")
    // From there, `pub` is outside: the cursor stays.
    s
    .expect(cursor.goto_node_at(@span.ByteOffset::from_int(0).unwrap()))
    .to_be_false()
    s.expect(cursor.node().kind()).to_equal("bin_op")
    // `b` is inside: the cursor goes down, and goto_parent goes back up.
    s
    .expect(cursor.goto_node_at(@span.ByteOffset::from_int(25).unwrap()))
    .to_be_true()
    s.expect(cursor.field_name()).to_equal(Some("right"))
    s.expect(cursor.goto_parent()).to_be_true()
    s.expect(cursor.node().kind()).to_equal("bin_op")
  })
}
