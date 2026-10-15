///|
/// A parse result as a tree with random access: parents, ancestors, paths,
/// the node at a byte offset and the tokens in a span. It is built once
/// and never changes; its indexes are private.
pub struct Tree {
  priv root : NodeRef
  /// identity key → (node, parent, step in the parent) for every node
  /// below the root.
  priv parents : Map[String, Array[(NodeRef, NodeRef, PathStep)]]
  priv tokens : ArrayView[@scanner.Token]
}

///|
/// The index key of a node: category, kind and span. Two different nodes
/// with the same key are told apart by structural equality.
fn identity(n : NodeRef) -> String {
  let s = n.span()
  "\{n.category()}/\{n.kind()}/\{s.start}-\{s.end}"
}

///|
/// The tree of `result`. It walks the whole tree once to index the
/// parents (an explicit stack), so build it once and keep it.
///
/// ```mbt check
/// test {
///   let tree = @syntax.Tree::new(
///     @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let body = tree.root().field("definitions")[0].field("body")[0]
///   inspect(tree.parent(body).unwrap().kind(), content="function")
///   inspect(tree.parent(tree.root()) is None, content="true")
///   debug_inspect(
///     tree.ancestors(body).map(n => n.kind()),
///     content="[\"function\", \"module\"]",
///   )
///   debug_inspect(
///     tree.path(body).map(n => n.kind()),
///     content="[\"module\", \"function\", \"expression\"]",
///   )
/// }
/// ```
pub fn Tree::new(result : @parser.ParseResult) -> Tree {
  let root = NodeRef::of_result(result)
  let parents : Map[String, Array[(NodeRef, NodeRef, PathStep)]] = Map([])
  let stack = [root]
  while stack.pop() is Some(node) {
    for entry in node.children_with_fields() {
      let (step, child) = entry
      let key = identity(child)
      let item = (child, node, step)
      match parents.get(key) {
        Some(bucket) => bucket.push(item)
        None => parents[key] = [item]
      }
      stack.push(child)
    }
  }
  { root, parents, tokens: result.cst.tokens, }
}

///|
/// The module node at the top of the tree.
pub fn Tree::root(self : Tree) -> NodeRef {
  self.root
}

///|
/// The parent of `n`, or `None` for the root and for nodes not in the
/// tree.
pub fn Tree::parent(self : Tree, n : NodeRef) -> NodeRef? {
  self.parent_entry(n).map(e => e.0)
}

///|
/// The step from the parent of `n` to `n` (its field and its index in
/// that field), or `None` for the root and for nodes not in the tree. It
/// reads the tree's index, so it does not look through the parent's
/// fields.
///
/// ```mbt check
/// test {
///   let tree = @syntax.Tree::new(
///     @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let b = tree.root().field("definitions")[0].field("arguments")[1]
///   debug_inspect(
///     tree.step(b),
///     content="Some({ field: \"arguments\", index: 1 })",
///   )
///   debug_inspect(tree.field_of(b), content="Some(\"arguments\")")
///   debug_inspect(tree.field_of(tree.root()), content="None")
/// }
/// ```
pub fn Tree::step(self : Tree, n : NodeRef) -> PathStep? {
  self.parent_entry(n).map(e => e.1)
}

///|
/// The field of the parent of `n` that holds `n`, or `None` for the root
/// and for nodes not in the tree. It gives what `parent.field_of(n)`
/// gives, but reads the tree's index, so a walk can call it for every
/// node.
pub fn Tree::field_of(self : Tree, n : NodeRef) -> String? {
  self.parent_entry(n).map(e => e.1.field)
}

///|
/// The parent of `n` and the step from the parent to `n`.
fn Tree::parent_entry(self : Tree, n : NodeRef) -> (NodeRef, PathStep)? {
  guard self.parents.get(identity(n)) is Some(bucket) else { return None }
  for entry in bucket {
    if same(entry.0, n) {
      return Some((entry.1, entry.2))
    }
  }
  None
}

///|
/// The parents of `n`, nearest first, ending at the root (a new array).
pub fn Tree::ancestors(self : Tree, n : NodeRef) -> Array[NodeRef] {
  let found = []
  let mut current = n
  while self.parent(current) is Some(p) {
    found.push(p)
    current = p
  }
  found
}

