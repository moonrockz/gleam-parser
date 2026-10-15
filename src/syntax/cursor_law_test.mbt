///|
/// Offsets around and inside `n`: the start and end of every node in it,
/// one before each, and one past `n`.
fn node_positions(n : @syntax.NodeRef) -> Array[Int32] {
  let spans = []
  @syntax.walk(n, k => {
    spans.push(k.span())
    Continue
  })
  let out = []
  for s in spans {
    out.push(s.start)
    out.push(s.end)
    out.push(s.start - 1)
    out.push(s.end - 1)
  }
  out.push(n.span().end + 1)
  out
}

///|
/// The child goto_first_child_for(p) must pick: the innermost child that
/// contains `p` (the first among equals), or else the first child that
/// starts at or after `p`.
fn child_for(kids : Array[@syntax.NodeRef], p : Int32) -> Int32? {
  let mut best : Int32? = None
  for i, k in kids {
    let r = k.span()
    if contains(r, p) {
      match best {
        None => best = Some(i)
        Some(b) =>
          if within(r, kids[b].span()) && r != kids[b].span() {
            best = Some(i)
          }
      }
    }
  }
  match best {
    Some(_) => best
    None => kids.search_by(k => k.span().start >= p)
  }
}

///|
/// The node at `path` (child indices from `base`) and its field in its
/// parent.
fn node_at_path(
  base : @syntax.NodeRef,
  path : Array[Int32],
) -> (@syntax.NodeRef, String?) {
  let mut n = base
  let mut field = None
  for i in path {
    let parent = n
    n = parent.children()[i]
    field = parent.field_of(n)
  }
  (n, field)
}

///|
fn pick_position(n : @syntax.NodeRef, m : UInt32) -> Int32 {
  let ps = node_positions(n)
  ps[(m / 7 % ps.length().reinterpret_as_uint()).reinterpret_as_int()]
}

///|
/// Move `m` (not a reset), applied to a model cursor: a path of child
/// indices from `base`.
fn model_move(base : @syntax.NodeRef, path : Array[Int32], m : UInt32) -> Bool {
  let (n, _) = node_at_path(base, path)
  let siblings = if path.is_empty() {
    1
  } else {
    node_at_path(base, path[:path.length() - 1].to_owned()).0
    .children()
    .length()
  }
  match m % 6 {
    0 =>
      if n.children().is_empty() {
        false
      } else {
        path.push(0)
        true
      }
    1 => {
      let kids = n.children()
      if kids.is_empty() {
        false
      } else {
        path.push(kids.length() - 1)
        true
      }
    }
    2 =>
      if path.is_empty() || path[path.length() - 1] + 1 >= siblings {
        false
      } else {
        path[path.length() - 1] = path[path.length() - 1] + 1
        true
      }
    3 =>
      if path.is_empty() || path[path.length() - 1] == 0 {
        false
      } else {
        path[path.length() - 1] = path[path.length() - 1] - 1
        true
      }
    4 =>
      if path.is_empty() {
        false
      } else {
        ignore(path.pop())
        true
      }
    _ =>
      match child_for(n.children(), pick_position(n, m)) {
        Some(i) => {
          path.push(i)
          true
        }
        None => false
      }
  }
}

///|
/// Move `m` (not a reset), applied to a real cursor.
fn cursor_move(c : @syntax.TreeCursor, m : UInt32) -> Bool {
  match m % 6 {
    0 => c.goto_first_child()
    1 => c.goto_last_child()
    2 => c.goto_next_sibling()
    3 => c.goto_previous_sibling()
    4 => c.goto_parent()
    _ => c.goto_first_child_for(pick_position(c.node(), m))
  }
}

///|
/// The children of `n` as (field, index in field, node), sorted by start
/// and then by field order: computed apart from `children()`.
fn slot_order(n : @syntax.NodeRef) -> Array[(String, Int32, @syntax.NodeRef)] {
  let slots : Array[(Int32, String, Int32, @syntax.NodeRef)] = []
  for f in n.fields() {
    for i, c in n.field(f) {
      slots.push((slots.length(), f, i, c))
    }
  }
  slots.sort_by((a, b) => {
    let x = a.3.span().start
    let y = b.3.span().start
    if x != y {
      x.compare(y)
    } else {
      a.0.compare(b.0)
    }
  })
  slots.map(s => (s.1, s.2, s.3))
}

///|
/// The path steps a model path (child indices from `base`) names.
fn model_steps(
  base : @syntax.NodeRef,
  path : Array[Int32],
) -> Array[@syntax.PathStep] {
  let mut n = base
  let steps = []
  for k in path {
    let (field, index, child) = slot_order(n)[k]
    let step : @syntax.PathStep = { field, index, }
    steps.push(step)
    n = child
  }
  steps
}

///|
/// Whether the cursor is where the model path from `base` says.
fn agrees(
  c : @syntax.TreeCursor,
  base : @syntax.NodeRef,
  path : Array[Int32],
) -> Bool {
  let (n, field) = node_at_path(base, path)
  tag(c.node()) == tag(n) &&
  c.field_name() == field &&
  c.depth() == path.length() &&
  c.path().depth() == path.length() &&
  c.path().last().map(s => s.field) == field &&
  c.path().resolve(base).map(tag) == Some(tag(n)) &&
  c.path().steps() == model_steps(base, path)
}

