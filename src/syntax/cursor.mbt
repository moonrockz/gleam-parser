///|
/// One level of a cursor: the siblings (with their fields) and the
/// current position among them.
priv struct CursorFrame {
  /// Never changed after the frame is made, so copies share it.
  siblings : Array[(PathStep?, NodeRef)]
  /// The parent's path (the start node's frame has the empty path).
  parent_path : NodePath
  mut index : Int32
}

///|
/// A tree-sitter-style cursor: the caller moves it with the `goto_*`
/// methods. Each `goto_*` returns `false` and leaves the cursor in place
/// when there is nowhere to go. Its state is a stack of frames, not
/// recursion. A cursor belongs to its caller; `copy` gives an independent
/// cursor.
///
/// ```mbt check
/// test {
///   let root = @syntax.NodeRef::of_result(
///     @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let cursor = @syntax.TreeCursor(root)
///   inspect(cursor.goto_first_child(), content="true")
///   inspect(cursor.node().kind(), content="function")
///   inspect(cursor.goto_next_sibling(), content="false")
///   // Down to the arguments of `add`.
///   ignore(cursor.goto_first_child())
///   inspect(cursor.goto_next_sibling(), content="true")
///   debug_inspect(cursor.field_name(), content="Some(\"arguments\")")
///   inspect(cursor.depth(), content="2")
///   inspect(cursor.path(), content="definitions[0].arguments[1]")
///   // A copy moves on its own.
///   let other = cursor.copy()
///   ignore(other.goto_parent())
///   inspect(cursor.node().kind(), content="arg")
/// }
/// ```
pub struct TreeCursor {
  priv frames : Array[CursorFrame]
}

///|
/// A cursor at `root` (depth 0, no field).
#alias(new, deprecated="Use `TreeCursor(...)` instead")
pub fn TreeCursor::TreeCursor(root : NodeRef) -> TreeCursor {
  {
    frames: [
      { siblings: [(None, root)], parent_path: NodePath::root(), index: 0, },
    ],
  }
}

///|
fn TreeCursor::top(self : TreeCursor) -> CursorFrame {
  self.frames[self.frames.length() - 1]
}

///|
/// The node at the cursor.
pub fn TreeCursor::node(self : TreeCursor) -> NodeRef {
  let f = self.top()
  f.siblings[f.index].1
}

///|
/// The node's field in its parent (`"arguments"`, ...); `None` at the
/// start node.
pub fn TreeCursor::field_name(self : TreeCursor) -> String? {
  let f = self.top()
  f.siblings[f.index].0.map(step => step.field)
}

///|
/// The steps from the start node to the node (each frame keeps its
/// parent's path, so this is O(1)).
pub fn TreeCursor::path(self : TreeCursor) -> NodePath {
  let f = self.top()
  match f.siblings[f.index].0 {
    Some(step) => f.parent_path.child(step.field, step.index)
    None => f.parent_path
  }
}

///|
/// The number of `goto_*` steps below the start node (0 at the start
/// node).
pub fn TreeCursor::depth(self : TreeCursor) -> NodeDepth {
  NodeDepth::from_int(self.frames.length() - 1).unwrap()
}

///|
/// Move to the child that `choose` picks among the node's children.
fn TreeCursor::descend(
  self : TreeCursor,
  choose : (Array[(PathStep?, NodeRef)]) -> Int32?,
) -> Bool {
  let kids = self.node().children_with_fields().map(x => (Some(x.0), x.1))
  guard choose(kids) is Some(i) else { return false }
  let parent_path = self.path()
  self.frames.push({ siblings: kids, parent_path, index: i, })
  true
}

///|
/// Move to the node's first child in source order. Return `false` and
/// stay when the node has no children.
pub fn TreeCursor::goto_first_child(self : TreeCursor) -> Bool {
  self.descend(kids => if kids.is_empty() { None } else { Some(0) })
}

///|
/// Move to the node's last child in source order. Return `false` and
/// stay when the node has no children.
pub fn TreeCursor::goto_last_child(self : TreeCursor) -> Bool {
  self.descend(kids => {
    if kids.is_empty() {
      None
    } else {
      Some(kids.length() - 1)
    }
  })
}

///|
/// Move to the next child of the same parent, in source order. Return
/// `false` and stay at the last child and at the start node.
pub fn TreeCursor::goto_next_sibling(self : TreeCursor) -> Bool {
  let f = self.top()
  if f.index + 1 < f.siblings.length() {
    f.index = f.index + 1
    true
  } else {
    false
  }
}