///|
/// The nodes from the root down to `n`, both included (a new array).
pub fn Tree::path(self : Tree, n : NodeRef) -> Array[NodeRef] {
  let path = self.ancestors(n)
  path.rev_in_place()
  path.push(n)
  path
}

///|
/// The steps from the root to `n`, or `None` when `n` is not in the
/// tree. With `node_at`, this takes an editor from an offset to a path.
///
/// ```mbt check
/// test {
///   let tree = @syntax.Tree::new(
///     @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   // Byte 25 is the `b` in `a + b`.
///   let b = tree.node_at(25).unwrap()
///   inspect("\{b.category()}/\{b.kind()}", content="expression/var")
///   inspect(
///     tree.node_path(b).unwrap(),
///     content="definitions[0].body[0].expression[0].right[0]",
///   )
/// }
/// ```
pub fn Tree::node_path(self : Tree, n : NodeRef) -> NodePath? {
  let steps = []
  let mut current = n
  while self.parent_entry(current) is Some((parent, step)) {
    steps.push(step)
    current = parent
  }
  guard same(current, self.root) else { return None }
  let mut path = NodePath::root()
  for step in steps.rev_iter() {
    path = path.child(step.field, step.index)
  }
  Some(path)
}

///|
/// Whether `s` contains `p` (`start <= p < end`; an empty span contains
/// nothing).
fn contains(s : @span.SrcSpan, p : Int32) -> Bool {
  s.start <= p && p < s.end
}

///|
/// Whether `a` fits inside `b`.
fn within(a : @span.SrcSpan, b : @span.SrcSpan) -> Bool {
  b.start <= a.start && a.end <= b.end
}

///|
/// The innermost node whose span contains byte offset `p`, or `None`
/// outside the text. Every branch that contains `p` is searched; the
/// smallest span wins; for equal spans the deeper node wins, then the
/// first in source order. See `node_path` for an example.
pub fn Tree::node_at(self : Tree, p : Int32) -> NodeRef? {
  innermost_at(self.root, p).map(found => found.0)
}

///|
/// The innermost node at or below `start` whose span contains `p` (the
/// rule of `Tree::node_at`), with the index of each step down in its
/// parent's `children()`, or `None` when `start` does not contain `p`.
fn innermost_at(start : NodeRef, p : Int32) -> (NodeRef, Array[Int32])? {
  if !contains(start.span(), p) {
    return None
  }
  let mut best = start
  let mut best_trail : @list.List[Int32] = @list.List([])
  let mut best_depth = 0
  // An explicit stack, visited in source order. A trail holds the child
  // indices from `start`, innermost first.
  let stack : Array[(NodeRef, Int32, @list.List[Int32])] = [
    (start, 0, @list.List([])),
  ]
  while stack.pop() is Some((node, depth, trail)) {
    let r = node.span()
    let b = best.span()
    if (within(r, b) && r != b) || (r == b && depth > best_depth) {
      best = node
      best_trail = trail
      best_depth = depth
    }
    let kids = node.children()
    for i = kids.length() - 1; i >= 0; i = i - 1 {
      if contains(kids[i].span(), p) {
        stack.push((kids[i], depth + 1, trail.prepend(i)))
      }
    }
  }
  let indices = best_trail.to_array()
  indices.rev_in_place()
  Some((best, indices))
}

///|
/// The tokens that lie inside `s`, in source order (a new array; the
/// tokens are shared with the parse result). A token that lies only
/// partly inside `s` is left out.
///
/// ```mbt check
/// test {
///   let tree = @syntax.Tree::new(
///     @parser.parse_text("pub fn f() {\n  1\n}\n\nconst x = 2\n"),
///   )
///   let f = tree.root().field("definitions")[0]
///   debug_inspect(
///     tree.tokens_in(f.span()).map(t => t.lexeme),
///     content="[\"pub\", \"fn\", \"f\", \"(\", \")\", \"{\", \"1\", \"}\"]",
///   )
/// }
/// ```
pub fn Tree::tokens_in(self : Tree, s : @span.SrcSpan) -> Array[@scanner.Token] {
  self.tokens.filter(t => within(t.span, s))
}
