///|
/// Collects function names and counts the arguments it meets.
struct Names {
  functions : Array[String]
  mut args : Int32
}

///|
impl @syntax.Visitor for Names with fn visit_definition(self, n) {
  match n {
    Definition({ definition: Function(f), .. }) =>
      self.functions.push(f.name.map(x => x.name).unwrap_or("?"))
    _ => ()
  }
  Continue
}

///|
impl @syntax.Visitor for Names with fn visit_other(self, n) {
  if n.category() == "arg" {
    self.args += 1
  }
  Continue
}

///|
test "accept dispatches by category and keeps the visitor's state" {
  let root = root_of("pub fn add(a, b) {\n  a + b\n}\n\nfn z() {\n  0\n}\n")
  let names : Names = { functions: [], args: 0, }
  @syntax.accept(root, names)
  @expect.expect_all(e => {
    e.expect(names.functions).to_equal(["add", "z"])
    e.expect(names.args).to_equal(2)
  })
}

///|
/// Skips every expression's children and logs what it leaves.
struct Shallow {
  seen : Array[String]
  left : Array[String]
}

///|
impl @syntax.Visitor for Shallow with fn visit_expression(self, n) {
  self.seen.push(n.kind())
  SkipChildren
}

///|
impl @syntax.Visitor for Shallow with fn leave(self, n) {
  self.left.push(n.kind())
}

///|
test "a visitor's Control steers the walk and leave runs in post-order" {
  let root = root_of("pub fn f(x) {\n  f(x)\n}\n")
  let v : Shallow = { seen: [], left: [], }
  @syntax.accept(root, v)
  @expect.expect_all(e => {
    e.expect(v.seen).to_equal(["call"])
    e
    .expect(v.left)
    .to_equal(["arg", "call", "expression", "function", "module"])
  })
}
