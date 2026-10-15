///|
/// A visitor over the node model: one method per group of node types (see
/// `accept` for which method sees which node). Every method has a default:
/// `visit_*` returns `Continue` and `leave` does nothing, so a visitor
/// implements only what it needs. The visitor's state belongs to the
/// caller; for a traversal that returns a value, see `reduce` and `fold`.
pub(open) trait Visitor {
  /// Every definition: functions, type aliases, custom types, imports and
  /// module constants.
  fn visit_definition(Self, NodeRef) -> Control = _
  /// Statements: expression statements, `let`, `use` and `assert`.
  fn visit_statement(Self, NodeRef) -> Control = _
  /// Expressions, `case`, `fn` and blocks included.
  fn visit_expression(Self, NodeRef) -> Control = _
  /// Patterns, a list's tail pattern included.
  fn visit_pattern(Self, NodeRef) -> Control = _
  /// Type annotations.
  fn visit_type(Self, NodeRef) -> Control = _
  /// Constants (the value of a `const`, a guard's constant).
  fn visit_constant(Self, NodeRef) -> Control = _
  /// Clause guards (`if` in a `case` clause).
  fn visit_guard(Self, NodeRef) -> Control = _
  /// Case clauses.
  fn visit_clause(Self, NodeRef) -> Control = _
  /// Every other node: the module, arguments, record constructors and
  /// their arguments, `use` assignments, call arguments, record update
  /// parts, bit array segments, options and sizes.
  fn visit_other(Self, NodeRef) -> Control = _
  /// Runs after a node's children, as in `walk`.
  fn leave(Self, NodeRef) -> Unit = _
}

///|
impl Visitor with fn visit_definition(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_statement(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_expression(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_pattern(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_type(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_constant(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_guard(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_clause(_self, _node) {
  Continue
}

///|
impl Visitor with fn visit_other(_self, _node) {
  Continue
}

///|
impl Visitor with fn leave(_self, _node) {
  ()
}

///|
fn[V : Visitor] dispatch(visitor : V, n : NodeRef) -> Control {
  match n {
    Definition(_) => visitor.visit_definition(n)
    Statement(_) => visitor.visit_statement(n)
    Expr(_) => visitor.visit_expression(n)
    Pattern(_) | TailPattern(_) => visitor.visit_pattern(n)
    TypeAst(_) => visitor.visit_type(n)
    Constant(_) => visitor.visit_constant(n)
    ClauseGuard(_) => visitor.visit_guard(n)
    Clause(_) => visitor.visit_clause(n)
    _ => visitor.visit_other(n)
  }
}

///|
/// Walk `root` (see `walk`) and call one `visitor` method per node:
/// definitions → `visit_definition`; statements → `visit_statement`;
/// expressions, patterns (tail patterns included), types, constants →
/// `visit_expression`, `visit_pattern`, `visit_type`, `visit_constant`;
/// clause guards → `visit_guard`; clauses → `visit_clause`; every other
/// node → `visit_other`. The method's `Control` steers the walk; `leave`
/// runs after each node's children.
///
/// A visitor needs its own type, so this example is not a doc test (a doc
/// test holds only `test` blocks). The cookbook article "Choose a
/// traversal" has a tested visitor:
/// https://github.com/moonrockz/gleam-parser/blob/main/docs/cookbook/traverse.mbt.md
///
/// ```mbt nocheck
/// struct Names {
///   functions : Array[String]
/// }
///
/// impl @gleam.Visitor for Names with fn visit_definition(self, n) {
///   match n {
///     Definition({ definition: Function(f), .. }) =>
///       self.functions.push(f.name.map(x => x.name).unwrap_or("?"))
///     _ => ()
///   }
///   Continue
/// }
///
/// test {
///   let root = @gleam.NodeRef::of_result(
///     @gleam.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let names : Names = { functions: [], }
///   @gleam.accept(root, names)
///   debug_inspect(names.functions, content="[\"add\"]")
/// }
/// ```
pub fn[V : Visitor] accept(root : NodeRef, visitor : V) -> Unit {
  walk(root, n => dispatch(visitor, n), leave=n => visitor.leave(n))
}
