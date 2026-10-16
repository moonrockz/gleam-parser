# Choose a traversal

The syntax tree is a read-only node model over the AST. `NodeRef::of_result`
gives the root of a parse; `category()` and `kind()` name a node with the
JSON vocabulary of `docs/ast-json.md`, `span()` is its byte span, and
`children()`, `field(name)` and `children_with_fields()` go down. Seven
traversals share that order; each uses an explicit stack, so no module is
too deep.

`walk` enters every node in pre-order; `enter` returns `Continue`,
`SkipChildren` or `Stop`, and `leave` runs after a node's children:

```mbt check
///|
test "tr: walk" {
  let root = @gleam.NodeRef::of_result(
    @gleam.parse_text("pub fn f(x) {\n  [x]\n}\n"),
  )
  let log = []
  @gleam.walk(
    root,
    n => {
      log.push("+" + n.kind())
      if n.category() == "arg" {
        SkipChildren
      } else {
        Continue
      }
    },
    leave=n => log.push("-" + n.kind()),
  )
  @expect.expect(log.join(" ")).to_equal(
    "+module +function +arg -arg +expression +list +var -var -list -expression -function -module",
  )
}
```

`fold` threads a value through the same walk, top down and back up:

```mbt check
///|
test "tr: fold counts expressions and the deepest nesting" {
  let root = @gleam.NodeRef::of_result(
    @gleam.parse_text("pub fn f() {\n  [[1]]\n}\n"),
  )
  let (count, _, deepest) = @gleam.fold(
    root,
    (0, 0, 0),
    (acc, n) => {
      let (count, depth, deepest) = acc
      let count = count + (if n.category() == "expression" { 1 } else { 0 })
      let depth = depth + 1
      let deepest = if depth > deepest { depth } else { deepest }
      ((count, depth, deepest), Continue)
    },
    leave=(acc, _) => (acc.0, acc.1 - 1, acc.2),
  )
  @expect.expect_all(e => {
    e.expect(count).to_equal(3)
    e.expect(deepest).to_equal(6)
  })
}
```

`reduce` is the visitor that returns a value: each node gets its
children's results, bottom up, and the root's result is the answer. A
MoonBit trait cannot carry the result type, so the value lives in the
closure:

```mbt check
///|
test "tr: reduce builds an outline" {
  let root = @gleam.NodeRef::of_result(
    @gleam.parse_text("pub fn f() {\n  [[1]]\n}\n"),
  )
  let outline = @gleam.reduce(root, (n, kids) => {
    if kids.length() == 0 {
      n.kind()
    } else {
      n.kind() + "(" + kids.to_owned().join(",") + ")"
    }
  })
  @expect.expect(outline).to_equal(
    "module(function(expression(list(list(int)))))",
  )
}
```

A `Visitor` is a type with one method per node group; every method has a
default, and the visitor's state belongs to you:

```mbt check
///|
struct TrNames {
  functions : Array[String]
  mut args : Int32
}

///|
impl @gleam.Visitor for TrNames with fn visit_definition(self, n) {
  match n {
    Definition({ definition: Function(f), .. }) =>
      self.functions.push(f.name.map(x => x.name).unwrap_or("?"))
    _ => ()
  }
  Continue
}

///|
impl @gleam.Visitor for TrNames with fn visit_other(self, n) {
  if n.category() == "arg" {
    self.args += 1
  }
  Continue
}

///|
test "tr: a visitor collects names" {
  let root = @gleam.NodeRef::of_result(
    @gleam.parse_text("pub fn add(a, b) {\n  a + b\n}\n\nfn z() {\n  0\n}\n"),
  )
  let names : TrNames = { functions: [], args: 0, }
  @gleam.accept(root, names)
  @expect.expect_all(e => {
    e.expect(names.functions).to_equal(["add", "z"])
    e.expect(names.args).to_equal(2)
  })
}
```

`EventReader` pulls `Enter` and `Leave` events one at a time; an `Enter`
carries only what a streaming parser knows (category, kind, field, start,
depth, path), and `skip_children` right after an `Enter` skips that node:

```mbt check
///|
test "tr: pull events" {
  let root = @gleam.NodeRef::of_result(
    @gleam.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
  )
  let reader = @gleam.EventReader(root)
  let args = []
  for event in reader.iter() {
    if event is Enter(e) {
      if e.category == "expression" {
        reader.skip_children()
      }
      if e.category == "arg" {
        args.push(e.path.to_string())
      }
    }
  }
  @expect.expect(args).to_equal([
    "definitions[0].arguments[0]", "definitions[0].arguments[1]",
  ])
}
```

`push_events` pushes the same events to a `Handler`; a streaming parser
can be an `EventSource` too:

```mbt check
///|
struct TrPaths {
  found : Array[String]
}

///|
impl @gleam.Handler for TrPaths with fn on_enter(self, e) {
  if e.kind == "var" {
    self.found.push(e.path.to_string())
  }
  Continue
}

///|
test "tr: push events" {
  let root = @gleam.NodeRef::of_result(
    @gleam.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
  )
  let paths : TrPaths = { found: [], }
  @gleam.push_events(@gleam.EventReader(root), paths)
  @expect.expect(paths.found).to_equal([
    "definitions[0].body[0].expression[0].left[0]", "definitions[0].body[0].expression[0].right[0]",
  ])
}
```

A `TreeCursor` moves where you tell it (tree-sitter style), and a `Tree`
answers questions about position: the node at a byte offset, its parent,
its path:

```mbt check
///|
test "tr: a cursor and a tree" {
  let text = "pub fn add(a, b) {\n  a + b\n}\n"
  let tree = @gleam.Tree(@gleam.parse_text(text))
  // Byte 23 is the `+`.
  let cursor = @gleam.TreeCursor(tree.root())
  @expect.expect_all(e => {
    e
    .expect(cursor.goto_node_at(@gleam.ByteOffset::from_int(23).unwrap()))
    .to_be_true()
    e.expect(cursor.node().kind()).to_equal("bin_op")
    e
    .expect(cursor.path().to_string())
    .to_equal("definitions[0].body[0].expression[0]")
    e.expect(cursor.goto_first_child()).to_be_true()
    e.expect(cursor.field_name()).to_equal(Some("left"))
    let plus = tree.node_at(@gleam.ByteOffset::from_int(23).unwrap()).unwrap()
    e.expect(tree.parent(plus).map(n => n.kind())).to_equal(Some("expression"))
    e
    .expect(tree.node_path(plus).map(p => p.to_string()))
    .to_equal(Some("definitions[0].body[0].expression[0]"))
    e
    .expect(tree.tokens_in(plus.span()).map(t => t.lexeme))
    .to_equal(["a", "+", "b"])
  })
}
```

A path mirrors the AST JSON (`definitions[0].body[0].expression[0]`),
with three differences: a field that holds one node gets index 0, the
`definition` wrapper of a targeted definition is not a step, and a
clause's `alternative_patterns` (a list of lists in the JSON) is flattened
to one index.
