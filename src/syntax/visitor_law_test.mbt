///|
/// Records method and node, and returns the policy's k-th decision.
struct PolicyVisitor {
  policy : Policy
  events : Array[String]
  mut k : Int32
}

///|
fn PolicyVisitor::on(
  self : PolicyVisitor,
  m : String,
  n : @syntax.NodeRef,
) -> @syntax.Control {
  self.events.push("+" + m + " " + tag(n))
  self.k = self.k + 1
  decide(self.policy, self.k - 1)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_definition(self, n) {
  self.on("definition", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_statement(self, n) {
  self.on("statement", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_expression(self, n) {
  self.on("expression", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_pattern(self, n) {
  self.on("pattern", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_type(self, n) {
  self.on("type", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_constant(self, n) {
  self.on("constant", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_guard(self, n) {
  self.on("guard", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_clause(self, n) {
  self.on("clause", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn visit_other(self, n) {
  self.on("other", n)
}

///|
impl @syntax.Visitor for PolicyVisitor with fn leave(self, n) {
  self.events.push("-" + tag(n))
}

///|
fn accept_events(root : @syntax.NodeRef, p : Policy) -> Array[String] {
  let v : PolicyVisitor = { policy: p, events: [], k: 0, }
  @syntax.accept(root, v)
  v.events
}

///|
/// The visitor method a node goes to: the dispatch table.
fn expected_method(n : @syntax.NodeRef) -> String {
  match n {
    Definition(_) => "definition"
    Statement(_) => "statement"
    Expr(_) => "expression"
    Pattern(_) | TailPattern(_) => "pattern"
    TypeAst(_) => "type"
    Constant(_) => "constant"
    ClauseGuard(_) => "guard"
    Clause(_) => "clause"
    _ => "other"
  }
}

///|
/// What accept must record: walk's events with the dispatch table's method.
fn dispatch_events(root : @syntax.NodeRef, p : Policy) -> Array[String] {
  let expected = []
  let mut k = 0
  @syntax.walk(
    root,
    n => {
      expected.push("+" + expected_method(n) + " " + tag(n))
      k = k + 1
      decide(p, k - 1)
    },
    leave=n => expected.push("-" + tag(n)),
  )
  expected
}

///|
test "law: accept is walk with the dispatch table" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Policy)) => {
      let (m, p) = input
      let root = gleam_root(m)
      accept_events(root, p) == dispatch_events(root, p)
    },
    count=100,
    max_size=10,
    seed=2111,
  )
}

///|
/// A visitor with only `leave`, logging the nodes it leaves.
struct LeaveLog {
  left : Array[String]
}

///|
impl @syntax.Visitor for LeaveLog with fn leave(self, n) {
  self.left.push(tag(n))
}

///|
test "law: a visitor with only leave leaves every node in walk's post-order" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let v : LeaveLog = { left: [], }
      @syntax.accept(root, v)
      let expected = []
      @syntax.walk(root, _ => Continue, leave=n => expected.push(tag(n)))
      v.left == expected
    },
    count=100,
    max_size=10,
    seed=2112,
  )
}

///|
test "law: an accept inside a callback gives its standalone result" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Policy, Policy)) => {
      let (m, p, q) = input
      let root = gleam_root(m)
      let outer : PolicyVisitor = { policy: p, events: [], k: 0, }
      let mut ok = true
      @syntax.accept(root, outer)
      @syntax.walk(
        root,
        n => {
          if accept_events(n, q) != dispatch_events(n, q) {
            ok = false
          }
          Continue
        },
        leave=n => {
          if accept_events(n, q) != dispatch_events(n, q) {
            ok = false
          }
        },
      )
      ok && outer.events == dispatch_events(root, p)
    },
    count=50,
    max_size=8,
    seed=2113,
  )
}

///|
/// Runs a fresh inner accept at every node it enters and leaves, and
/// forwards each call to an inner PolicyVisitor.
struct NestingVisitor {
  inner : PolicyVisitor
  q : Policy
  mut ok : Bool
}

///|
fn NestingVisitor::check(self : NestingVisitor, n : @syntax.NodeRef) -> Unit {
  if accept_events(n, self.q) != dispatch_events(n, self.q) {
    self.ok = false
  }
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_definition(self, n) {
  self.check(n)
  self.inner.on("definition", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_statement(self, n) {
  self.check(n)
  self.inner.on("statement", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_expression(self, n) {
  self.check(n)
  self.inner.on("expression", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_pattern(self, n) {
  self.check(n)
  self.inner.on("pattern", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_type(self, n) {
  self.check(n)
  self.inner.on("type", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_constant(self, n) {
  self.check(n)
  self.inner.on("constant", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_guard(self, n) {
  self.check(n)
  self.inner.on("guard", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_clause(self, n) {
  self.check(n)
  self.inner.on("clause", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn visit_other(self, n) {
  self.check(n)
  self.inner.on("other", n)
}

///|
impl @syntax.Visitor for NestingVisitor with fn leave(self, n) {
  self.check(n)
  self.inner.events.push("-" + tag(n))
}

///|
test "law: an accept inside an accept callback leaves the outer accept unchanged" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Policy, Policy)) => {
      let (m, p, q) = input
      let root = gleam_root(m)
      let v : NestingVisitor = {
        inner: { policy: p, events: [], k: 0, },
        q,
        ok: true,
      }
      @syntax.accept(root, v)
      v.ok && v.inner.events == dispatch_events(root, p)
    },
    count=50,
    max_size=8,
    seed=2114,
  )
}
