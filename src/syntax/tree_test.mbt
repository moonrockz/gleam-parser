///|
fn tree_of(text : String) -> @syntax.Tree {
  @syntax.Tree::new(@parser.parse_text(text))
}

///|
/// Every node with its parent, in pre-order, from a walk.
fn all_nodes(
  root : @syntax.NodeRef,
) -> Array[(@syntax.NodeRef, @syntax.NodeRef?)] {
  let out = []
  let open : Array[@syntax.NodeRef] = []
  @syntax.walk(
    root,
    n => {
      out.push((n, open.last()))
      open.push(n)
      Continue
    },
    leave=_ => ignore(open.pop()),
  )
  out
}

///|
let body_source : String = "pub fn add(a, b) {\n  let c = a\n  case c {\n    1 -> [c, b]\n    _ -> c + b\n  }\n}\n"

///|
test "every node knows its parent, ancestors and path" {
  @expect.expect_all(s => {
    let tree = tree_of(body_source)
    let root = tree.root()
    s.expect(tree.parent(root)).to_equal(None)
    for entry in all_nodes(root) {
      let (node, parent) = entry
      s.expect(tree.parent(node)).to_equal(parent)
      let ancestors = tree.ancestors(node)
      if parent is Some(_) {
        s.expect(ancestors.last()).to_equal(Some(root))
        s.expect(ancestors.get(0)).to_equal(parent)
      } else {
        s.expect(ancestors).to_equal([])
      }
      let path = tree.path(node)
      s.expect(path.get(0)).to_equal(Some(root))
      s.expect(path.last()).to_equal(Some(node))
      s.expect(path.length()).to_equal(ancestors.length() + 1)
    }
  })
}

///|
test "node_path names the way from the root and step gives the last step" {
  let tree = tree_of("pub fn add(a, b) {\n  a + b\n}\n")
  let b = tree.root().field("definitions")[0].field("body")[0].field(
      "expression",
    )[0].field("right")[0]
  @expect.expect_all(s => {
    s
    .expect(tree.node_path(b).map(p => p.to_string()))
    .to_equal(Some("definitions[0].body[0].expression[0].right[0]"))
    s
    .expect(tree.node_path(b).bind(p => p.resolve(tree.root())))
    .to_equal(Some(b))
    s
    .expect(tree.step(b))
    .to_equal(
      Some({ field: "right", index: @syntax.ChildIndex::new(0).unwrap(), }),
    )
    s.expect(tree.field_of(b)).to_equal(Some("right"))
    s.expect(tree.step(tree.root())).to_equal(None)
    s
    .expect(tree.ancestors(b).map(n => n.kind()))
    .to_equal(["bin_op", "expression", "function", "module"])
    s
    .expect(tree.node_path(tree.root()).map(p => p.depth()))
    .to_equal(Some(@syntax.NodeDepth::new(0).unwrap()))
    // A node of another parse: equal in value, so it is found by structure.
    let other = @syntax.NodeRef::of_result(
        @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
      ).field("definitions")[0]
    s
    .expect(tree.node_path(other).map(p => p.to_string()))
    .to_equal(Some("definitions[0]"))
    // A node in no tree at all.
    let made_up = @syntax.NodeRef::Expr(
      @parser.parse_expression_text("nowhere"),
    )
    s.expect(tree.node_path(made_up)).to_equal(None)
  })
}

///|
test "node_at inside a pipeline's first expression gives that expression under the pipeline" {
  let tree = tree_of("fn f() {\n  a |> g |> h\n}\n")
  // `a` is at byte 11.
  guard tree.node_at(@span.ByteOffset::new(11).unwrap()) is Some(a) else {
    fail("nothing at 11")
  }
  @expect.expect_all(s => {
    s.expect(a.kind()).to_equal("var")
    s.expect(tree.parent(a).map(n => n.kind())).to_equal(Some("pipeline"))
    s
    .expect(tree.node_at(@span.ByteOffset::new(13).unwrap()).map(n => n.kind()))
    .to_equal(Some("pipeline"))
  })
}

///|
test "node_at at the start of `p as x` gives the inner pattern under the assign" {
  let tree = tree_of("fn f(x) {\n  case x {\n    [y] as z -> 1\n  }\n}\n")
  // `[` of `[y] as z` is at byte 25.
  guard tree.node_at(@span.ByteOffset::new(25).unwrap()) is Some(list) else {
    fail("nothing at 25")
  }
  @expect.expect_all(s => {
    s.expect("\{list.category()}/\{list.kind()}").to_equal("pattern/list")
    s.expect(tree.parent(list).map(n => n.kind())).to_equal(Some("assign"))
    // The name `z` belongs to the assign, not to the list.
    s
    .expect(tree.node_at(@span.ByteOffset::new(32).unwrap()).map(n => n.kind()))
    .to_equal(Some("assign"))
  })
}

///|
test "node_at inside a function body finds the statement through the head-only location" {
  let tree = tree_of(body_source)
  // `let c = a` starts at byte 21.
  guard tree.node_at(@span.ByteOffset::new(21).unwrap()) is Some(stmt) else {
    fail("nothing at 21")
  }
  @expect.expect_all(s => {
    s
    .expect("\{stmt.category()}/\{stmt.kind()}")
    .to_equal("statement/assignment")
    s.expect(tree.parent(stmt).map(n => n.kind())).to_equal(Some("function"))
    // Between statements: the function.
    s
    .expect(tree.node_at(@span.ByteOffset::new(30).unwrap()).map(n => n.kind()))
    .to_equal(Some("function"))
    // Outside the text.
    s.expect(tree.node_at(@span.ByteOffset::new(1000).unwrap())).to_equal(None)
    s.expect(@span.ByteOffset::new(-1)).to_equal(None)
  })
}

///|
test "a skipped definition keeps the tree of the others, and tokens_in gives whole tokens" {
  let text = "fn broken( {\n  1\n}\n\npub fn ok(a) {\n  a\n}\n"
  let result = @parser.parse_text(text)
  let tree = @syntax.Tree::new(result)
  let defs = tree.root().field("definitions")
  @expect.expect_all(s => {
    s.expect(result.has_errors()).to_be_true()
    s.expect(defs.map(d => d.kind())).to_equal(["function"])
    s
    .expect(tree.tokens_in(defs[0].span()).map(t => t.lexeme))
    .to_equal(["pub", "fn", "ok", "(", "a", ")", "{", "a", "}"])
    // A span that cuts the first token keeps only the whole ones.
    let span = defs[0].span()
    s
    .expect(
      tree
      .tokens_in(
        @span.SrcSpan::between(span.start.shift(1).unwrap(), span.end).unwrap(),
      )
      .map(t => t.lexeme),
    )
    .to_equal(["fn", "ok", "(", "a", ")", "{", "a", "}"])
  })
}
