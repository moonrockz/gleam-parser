///|
test "law: children are in start order, and in field order among equal starts" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let mut ok = true
      @syntax.walk(root, n => {
        let expected = slot_order(n).map(s => tag(s.2))
        if n.children().map(tag) != expected {
          ok = false
        }
        Continue
      })
      ok
    },
    count=100,
    max_size=10,
    seed=2181,
  )
}

///|
test "law: children_with_fields gives children in order, each with the step that leads to it" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let mut ok = true
      @syntax.walk(root, n => {
        let with_fields = n.children_with_fields()
        if with_fields.map(x => tag(x.1)) != n.children().map(tag) {
          ok = false
        }
        for x in with_fields {
          let (step, child) = x
          match n.field(step.field).get(step.index.to_int()) {
            Some(c) if tag(c) == tag(child) => ()
            _ => ok = false
          }
          if n.field_of(child) != Some(step.field) {
            ok = false
          }
        }
        Continue
      })
      ok
    },
    count=100,
    max_size=10,
    seed=2182,
  )
}

///|
test "law: every node's fields are its kind_table row" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let rows = @syntax.kind_table()
      let mut ok = true
      @syntax.walk(root, n => {
        match rows.search_by(r => r.0 == n.category() && r.1 == n.kind()) {
          Some(i) => if rows[i].2 != n.fields() { ok = false }
          None => ok = false
        }
        Continue
      })
      ok
    },
    count=100,
    max_size=10,
    seed=2183,
  )
}

///|
/// Keys whose JSON value holds a `kind` object but is data, not a child
/// node: publicity and deprecation, the three renamed `kind` fields, the
/// argument names, a type constructor's name, an import alias, a string
/// prefix's right side.
let data_keys : Array[String] = [
  "publicity", "deprecation", "fn_kind", "todo_kind", "names", "name", "as_name",
  "right_side_assignment",
]

///|
/// Whether a JSON value holds, at any depth, an object with a `kind` key:
/// then it is a node (or a wrapper of nodes). An explicit stack.
fn holds_kind(v : Json) -> Bool {
  let stack = [v]
  while stack.pop() is Some(x) {
    match x {
      Object(m) => {
        if m.contains("kind") {
          return true
        }
        for _, inner in m {
          stack.push(inner)
        }
      }
      Array(xs) =>
        for inner in xs {
          stack.push(inner)
        }
      _ => ()
    }
  }
  false
}

///|
/// The JSON of a node's payload, for the nodes with a public encoder.
fn encoded(n : @syntax.NodeRef) -> Json? {
  match n {
    Definition(t) => Some(@ast.encode_definition(t.definition))
    Statement(s) => Some(@ast.encode_statement(s))
    Expr(e) => Some(@ast.encode_expr(e))
    Pattern(p) => Some(@ast.encode_pattern(p))
    TypeAst(t) => Some(@ast.encode_type_ast(t))
    Constant(c) => Some(@ast.encode_constant(c))
    ClauseGuard(g) => Some(@ast.encode_clause_guard(g))
    _ => None
  }
}

///|
/// Every JSON key of a node whose value holds node objects is one of the
/// node's fields: a child the encoder writes is a child every traversal
/// reaches.
test "law: every JSON key that holds nodes is a field of the node" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let mut ok = true
      @syntax.walk(root, n => {
        if encoded(n) is Some(Object(obj)) {
          let fields = n.fields()
          for key, value in obj {
            if key == "kind" || data_keys.contains(key) {
              continue
            }
            if holds_kind(value) && !fields.contains(key) {
              ok = false
            }
          }
        }
        Continue
      })
      ok
    },
    count=100,
    max_size=10,
    seed=2184,
  )
}
