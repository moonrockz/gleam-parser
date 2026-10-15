///|
fn contains(s : @span.SrcSpan, p : Int32) -> Bool {
  s.start <= p && p < s.end
}

///|
fn within(a : @span.SrcSpan, b : @span.SrcSpan) -> Bool {
  b.start <= a.start && a.end <= b.end
}

///|
/// Offsets around every span: each start and end, one before each, 0, the
/// end of the text and one past it.
fn edge_offsets(length : Int32, spans : Array[@span.SrcSpan]) -> Array[Int32] {
  let out = [0, length, length + 1, -1]
  for s in spans {
    out.push(s.start)
    out.push(s.end)
    out.push(s.start - 1)
    out.push(s.end - 1)
    out.push(s.end + 1)
  }
  out
}

///|
/// A generated module's tree, text, parse result and every node (pre-order).
fn module_tree(
  m : @lawkit.GleamModule,
) -> (@syntax.Tree, String, @parser.ParseResult, Array[@syntax.NodeRef]) raise {
  ignore(gleam_root(m))
  let text = m.text()
  let result = @parser.parse_text(text)
  let tree = @syntax.Tree::new(result)
  let nodes = []
  @syntax.walk(tree.root(), n => {
    nodes.push(n)
    Continue
  })
  (tree, text, result, nodes)
}

///|
test "law: node_at is a smallest node that contains the offset: deepest among equals, first among partial overlaps" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let (tree, text, _, nodes) = module_tree(m)
      let depth = nodes.map(n => tree.ancestors(n).length())
      let length = @scanner.SourceText::new(text).byte_length()
      edge_offsets(length, nodes.map(n => n.span()))
      .iter()
      .all(p => {
        let holders = []
        for i, n in nodes {
          if contains(n.span(), p) {
            holders.push(i)
          }
        }
        match tree.node_at(p) {
          None => holders.is_empty()
          Some(found) => {
            guard nodes.search_by(n => n == found) is Some(fi) else {
              return false
            }
            let f = found.span()
            holders.contains(fi) &&
            holders
            .iter()
            .all(i => {
              let r = nodes[i].span()
              !(within(r, f) && r != f) &&
              (r != f || depth[i] <= depth[fi]) &&
              (within(f, r) || within(r, f) || fi < i)
            })
          }
        }
      })
    },
    count=100,
    max_size=10,
    seed=2151,
  )
}

///|
test "law: tokens_in keeps exactly the whole tokens inside the span" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let (tree, _, result, nodes) = module_tree(m)
      let all = result.cst.tokens.map(t => t.span)
      let candidates : Array[@span.SrcSpan] = nodes.map(n => n.span())
      for i, r in all {
        candidates.push(r)
        candidates.push(@span.SrcSpan::new(r.start, r.start))
        if r.end - r.start >= 2 {
          candidates.push(@span.SrcSpan::new(r.start + 1, r.end))
          candidates.push(@span.SrcSpan::new(r.start, r.end - 1))
        }
        if all.get(i + 1) is Some(next) {
          candidates.push(@span.SrcSpan::new(r.start, next.end))
          candidates.push(@span.SrcSpan::new(r.start, next.start))
          candidates.push(@span.SrcSpan::new(r.end - 1, next.start + 1))
        }
      }
      candidates
      .iter()
      .all(r => {
        tree.tokens_in(r) == result.cst.tokens.filter(t => within(t.span, r))
      })
    },
    count=50,
    max_size=10,
    seed=2152,
  )
}

///|
test "law: the text at a node's span starts with its first token and ends with its last" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let (tree, text, _, nodes) = module_tree(m)
      let source = @scanner.SourceText::new(text)
      nodes
      .iter()
      .all(n => {
        // The module starts at byte 0, before any leading comment.
        if n.category() == "module" {
          return true
        }
        let tokens = tree.tokens_in(n.span())
        if tokens.is_empty() {
          return true
        }
        guard source.slice(n.span()) is Some(s) else { return false }
        s.has_prefix(tokens[0].lexeme) &&
        s.has_suffix(tokens[tokens.length() - 1].lexeme)
      })
    },
    count=100,
    max_size=10,
    seed=2153,
  )
}

///|
/// Every node's category/kind in pre-order.
fn shape(text : String) -> Array[String] {
  let out = []
  @syntax.walk(@syntax.NodeRef::of_result(@parser.parse_text(text)), n => {
    out.push("\{n.category()}/\{n.kind()}")
    Continue
  })
  out
}

///|
test "law: LF, CRLF and a missing final newline give the same node kinds in walk order" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      ignore(gleam_root(m))
      let lf = m.text().replace_all(old="\r\n", new="\n")
      let base = if lf.has_suffix("\n") { lf } else { lf + "\n" }
      let bare = base.trim_end(chars="\n").to_owned()
      let expected = shape(base)
      let mut same = true
      for
        text in [
          base.replace_all(old="\n", new="\r\n"),
          bare,
          bare.replace_all(old="\n", new="\r\n"),
        ] {
        same = same &&
          @parser.parse_text(text).diagnostics.is_empty() &&
          shape(text) == expected
      }
      same
    },
    count=100,
    max_size=10,
    seed=2154,
  )
}

///|
test "law: for any text, every node lies inside the source and inside its parent" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      let result = @parser.parse_text(text)
      let length = @scanner.SourceText::new(text).byte_length()
      let root = @syntax.NodeRef::of_result(result)
      let mut ok = true
      let open : Array[@syntax.NodeRef] = []
      @syntax.walk(
        root,
        n => {
          let s = n.span()
          ok = ok &&
            0 <= s.start &&
            s.start <= s.end &&
            s.end <= length &&
            (match open.last() {
              // A definition's own AST location covers its head only, but
              // its node span reaches end_position; the module covers all.
              Some(parent) => within(s, parent.span())
              None => true
            })
          open.push(n)
          Continue
        },
        leave=_ => ignore(open.pop()),
      )
      ok
    },
    count=100,
    max_size=10,
    seed=2155,
  )
}
