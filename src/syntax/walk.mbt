///|
/// What a traversal does after it enters a node.
pub(all) enum Control {
  /// Visit the node's children next.
  Continue
  /// Do not visit the children; the node is still left.
  SkipChildren
  /// End the traversal now; no node is left after this.
  Stop
} derive(Eq, Debug)

///|
/// One open node on the walk stack.
priv struct Frame {
  node : NodeRef
  children : Array[NodeRef]
  mut next : Int32
}

///|
/// Visit `root` and every node below it in pre-order (source order).
/// `enter` runs when a node is reached and decides what happens next;
/// `leave` runs after all of a node's children, with the same node
/// object. An explicit stack, not recursion, holds the open nodes, so
/// trees of any depth work on every target and no fuel is spent. All
/// traversal state belongs to this call.
///
/// ```mbt check
/// test {
///   let root = @syntax.NodeRef::of_result(
///     @parser.parse_text("pub fn f(x) {\n  x\n}\n"),
///   )
///   // Log enter and leave; skip the arguments.
///   let log = []
///   @syntax.walk(
///     root,
///     n => {
///       log.push("+" + n.kind())
///       if n.category() == "arg" {
///         SkipChildren
///       } else {
///         Continue
///       }
///     },
///     leave=n => log.push("-" + n.kind()),
///   )
///   inspect(
///     log.join(" "),
///     content="+module +function +arg -arg +expression +var -var -expression -function -module",
///   )
///   // Stop at the first `var`: the walk ends there, with no more `leave`.
///   let seen = []
///   @syntax.walk(
///     root,
///     n => {
///       seen.push("+" + n.kind())
///       if n.kind() == "var" {
///         Stop
///       } else {
///         Continue
///       }
///     },
///     leave=n => seen.push("-" + n.kind()),
///   )
///   inspect(
///     seen.join(" "),
///     content="+module +function +arg -arg +expression +var",
///   )
/// }
/// ```
pub fn walk(
  root : NodeRef,
  enter : (NodeRef) -> Control,
  leave~ : (NodeRef) -> Unit = _ => (),
) -> Unit {
  match enter(root) {
    Stop => return
    SkipChildren => {
      leave(root)
      return
    }
    Continue => ()
  }
  let stack = [{ node: root, children: root.children(), next: 0, }]
  while stack.last() is Some(top) {
    if top.next < top.children.length() {
      let child = top.children[top.next]
      top.next = top.next + 1
      match enter(child) {
        Stop => return
        SkipChildren => leave(child)
        Continue =>
          stack.push({ node: child, children: child.children(), next: 0, })
      }
    } else {
      ignore(stack.pop())
      leave(top.node)
    }
  }
}
