///|
test "reduce gives every node its children's results, bottom up" {
  let root = root_of("pub fn f() {\n  [[1]]\n}\n")
  // The height of the tree: a leaf is 1.
  let height = @syntax.reduce(root, (_, kids) => {
    let mut best = 0
    for k in kids {
      if k > best {
        best = k
      }
    }
    1 + best
  })
  // A printed outline: kind(children).
  let outline = @syntax.reduce(root, (n, kids) => {
    if kids.length() == 0 {
      n.kind()
    } else {
      n.kind() + "(" + kids.to_owned().join(",") + ")"
    }
  })
  @expect.expect_all(e => {
    e.expect(height).to_equal(6)
    e.expect(outline).to_equal("module(function(expression(list(list(int)))))")
  })
}

///|
test "reduce_with_fields names each child's field and index" {
  let sum = @syntax.NodeRef::Expr(@parser.parse_expression_text("a + b"))
  let shown = @syntax.reduce_with_fields(sum, (n, kids) => {
    let parts = kids.to_owned().map(k => "\{k.0.field}[\{k.0.index}]=\{k.1}")
    if parts.length() == 0 {
      n.kind()
    } else {
      n.kind() + "{" + parts.join(" ") + "}"
    }
  })
  @expect.expect(shown).to_equal("bin_op{left[0]=var right[0]=var}")
}

///|
test "reduce over 3000 nested lists runs on every target" {
  let count = @syntax.reduce(deep_list(3000), (_, kids) => {
    let mut n = 1
    for k in kids {
      n += k
    }
    n
  })
  @expect.expect(count).to_equal(3001)
}
