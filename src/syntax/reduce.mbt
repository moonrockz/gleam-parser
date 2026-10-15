///|
/// One open node of a reduction: its children with their steps, the next
/// child to open, and the results of the children done so far.
priv struct ReduceFrame[A] {
  node : NodeRef
  children : Array[(PathStep, NodeRef)]
  mut next : Int32
  results : Array[(PathStep, A)]
}

///|
/// Reduce the tree below `root` to one value, bottom up: `f` gets a node
/// and its children's results in `children()` order and returns the
/// node's result; the root's result is the answer. This is the visitor
/// that returns a value: a trait cannot carry the result type, a closure
/// can. An explicit stack, not recursion, holds the open nodes, so trees
/// of any depth work on every target.
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("pub fn f() {\n  [[1]]\n}\n")
///   let root = @syntax.NodeRef::of_result(r)
///   let nodes = @syntax.reduce(root, (_, kids) => {
///     let mut n = 1
///     for k in kids {
///       n += k
///     }
///     n
///   })
///   inspect(nodes, content="6")
/// }
/// ```
pub fn[A] reduce(root : NodeRef, f : (NodeRef, ArrayView[A]) -> A) -> A {
  reduce_with_fields(root, (n, kids) => f(n, kids.map(k => k.1)[:]))
}

///|
/// `reduce` with each child's step (its field and index) next to its
/// result, so `f` can tell `left` from `right`.
///
/// ```mbt check
/// test {
///   let sum = @syntax.NodeRef::Expr(@parser.parse_expression_text("a + b"))
///   let shown = @syntax.reduce_with_fields(sum, (n, kids) => {
///     let parts = kids.to_owned().map(k => "\{k.0.field}=\{k.1}")
///     if parts.length() == 0 {
///       n.kind()
///     } else {
///       n.kind() + "{" + parts.join(" ") + "}"
///     }
///   })
///   inspect(shown, content="bin_op{left=var right=var}")
/// }
/// ```
pub fn[A] reduce_with_fields(
  root : NodeRef,
  f : (NodeRef, ArrayView[(PathStep, A)]) -> A,
) -> A {
  let stack : Array[ReduceFrame[A]] = [
    { node: root, children: root.children_with_fields(), next: 0, results: [], },
  ]
  let mut answer : A? = None
  while stack.last() is Some(top) {
    if top.next < top.children.length() {
      let (_, child) = top.children[top.next]
      stack.push({
        node: child,
        children: child.children_with_fields(),
        next: 0,
        results: [],
      })
    } else {
      ignore(stack.pop())
      let value = f(top.node, top.results[:])
      match stack.last() {
        Some(parent) => {
          let (step, _) = parent.children[parent.next]
          parent.next = parent.next + 1
          parent.results.push((step, value))
        }
        None => answer = Some(value)
      }
    }
  }
  answer.unwrap()
}
