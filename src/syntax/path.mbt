///|
/// One step of a node path: a field of the parent and the node's index in
/// that field (0 for a field that holds one node).
pub(all) struct PathStep {
  field : String
  index : Int32
} derive(Eq, Hash, Debug)

///|
/// Where a node sits below a start node: the steps from the start node,
/// each a field and an index, like a path into the AST JSON
/// (`definitions[0].body[1].value[0]`). A path is immutable; a child's
/// path shares its parent's steps. Get one from `Tree::node_path`, an
/// `EnterEvent` or `TreeCursor::path`.
///
/// ```mbt check
/// test {
///   let root = @syntax.NodeRef::of_result(
///     @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let path = @syntax.NodePath::root()
///     .child("definitions", 0)
///     .child("body", 0)
///     .child("expression", 0)
///     .child("right", 0)
///   inspect(path, content="definitions[0].body[0].expression[0].right[0]")
///   inspect(path.depth(), content="4")
///   debug_inspect(path.last(), content="Some({ field: \"right\", index: 0 })")
///   debug_inspect(path.resolve(root).map(n => n.kind()), content="Some(\"var\")")
///   let up = path.parent().unwrap()
///   inspect(up, content="definitions[0].body[0].expression[0]")
///   inspect(up.resolve(root).unwrap().kind(), content="bin_op")
///   let missing = @syntax.NodePath::root().child("definitions", 5)
///   inspect(missing.resolve(root) is None, content="true")
/// }
/// ```
pub struct NodePath {
  /// The steps, innermost first.
  priv reversed : @list.List[PathStep]
  priv length : Int32
} derive(Eq, Hash)

///|
/// The path of the start node: no steps, depth 0.
pub fn NodePath::root() -> NodePath {
  { reversed: @list.List([]), length: 0, }
}

///|
/// The path of the node at `index` in this node's `field`.
pub fn NodePath::child(
  self : NodePath,
  field : String,
  index : Int32,
) -> NodePath {
  {
    reversed: self.reversed.prepend({ field, index, }),
    length: self.length + 1,
  }
}

///|
/// The path with these steps, from the start node down.
/// `from_steps(p.steps())` equals `p`.
pub fn NodePath::from_steps(steps : ArrayView[PathStep]) -> NodePath {
  let mut path = NodePath::root()
  for step in steps {
    path = path.child(step.field, step.index)
  }
  path
}

///|
/// This path followed by `rest`: when this path leads from `start` to `n`
/// and `rest` leads from `n` on, the result leads from `start` through
/// `n`. The empty path is the identity on both sides. It takes time linear
/// in `rest.depth()` and shares this path's steps.
pub fn NodePath::append(self : NodePath, rest : NodePath) -> NodePath {
  let mut path = self
  for step in rest.steps() {
    path = path.child(step.field, step.index)
  }
  path
}

///|
/// The number of steps (0 for the start node).
pub fn NodePath::depth(self : NodePath) -> Int32 {
  self.length
}

///|
/// The steps, from the start node down (a new array).
pub fn NodePath::steps(self : NodePath) -> Array[PathStep] {
  self.reversed.rev().to_array()
}

///|
/// The last step: the node's field and index in its parent.
pub fn NodePath::last(self : NodePath) -> PathStep? {
  self.reversed.head()
}

///|
/// The parent's path, or `None` for the start node.
pub fn NodePath::parent(self : NodePath) -> NodePath? {
  match self.reversed {
    More(_, tail~) => Some({ reversed: tail, length: self.length - 1, })
    Empty => None
  }
}

///|
/// The node this path leads to from `start`, or `None` when a step does
/// not exist there.
pub fn NodePath::resolve(self : NodePath, start : NodeRef) -> NodeRef? {
  let mut n = start
  for step in self.steps() {
    guard n.field(step.field).get(step.index) is Some(c) else { return None }
    n = c
  }
  Some(n)
}

///|
/// `definitions[0].body[1].value[0]`; empty for the start node.
pub impl Show for NodePath with fn output(self, logger) {
  logger.write_string(self.steps().map(s => "\{s.field}[\{s.index}]").join("."))
}

///|
/// `{ steps: [...] }`, the steps from the start node down.
pub impl @debug.Debug for NodePath with fn to_repr(self) {
  let steps = self.steps().map(s => @debug.Repr(s))
  @debug.Repr::record({ "steps": @debug.Repr::array(steps) })
}
