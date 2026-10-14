///|
fn node_location(n : Node) -> @span.SrcSpan {
  match n {
    D(d) => d.location()
    E(e) => e.location()
    S(s) => s.location()
    P(p) => p.location()
    T(t) => t.location()
    C(c) => c.location()
    G(g) => g.location()
    Z(z) => z.location()
  }
}

///|
/// Whether `child` lies inside `parent`.
fn inside(child : @span.SrcSpan, parent : @span.SrcSpan) -> Bool {
  parent.start <= child.start && child.end <= parent.end
}

///|
/// The compiler's exceptions: a definition's `location` covers its head
/// only; `Pattern::Assign` has the name's span; a guard `TupleIndex` has the
/// `.index` span.
fn checks_children(n : Node) -> Bool {
  match n {
    D(_) => false
    P(Assign(..)) => false
    G(TupleIndex(..)) => false
    _ => true
  }
}

///|
test "law: every child's span lies inside its parent's span" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let r = parse_text(m.text())
      guard r.diagnostics.length() == 0 else { return false }
      let stack : Array[Node] = []
      for t in r.module_.definitions {
        stack.push(D(t.definition))
      }
      let mut ok = true
      while stack.pop() is Some(node) {
        let (_, children) = node_shape(node)
        let parent = node_location(node)
        for child in children {
          if checks_children(node) && !inside(node_location(child.1), parent) {
            ok = false
          }
          stack.push(child.1)
        }
      }
      ok
    },
    count=200,
    max_size=12,
    seed=2066,
  )
}

///|
test "law: every span of a parsed module lies inside the text" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let text = m.text()
      let r = parse_text(text)
      guard r.diagnostics.length() == 0 else { return false }
      let end = @scanner.SourceText::new(text).byte_length()
      let stack : Array[Node] = []
      for t in r.module_.definitions {
        stack.push(D(t.definition))
      }
      let mut ok = true
      while stack.pop() is Some(node) {
        let s = node_location(node)
        if !(0 <= s.start && s.start <= s.end && s.end <= end) {
          ok = false
        }
        for child in node_shape(node).1 {
          stack.push(child.1)
        }
      }
      ok
    },
    count=200,
    max_size=12,
    seed=2067,
  )
}
