///|
/// A node of the AST, for the span laws (test support only; the v0.2
/// syntax tree gives the public model).
priv enum Node {
  D(@ast.Definition)
  E(@ast.Expr)
  S(@ast.Statement)
  P(@ast.Pattern)
  T(@ast.TypeAst)
  C(@ast.Constant)
  G(@ast.ClauseGuard)
  Z(@ast.BitArraySize)
}

///|
fn[X] push_segments(
  out : Array[Node],
  xs : ArrayView[@ast.BitArraySegment[X]],
  f : (X) -> Node,
) -> Unit {
  for s in xs {
    out.push(f(s.value))
    for o in s.options {
      if o is Size(value~, ..) {
        out.push(f(value))
      }
    }
  }
}

///|
/// The child nodes of a node, in source order.
fn node_children(node : Node) -> Array[Node] {
  let out : Array[Node] = []
  fn push_opt(x : Node?) {
    if x is Some(n) {
      out.push(n)
    }
  }

  match node {
    D(Function(f)) => {
      for a in f.arguments {
        push_opt(a.annotation.map(t => T(t)))
      }
      for s in f.body {
        out.push(S(s))
      }
      push_opt(f.return_annotation.map(t => T(t)))
    }
    D(TypeAlias(a)) => out.push(T(a.type_ast))
    D(CustomType(c)) =>
      for rc in c.constructors {
        for arg in rc.arguments {
          out.push(T(arg.ast))
        }
      }
    D(Import(_)) => ()
    D(ModuleConstant(c)) => {
      push_opt(c.annotation.map(t => T(t)))
      out.push(C(c.value))
    }
    S(Expression(e)) => out.push(E(e))
    S(Assignment(a)) => {
      out.push(E(a.value))
      out.push(P(a.pattern))
      push_opt(a.annotation.map(t => T(t)))
      if a.kind is Assert(message=Some(m), ..) {
        out.push(E(m))
      }
    }
    S(Use(u)) => {
      out.push(E(u.call))
      for ua in u.assignments {
        out.push(P(ua.pattern))
        push_opt(ua.annotation.map(t => T(t)))
      }
    }
    S(Assert(a)) => {
      out.push(E(a.value))
      push_opt(a.message.map(e => E(e)))
    }
    E(Int(..)) | E(Float(..)) | E(String(..)) | E(Var(..)) => ()
    E(Block(statements~, ..)) =>
      for s in statements {
        out.push(S(s))
      }
    E(Fn(arguments~, body~, return_annotation~, ..)) => {
      for a in arguments {
        push_opt(a.annotation.map(t => T(t)))
      }
      for s in body {
        out.push(S(s))
      }
      push_opt(return_annotation.map(t => T(t)))
    }
    E(List(elements~, tail~, ..)) => {
      for e in elements {
        out.push(E(e))
      }
      push_opt(tail.map(e => E(e)))
    }
    E(Call(fun~, arguments~, ..)) => {
      out.push(E(fun))
      for a in arguments {
        out.push(E(a.value))
      }
    }
    E(BinOp(left~, right~, ..)) => {
      out.push(E(left))
      out.push(E(right))
    }
    E(Pipeline(expressions~)) =>
      for e in expressions {
        out.push(E(e))
      }
    E(Case(subjects~, clauses~, ..)) => {
      for e in subjects {
        out.push(E(e))
      }
      if clauses is Some(cs) {
        for c in cs {
          for p in c.pattern {
            out.push(P(p))
          }
          for alt in c.alternative_patterns {
            for p in alt {
              out.push(P(p))
            }
          }
          push_opt(c.guard_.map(g => G(g)))
          out.push(E(c.then))
        }
      }
    }
    E(FieldAccess(container~, ..)) => out.push(E(container))
    E(Tuple(elements~, ..)) =>
      for e in elements {
        out.push(E(e))
      }
    E(TupleIndex(tuple~, ..)) => out.push(E(tuple))
    E(Todo(message~, ..)) => push_opt(message.map(e => E(e)))
    E(Panic(message~, ..)) => push_opt(message.map(e => E(e)))
    E(Echo(expression~, message~, ..)) => {
      push_opt(expression.map(e => E(e)))
      push_opt(message.map(e => E(e)))
    }
    E(BitArray(segments~, ..)) => push_segments(out, segments, e => E(e))
    E(RecordUpdate(constructor_~, record~, arguments~, ..)) => {
      out.push(E(constructor_))
      out.push(E(record.base))
      for a in arguments {
        out.push(E(a.value))
      }
    }
    E(NegateBool(value~, ..)) | E(NegateInt(value~, ..)) => out.push(E(value))
    P(Int(..))
    | P(Float(..))
    | P(String(..))
    | P(Variable(..))
    | P(Discard(..))
    | P(StringPrefix(..)) => ()
    P(BitArraySize(size)) => out.push(Z(size))
    P(Assign(pattern~, ..)) => out.push(P(pattern))
    P(List(elements~, tail~, ..)) => {
      for p in elements {
        out.push(P(p))
      }
      if tail is Some(t) {
        out.push(P(t.pattern))
      }
    }
    P(Constructor(arguments~, ..)) =>
      for a in arguments {
        out.push(P(a.value))
      }
    P(Tuple(elements~, ..)) =>
      for p in elements {
        out.push(P(p))
      }
    P(BitArray(segments~, ..)) => push_segments(out, segments, p => P(p))
    T(Constructor(c)) =>
      for t in c.arguments {
        out.push(T(t))
      }
    T(Fn(f)) => {
      for t in f.arguments {
        out.push(T(t))
      }
      out.push(T(f.return_))
    }
    T(Var(_)) | T(Hole(_)) => ()
    T(Tuple(t)) =>
      for t in t.elements {
        out.push(T(t))
      }
    C(Int(..)) | C(Float(..)) | C(String(..)) | C(Var(..)) => ()
    C(Tuple(elements~, ..)) =>
      for c in elements {
        out.push(C(c))
      }
    C(List(elements~, tail~, ..)) => {
      for c in elements {
        out.push(C(c))
      }
      push_opt(tail.map(c => C(c)))
    }
    C(Record(arguments~, ..)) =>
      if arguments is Some(xs) {
        for a in xs {
          out.push(C(a.value))
        }
      }
    C(RecordUpdate(record~, arguments~, ..)) => {
      out.push(C(record.base))
      for a in arguments {
        out.push(C(a.value))
      }
    }
    C(BitArray(segments~, ..)) => push_segments(out, segments, c => C(c))
    C(BinaryOperator(left~, right~, ..)) => {
      out.push(C(left))
      out.push(C(right))
    }
    C(Todo(message~, ..)) => push_opt(message.map(c => C(c)))
    G(Block(value~, ..)) => out.push(G(value))
    G(BinaryOperator(left~, right~, ..)) => {
      out.push(G(left))
      out.push(G(right))
    }
    G(Not(expression~, ..)) => out.push(G(expression))
    G(Var(..)) => ()
    G(TupleIndex(tuple~, ..)) => out.push(G(tuple))
    G(FieldAccess(container~, ..)) => out.push(G(container))
    G(Constant(c)) => out.push(C(c))
    Z(Int(..)) | Z(Variable(..)) => ()
    Z(BinaryOperator(left~, right~, ..)) => {
      out.push(Z(left))
      out.push(Z(right))
    }
    Z(Block(inner~, ..)) => out.push(Z(inner))
  }
  out
}

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
        let parent = node_location(node)
        for child in node_children(node) {
          if checks_children(node) && !inside(node_location(child), parent) {
            ok = false
          }
          stack.push(child)
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
      let end = @scanner.SourceText(text).end_offset()
      let stack : Array[Node] = []
      for t in r.module_.definitions {
        stack.push(D(t.definition))
      }
      let mut ok = true
      while stack.pop() is Some(node) {
        let s = node_location(node)
        if !(s.start <= s.end && s.end <= end) {
          ok = false
        }
        for child in node_children(node) {
          stack.push(child)
        }
      }
      ok
    },
    count=200,
    max_size=12,
    seed=2067,
  )
}
