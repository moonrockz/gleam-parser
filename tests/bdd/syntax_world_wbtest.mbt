///|
/// Scenario state for `tests/features/syntax.feature`.
struct SyntaxWorld {
  /// category → kinds, from docs/ast-json.md.
  mut doc_kinds : Array[(String, Array[String])]
  mut root : @gleam.NodeRef?
  mut orders : Array[(String, Array[String])]
}

///|
fn SyntaxWorld::new() -> SyntaxWorld {
  { doc_kinds: [], root: None, orders: [], }
}

///|
/// The categories the schema lists under "## Kinds", by their MoonBit type
/// name as the document writes it.
fn category_of(type_name : String) -> String? {
  match type_name {
    "Statement" => Some("statement")
    "Expr" => Some("expression")
    "Pattern" => Some("pattern")
    "Constant" => Some("constant")
    "TypeAst" => Some("type")
    "ClauseGuard" => Some("clause_guard")
    "BitArraySize" => Some("bit_array_size")
    "BitArrayOption" => Some("bit_array_option")
    _ => None
  }
}

///|
/// The kinds a "- `Type`: `a`, `b` (...)" bullet lists: every backtick
/// word after the first colon up to the first `;` (the second type of a
/// shared bullet) or the end of the line.
fn kinds_in(line : String) -> Array[String] {
  guard line.find(": ") is Some(colon) else { return [] }
  let rest = line[colon + 2:].to_owned()
  let rest = match rest.find("; ") {
    Some(semi) => rest[:semi].to_owned()
    None => rest
  }
  let out = []
  let mut open : Int32? = None
  for i, c in rest {
    if c == '`' {
      match open {
        None => open = Some(i + 1)
        Some(start) => {
          let word = rest[start:i].to_owned()
          // A kind is one snake_case word; `{"size":<BitArraySize>}` is not.
          if !word.contains("{") && !word.contains(" ") {
            out.push(word)
          }
          open = None
        }
      }
    }
  }
  out
}

///|
/// Walks the module seven ways and records each pre-order of kinds.
fn traversals(root : @gleam.NodeRef) -> Array[(String, Array[String])] {
  let out = []
  let walked = []
  @gleam.walk(root, n => {
    walked.push(n.kind())
    Continue
  })
  out.push(("walk", walked))
  let folded = @gleam.fold(root, [], (acc, n) => {
    acc.push(n.kind())
    (acc, Continue)
  })
  out.push(("fold", folded))
  let reduced : Array[String] = @gleam.reduce(root, (n, kids) => {
    let list : Array[String] = [n.kind()]
    for k in kids {
      list.append(k)
    }
    list
  })
  out.push(("reduce", reduced))
  let visited : Recorder = { kinds: [], }
  @gleam.accept(root, visited)
  out.push(("visitor", visited.kinds))
  let read = []
  let reader = @gleam.EventReader::new(root)
  for e in reader.iter() {
    if e is Enter(e) {
      read.push(e.kind)
    }
  }
  out.push(("event reader", read))
  let pushed : Recorder = { kinds: [], }
  @gleam.push_events(@gleam.EventReader::new(root), pushed)
  out.push(("push events", pushed.kinds))
  let c = @gleam.TreeCursor::new(root)
  let cursor = [c.node().kind()]
  let mut going = true
  while going {
    if c.goto_first_child() {
      cursor.push(c.node().kind())
      continue
    }
    while !c.goto_next_sibling() {
      if !c.goto_parent() {
        going = false
        break
      }
    }
    if going {
      cursor.push(c.node().kind())
    }
  }
  out.push(("cursor", cursor))
  out
}

///|
/// Records every kind it visits, as a visitor and as a handler.
struct Recorder {
  kinds : Array[String]
}

///|
impl @gleam.Visitor for Recorder with fn visit_definition(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_statement(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_expression(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_pattern(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_type(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_constant(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_guard(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_clause(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Visitor for Recorder with fn visit_other(self, n) {
  self.kinds.push(n.kind())
  Continue
}

///|
impl @gleam.Handler for Recorder with fn on_enter(self, e) {
  self.kinds.push(e.kind)
  Continue
}

///|
impl @moonspec.World for SyntaxWorld with fn configure(self, setup) {
  setup.when("I read the kinds of the AST JSON schema", fn(_ctx) raise {
    let text = @fs.read_file_to_string("../docs/ast-json.md")
    let found = []
    for line in text.split("\n") {
      let line = line.to_owned()
      if line.has_prefix("- `") {
        let after = line[3:].to_owned()
        let type_name = after[:after.find("`").unwrap_or(0)].to_owned()
        if category_of(type_name) is Some(category) {
          found.push((category, kinds_in(line)))
        }
      }
    }
    self.doc_kinds = found
  })
  setup.then(
    "every expression, pattern, constant, type, clause guard, bit array size and bit array option kind has one row in the kind table",
    fn(_ctx) raise {
      let rows = @gleam.kind_table()
      @expect.expect_all(e => {
        e.expect(self.doc_kinds.length()).to_equal(8)
        for entry in self.doc_kinds {
          let (category, kinds) = entry
          e.expect((category, kinds.length() > 0)).to_equal((category, true))
          let table = rows.filter(r => r.0 == category).map(r => r.1)
          e.expect((category, table)).to_equal((category, kinds))
        }
      })
    },
  )
  setup.then("every row's fields are JSON keys of the recorded fixtures", fn(
    _ctx,
  ) raise {
    let sb = StringBuilder()
    for name in @fs.read_dir("fixtures/ast") {
      if name.has_suffix(".json") {
        sb.write_string(@fs.read_file_to_string("fixtures/ast/\{name}"))
      }
    }
    let all = sb.to_string()
    @expect.expect_all(e => {
      for row in @gleam.kind_table() {
        for field in row.2 {
          e
          .expect((row.0, row.1, field, all.contains("\"\{field}\":")))
          .to_equal((row.0, row.1, field, true))
        }
      }
    })
  })
  setup.given1("the Gleam module {string}", fn(text : String) {
    self.root = Some(
      @gleam.NodeRef::of_result(@gleam.parse_text(unescape(text))),
    )
  })
  setup.when(
    "I traverse it with walk, fold, reduce, a visitor, the event reader, push events and the cursor",
    fn(_ctx) raise {
      guard self.root is Some(root) else { fail("no module") }
      self.orders = traversals(root)
    },
  )
  setup.then1("every traversal gives the same pre-order {string}", fn(
    expected : String,
  ) raise {
    @expect.expect_all(e => {
      e.expect(self.orders.length()).to_equal(7)
      for entry in self.orders {
        e.expect((entry.0, entry.1.join(" "))).to_equal((entry.0, expected))
      }
    })
  })
}

///|
async test "syntax feature" {
  @moonspec.run_or_fail(
    SyntaxWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/syntax.feature"),
    ]),
  )
  |> ignore
}