///|
/// Move to the previous child of the same parent, in source order. Return
/// `false` and stay at the first child and at the start node.
pub fn TreeCursor::goto_previous_sibling(self : TreeCursor) -> Bool {
  let f = self.top()
  if f.index > 0 {
    f.index = f.index - 1
    true
  } else {
    false
  }
}

///|
/// Move to the parent. Return `false` and stay at the start node: the
/// cursor never goes above the node it started at.
pub fn TreeCursor::goto_parent(self : TreeCursor) -> Bool {
  if self.frames.length() > 1 {
    ignore(self.frames.pop())
    true
  } else {
    false
  }
}

///|
/// Move to the child whose span contains byte offset `p`, or else to the
/// first child that starts at or after `p`. Where children overlap, the
/// innermost one that contains `p` wins, and the first in source order
/// among equals.
///
/// `goto_node_at(p)` moves to `Tree::node_at(p)` in one call. By hand,
/// descend while the new node contains `p`, and step back with
/// `goto_parent` from the first one that does not: a loop that only calls
/// `goto_first_child_for` goes one node too far whenever `node_at(p)` has
/// children after `p`. One place where the descent does not reach
/// `node_at(p)`: a function capture `f(_)` gives a generated argument
/// whose span is the hole's, so the descent stops at that argument while
/// `node_at` gives the hole's variable inside the call; `goto_node_at`
/// reaches it.
///
/// ```mbt check
/// test {
///   let tree = @syntax.Tree(
///     @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let p = @span.ByteOffset::from_int(23).unwrap() // the `+` in `a + b`
///   let contains = (s : @span.SrcSpan) => s.start <= p && p < s.end
///   let cursor = @syntax.TreeCursor(tree.root())
///   while cursor.goto_first_child_for(p) {
///     if !contains(cursor.node().span()) {
///       ignore(cursor.goto_parent())
///       break
///     }
///   }
///   inspect(cursor.node().kind(), content="bin_op")
///   inspect(tree.node_at(p) == Some(cursor.node()), content="true")
///   // A plain loop goes one node too far, to `b` after the `+`.
///   let naive = @syntax.TreeCursor(tree.root())
///   while naive.goto_first_child_for(p) {
///
///   }
///   inspect(naive.path(), content="definitions[0].body[0].expression[0].right[0]")
/// }
/// ```
pub fn TreeCursor::goto_first_child_for(
  self : TreeCursor,
  p : @span.ByteOffset,
) -> Bool {
  self.descend(kids => {
    let mut best : Int32? = None
    for i, x in kids {
      let r = x.1.span()
      if contains(r, p) {
        match best {
          None => best = Some(i)
          Some(b) => {
            let br = kids[b].1.span()
            if within(r, br) && r != br {
              best = Some(i)
            }
          }
        }
      }
    }
    match best {
      Some(_) => best
      None => kids.search_by(x => x.1.span().start >= p)
    }
  })
}

///|
/// Move to `Tree::node_at(p)` within the current node: the innermost node
/// at or below it whose span contains `p` (the smallest span; for equal
/// spans the deeper node, then the first in source order). `goto_parent`
/// then goes back up the way it came. Return `false` and stay when the
/// current node does not contain `p`; stay and return `true` when no child
/// does.
///
/// ```mbt check
/// test {
///   let tree = @syntax.Tree(
///     @parser.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let cursor = @syntax.TreeCursor(tree.root())
///   inspect(
///     cursor.goto_node_at(@span.ByteOffset::from_int(23).unwrap()),
///     content="true",
///   )
///   inspect(cursor.node().kind(), content="bin_op")
///   inspect(cursor.path(), content="definitions[0].body[0].expression[0]")
///   // `pub` is outside the current node: the cursor stays.
///   inspect(
///     cursor.goto_node_at(@span.ByteOffset::from_int(0).unwrap()),
///     content="false",
///   )
///   inspect(cursor.node().kind(), content="bin_op")
/// }
/// ```
pub fn TreeCursor::goto_node_at(
  self : TreeCursor,
  p : @span.ByteOffset,
) -> Bool {
  guard innermost_at(self.node(), p) is Some((_, indices)) else { return false }
  for i in indices {
    ignore(self.descend(_ => Some(i)))
  }
  true
}

///|
/// Move the cursor to a new start node (depth 0).
pub fn TreeCursor::reset(self : TreeCursor, node : NodeRef) -> Unit {
  self.frames.clear()
  self.frames.push({
    siblings: [(None, node)],
    parent_path: NodePath::root(),
    index: 0,
  })
}

///|
/// An independent cursor at the same place.
pub fn TreeCursor::copy(self : TreeCursor) -> TreeCursor {
  {
    frames: self.frames.map(f => {
      siblings: f.siblings,
      parent_path: f.parent_path,
      index: f.index,
    }),
  }
}
