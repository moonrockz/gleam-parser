// Shared helpers of the syntax laws: a generated module's root, a
// `Control` policy, node tags, and the recursive reference walk.

///|
fn pick(rs : @splitmix.RandomState, n : Int32) -> Int32 {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
/// The root of a generated module. Any diagnostic fails the law: a
/// generator defect must be seen, not discarded.
fn gleam_root(m : @lawkit.GleamModule) -> @syntax.NodeRef raise {
  let text = m.text()
  let result = @parser.parse_text(text)
  if !result.diagnostics.is_empty() {
    fail(
      "generated Gleam does not parse:\n\{text}\n\{result.diagnostics.map(d => d.message).join("; ")}",
    )
  }
  @syntax.NodeRef::of_result(result)
}

///|
/// What the k-th entered node returns: mostly Continue, sometimes
/// SkipChildren, rarely Stop.
struct Policy(Array[@syntax.Control]) derive(Debug)

///|
impl @quickcheck.Arbitrary for Policy with fn arbitrary(_, rs) {
  let n = 1 + pick(rs, 8)
  Policy(
    Array::makei(n, _ => {
      match pick(rs, 10) {
        0 => Stop
        1 | 2 | 3 => SkipChildren
        _ => Continue
      }
    }),
  )
}

///|
impl @quickcheck.Shrink for Policy with fn shrink(_self) {
  [].iter()
}

///|
fn decide(p : Policy, k : Int32) -> @syntax.Control {
  let Policy(cs) = p
  cs[k % cs.length()]
}

///|
/// A node's occurrence tag: category, kind and full span.
fn tag(n : @syntax.NodeRef) -> String {
  let s = n.span()
  "\{n.category()}/\{n.kind()}@\{s.start.to_int()}-\{s.end.to_int()}"
}

///|
/// The events a walk under `p` must produce, by plain recursion
/// (test-only; generated trees are shallow).
fn model(root : @syntax.NodeRef, p : Policy) -> Array[String] {
  let events = []
  let mut k = 0
  fn go(n : @syntax.NodeRef) -> Bool {
    let c = decide(p, k)
    k = k + 1
    events.push("+" + tag(n))
    match c {
      Stop => return true
      SkipChildren => ()
      Continue =>
        for child in n.children() {
          if go(child) {
            return true
          }
        }
    }
    events.push("-" + tag(n))
    false
  }

  ignore(go(root))
  events
}

///|
fn walk_events(root : @syntax.NodeRef, p : Policy) -> Array[String] {
  let events = []
  let mut k = 0
  @syntax.walk(
    root,
    n => {
      events.push("+" + tag(n))
      k = k + 1
      decide(p, k - 1)
    },
    leave=n => events.push("-" + tag(n)),
  )
  events
}

///|
/// Every node's tag in `children()` pre-order, with an explicit stack.
fn preorder(root : @syntax.NodeRef) -> Array[String] {
  let out = []
  let stack = [root]
  while stack.pop() is Some(n) {
    out.push(tag(n))
    let kids = n.children()
    for i = kids.length() - 1; i >= 0; i = i - 1 {
      stack.push(kids[i])
    }
  }
  out
}

///|
/// Subtree sizes in pre-order (test-only recursion over a shallow tree).
fn subtree_sizes(root : @syntax.NodeRef) -> Array[Int32] {
  let sizes = []
  fn go(n : @syntax.NodeRef) -> Int32 {
    let at = sizes.length()
    sizes.push(1)
    let mut total = 1
    for c in n.children() {
      total = total + go(c)
    }
    sizes[at] = total
    total
  }

  ignore(go(root))
  sizes
}