///|
test "law: every cursor move agrees with a path model, resets included" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Array[UInt32])) => {
      let (m, moves) = input
      let root = gleam_root(m)
      let nodes = []
      @syntax.walk(root, n => {
        nodes.push(n)
        Continue
      })
      let c = @syntax.TreeCursor::new(root)
      let mut base = root
      let path = []
      moves
      .iter()
      .all(mv => {
        let same = if mv % 8 == 7 {
          base = nodes[(mv / 8 % nodes.length().reinterpret_as_uint()).reinterpret_as_int()]
          c.reset(base)
          path.clear()
          true
        } else {
          cursor_move(c, mv) == model_move(base, path, mv)
        }
        same && agrees(c, base, path)
      })
    },
    count=100,
    max_size=10,
    seed=2161,
  )
}

///|
test "law: a cursor's copy moves independently" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Array[UInt32], Array[UInt32])) => {
      let (m, first, second) = input
      let root = gleam_root(m)
      let c = @syntax.TreeCursor::new(root)
      let path = []
      for mv in first {
        ignore(cursor_move(c, mv))
        ignore(model_move(root, path, mv))
      }
      let d = c.copy()
      let copy_path = path.copy()
      for mv in second {
        ignore(cursor_move(d, mv))
        ignore(model_move(root, copy_path, mv))
      }
      let c_unchanged = agrees(c, root, path)
      for mv in first {
        ignore(cursor_move(c, mv))
        ignore(model_move(root, path, mv))
      }
      c_unchanged && agrees(c, root, path) && agrees(d, root, copy_path)
    },
    count=100,
    max_size=10,
    seed=2162,
  )
}

///|
test "law: a full cursor navigation enters children() pre-order and ends at the start" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      navigate(root) == preorder(root)
    },
    count=100,
    max_size=10,
    seed=2163,
  )
}

///|
test "law: at every node, goto_first_child_for(p) moves to the innermost child that contains p, or the first that follows it" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let c = @syntax.TreeCursor::new(root)
      let mut ok = true
      @syntax.walk(root, n => {
        let kids = n.children()
        for p in node_positions(n) {
          c.reset(n)
          let moved = c.goto_first_child_for(p)
          ok = ok &&
            (match child_for(kids, p) {
              None => !moved && c.depth() == 0
              Some(i) =>
                moved &&
                c.depth() == 1 &&
                tag(c.node()) == tag(kids[i]) &&
                c.field_name() == n.field_of(kids[i])
            })
        }
        Continue
      })
      ok
    },
    count=100,
    max_size=10,
    seed=2164,
  )
}

///|
test "law: descending with goto_first_child_for ends at node_at" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let (tree, text, _, nodes) = module_tree(m)
      let root = tree.root()
      let length = @scanner.SourceText::new(text).byte_length()
      edge_offsets(length, nodes.map(n => n.span()))
      .iter()
      .filter(p => contains(root.span(), p))
      .all(p => {
        let c = @syntax.TreeCursor::new(root)
        while c.goto_first_child_for(p) {
          if !contains(c.node().span(), p) {
            ignore(c.goto_parent())
            break
          }
        }
        guard tree.node_at(p) is Some(found) else { return false }
        contains(c.node().span(), p) &&
        !c.node().children().iter().any(k => contains(k.span(), p)) &&
        (tag(c.node()) == tag(found) || capture_exception(c.node(), found))
      })
    },
    count=100,
    max_size=10,
    seed=2165,
  )
}

///|
/// The documented exception: a function capture `f(_)` gives a generated
/// argument whose span is the hole's; the descent stops at that argument
/// (a leaf) while `node_at` gives the deeper hole variable. `goto_node_at`
/// reaches it.
fn capture_exception(
  stopped : @syntax.NodeRef,
  found : @syntax.NodeRef,
) -> Bool {
  stopped.category() == "arg" && stopped.span() == found.span()
}

///|
test "law: goto_node_at from the root or from any ancestor of node_at(p) moves to node_at(p), with its path" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let (tree, text, _, nodes) = module_tree(m)
      let root = tree.root()
      let length = @scanner.SourceText::new(text).byte_length()
      edge_offsets(length, nodes.map(n => n.span()))
      .iter()
      .all(p => {
        let c = @syntax.TreeCursor::new(root)
        let moved = c.goto_node_at(p)
        match tree.node_at(p) {
          None => !moved && c.depth() == 0 && c.node() == root
          Some(found) =>
            moved &&
            c.node() == found &&
            Some(c.path()) == tree.node_path(found) &&
            tree
            .ancestors(found)
            .iter()
            .all(a => {
              let from_a = @syntax.TreeCursor::new(a)
              from_a.goto_node_at(p) &&
              from_a.node() == found &&
              tree.node_path(a).map(ap => ap.append(from_a.path())) ==
              tree.node_path(found)
            })
        }
      })
    },
    count=100,
    max_size=10,
    seed=2166,
  )
}
