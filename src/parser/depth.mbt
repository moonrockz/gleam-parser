///|
/// The JSON path depth of `$.module.definitions[i].definition`: the steps the
/// decoder counts before a definition's own fields.
pub let definition_root_depth : Int32 = 4

///|
/// A node of the AST, for the depth walk.
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
/// For a node: the deepest leaf path inside its own JSON object (steps from
/// the object to a scalar: `.location.start` is 2, `.name.location.start`
/// is 3, `.parameters[k].location.start` is 4), and its child nodes with
/// the steps from the object to the child's object (`.left` is 1,
/// `.elements[k]` is 2, `.arguments[k].value` is 3). Wrapper objects
/// (call arguments, segments, options, clauses, constructors) are folded
/// into the steps and the leaf depth. Keep this in step with
/// `src/ast/encode.mbt`; the boundary law in Task 7 checks it against the
/// decoder.
fn deeper(leaf : Ref[Int32], n : Int32) -> Unit {
  if n > leaf.val {
    leaf.val = n
  }
}

///|
fn[A] push_list(
  children : Array[(Int32, Node)],
  xs : ArrayView[A],
  steps : Int32,
  f : (A) -> Node,
) -> Unit {
  for x in xs {
    children.push((steps, f(x)))
  }
}

///|
fn push_opt(children : Array[(Int32, Node)], x : Node?, steps : Int32) -> Unit {
  if x is Some(n) {
    children.push((steps, n))
  }
}

///|
fn[X] push_segments(
  children : Array[(Int32, Node)],
  leaf : Ref[Int32],
  xs : ArrayView[@ast.BitArraySegment[X]],
  f : (X) -> Node,
) -> Unit {
  for s in xs {
    deeper(leaf, 4)
    children.push((3, f(s.value)))
    for o in s.options {
      deeper(leaf, 6)
      if o is Size(value~, ..) {
        children.push((5, f(value)))
      }
    }
  }
}

///|
fn[X] push_call_args(
  children : Array[(Int32, Node)],
  leaf : Ref[Int32],
  xs : ArrayView[@ast.CallArg[X]],
  f : (X) -> Node,
) -> Unit {
  for a in xs {
    deeper(leaf, 4)
    children.push((3, f(a.value)))
  }
}

///|
fn[X] push_update_args(
  children : Array[(Int32, Node)],
  leaf : Ref[Int32],
  xs : ArrayView[@ast.RecordUpdateArg[X]],
  f : (X) -> Node,
) -> Unit {
  for a in xs {
    deeper(leaf, 4)
    children.push((3, f(a.value)))
  }
}

///|
fn push_args(
  children : Array[(Int32, Node)],
  leaf : Ref[Int32],
  xs : ArrayView[@ast.Arg],
) -> Unit {
  for a in xs {
    deeper(leaf, 5)
    push_opt(children, a.annotation.map(t => T(t)), 3)
  }
}

///|
fn node_shape(node : Node) -> (Int32, Array[(Int32, Node)]) {
  let children : Array[(Int32, Node)] = []
  let leaf : Ref[Int32] = { val: 2, }
  match node {
    D(Function(f)) => {
      if f.name is Some(_) ||
        f.external_erlang is Some(_) ||
        f.external_javascript is Some(_) ||
        f.publicity is Internal(attribute_location=Some(_)) {
        deeper(leaf, 3)
      }
      push_args(children, leaf, f.arguments)
      push_list(children, f.body, 2, s => S(s))
      push_opt(children, f.return_annotation.map(t => T(t)), 1)
    }
    D(TypeAlias(a)) => {
      if a.publicity is Internal(attribute_location=Some(_)) {
        deeper(leaf, 3)
      }
      if a.parameters.length() > 0 {
        deeper(leaf, 4)
      }
      children.push((1, T(a.type_ast)))
    }
    D(CustomType(c)) => {
      if c.publicity is Internal(attribute_location=Some(_)) ||
        c.external_erlang is Some(_) ||
        c.external_javascript is Some(_) {
        deeper(leaf, 3)
      }
      if c.parameters.length() > 0 {
        deeper(leaf, 4)
      }
      for rc in c.constructors {
        // `.constructors[k].location.start`
        deeper(leaf, 4)
        for arg in rc.arguments {
          // `.constructors[k].arguments[m].location.start`, and the label's
          // `.label.location.start` one deeper.
          deeper(leaf, 6)
          if arg.label is Some(_) {
            deeper(leaf, 7)
          }
          children.push((5, T(arg.ast)))
        }
      }
    }
    D(Import(i)) => {
      if i.as_name is Some(_) {
        deeper(leaf, 3)
      }
      if i.unqualified_values.length() > 0 || i.unqualified_types.length() > 0 {
        deeper(leaf, 4)
      }
    }
    D(ModuleConstant(c)) => {
      if c.publicity is Internal(attribute_location=Some(_)) {
        deeper(leaf, 3)
      }
      push_opt(children, c.annotation.map(t => T(t)), 1)
      children.push((1, C(c.value)))
    }
    S(Expression(e)) => {
      leaf.val = 1
      children.push((1, E(e)))
    }
    S(Assignment(a)) => {
      if a.kind is Assert(..) {
        deeper(leaf, 3)
      }
      children.push((1, E(a.value)))
      children.push((1, P(a.pattern)))
      push_opt(children, a.annotation.map(t => T(t)), 1)
      if a.kind is Assert(message=Some(m), ..) {
        children.push((2, E(m)))
      }
    }
    S(Use(u)) => {
      children.push((1, E(u.call)))
      for ua in u.assignments {
        deeper(leaf, 4)
        children.push((3, P(ua.pattern)))
        push_opt(children, ua.annotation.map(t => T(t)), 3)
      }
    }
    S(Assert(a)) => {
      children.push((1, E(a.value)))
      push_opt(children, a.message.map(e => E(e)), 1)
    }
    E(Int(..)) | E(Float(..)) | E(String(..)) | E(Var(..)) => ()
    E(Block(statements~, ..)) => push_list(children, statements, 2, s => S(s))
    E(Fn(arguments~, body~, return_annotation~, ..)) => {
      deeper(leaf, 3)
      push_args(children, leaf, arguments)
      push_list(children, body, 2, s => S(s))
      push_opt(children, return_annotation.map(t => T(t)), 1)
    }
    E(List(elements~, tail~, ..)) => {
      push_list(children, elements, 2, e => E(e))
      push_opt(children, tail.map(e => E(e)), 1)
    }
    E(Call(fun~, arguments~, ..)) => {
      children.push((1, E(fun)))
      push_call_args(children, leaf, arguments, e => E(e))
    }
    E(BinOp(left~, right~, ..)) => {
      children.push((1, E(left)))
      children.push((1, E(right)))
    }
    E(Pipeline(expressions~)) => {
      leaf.val = 1
      push_list(children, expressions, 2, e => E(e))
    }
    E(Case(subjects~, clauses~, ..)) => {
      push_list(children, subjects, 2, e => E(e))
      if clauses is Some(cs) {
        for c in cs {
          deeper(leaf, 4)
          push_list(children, c.pattern, 4, p => P(p))
          for alt in c.alternative_patterns {
            push_list(children, alt, 5, p => P(p))
          }
          push_opt(children, c.guard_.map(g => G(g)), 3)
          children.push((3, E(c.then)))
        }
      }
    }
    E(FieldAccess(container~, ..)) => children.push((1, E(container)))
    E(Tuple(elements~, ..)) => push_list(children, elements, 2, e => E(e))
    E(TupleIndex(tuple~, ..)) => children.push((1, E(tuple)))
    E(Todo(kind~, message~, ..)) => {
      if kind is EmptyFunction(..) {
        deeper(leaf, 3)
      }
      push_opt(children, message.map(e => E(e)), 1)
    }
    E(Panic(message~, ..)) => push_opt(children, message.map(e => E(e)), 1)
    E(Echo(expression~, message~, ..)) => {
      push_opt(children, expression.map(e => E(e)), 1)
      push_opt(children, message.map(e => E(e)), 1)
    }
    E(BitArray(segments~, ..)) =>
      push_segments(children, leaf, segments, e => E(e))
    E(RecordUpdate(constructor_~, record~, arguments~, ..)) => {
      deeper(leaf, 3)
      children.push((1, E(constructor_)))
      children.push((2, E(record.base)))
      push_update_args(children, leaf, arguments, e => E(e))
    }
    E(NegateBool(value~, ..)) | E(NegateInt(value~, ..)) =>
      children.push((1, E(value)))
    P(Int(..))
    | P(Float(..))
    | P(String(..))
    | P(Variable(..))
    | P(Discard(..)) => ()
    P(BitArraySize(size)) => {
      leaf.val = 1
      children.push((1, Z(size)))
    }
    P(Assign(pattern~, ..)) => children.push((1, P(pattern)))
    P(List(elements~, tail~, ..)) => {
      push_list(children, elements, 2, p => P(p))
      if tail is Some(t) {
        deeper(leaf, 3)
        children.push((2, P(t.pattern)))
      }
    }
    P(Constructor(arguments~, module_~, ..)) => {
      if module_ is Some(_) {
        deeper(leaf, 3)
      }
      push_call_args(children, leaf, arguments, p => P(p))
    }
    P(Tuple(elements~, ..)) => push_list(children, elements, 2, p => P(p))
    P(BitArray(segments~, ..)) =>
      push_segments(children, leaf, segments, p => P(p))
    P(StringPrefix(left_side_assignment~, ..)) =>
      if left_side_assignment is Some(_) {
        deeper(leaf, 3)
      }
    T(Constructor(c)) => {
      // `.name.location.start` is 3; a qualified name with a type name has
      // `.name.name.location.start`.
      deeper(leaf, 3)
      if c.name is Qualified(name=Some(_), ..) {
        deeper(leaf, 4)
      }
      push_list(children, c.arguments, 2, t => T(t))
    }
    T(Fn(f)) => {
      push_list(children, f.arguments, 2, t => T(t))
      children.push((1, T(f.return_)))
    }
    T(Var(_)) | T(Hole(_)) => ()
    T(Tuple(t)) => push_list(children, t.elements, 2, t => T(t))
    C(Int(..)) | C(Float(..)) | C(String(..)) => ()
    C(Tuple(elements~, ..)) => push_list(children, elements, 2, c => C(c))
    C(List(elements~, tail~, ..)) => {
      push_list(children, elements, 2, c => C(c))
      push_opt(children, tail.map(c => C(c)), 1)
    }
    C(Record(arguments~, module_~, ..)) => {
      if module_ is Some(_) {
        deeper(leaf, 3)
      }
      if arguments is Some(xs) {
        push_call_args(children, leaf, xs, c => C(c))
      }
    }
    C(RecordUpdate(record~, arguments~, ..)) => {
      deeper(leaf, 3)
      children.push((2, C(record.base)))
      push_update_args(children, leaf, arguments, c => C(c))
    }
    C(BitArray(segments~, ..)) =>
      push_segments(children, leaf, segments, c => C(c))
    C(Var(module_~, ..)) => if module_ is Some(_) { deeper(leaf, 3) }
    C(BinaryOperator(left~, right~, ..)) => {
      children.push((1, C(left)))
      children.push((1, C(right)))
    }
    C(Todo(message~, ..)) => push_opt(children, message.map(c => C(c)), 1)
    G(Block(value~, ..)) => children.push((1, G(value)))
    G(BinaryOperator(left~, right~, ..)) => {
      children.push((1, G(left)))
      children.push((1, G(right)))
    }
    G(Not(expression~, ..)) => children.push((1, G(expression)))
    G(Var(..)) => ()
    G(TupleIndex(tuple~, ..)) => children.push((1, G(tuple)))
    G(FieldAccess(container~, ..)) => children.push((1, G(container)))
    G(Constant(c)) => {
      leaf.val = 1
      children.push((1, C(c)))
    }
    Z(Int(..)) | Z(Variable(..)) => ()
    Z(BinaryOperator(left~, right~, ..)) => {
      children.push((1, Z(left)))
      children.push((1, Z(right)))
    }
    Z(Block(inner~, ..)) => children.push((1, Z(inner)))
  }
  (leaf.val, children)
}

///|
/// The depth of the deepest JSON path inside a definition's canonical JSON,
/// counted as the decoder counts (`@ast.max_depth`): steps from the
/// definition object to its deepest scalar. Measured with an explicit
/// stack, so a definition of any depth is safe to measure.
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("const x = 1\n")
///   // $.location.start, $.name_location.start, $.value.location.start: 3
///   inspect(@parser.json_depth(r.module_.definitions[0].definition), content="3")
/// }
/// ```
pub fn json_depth(d : @ast.Definition) -> Int32 {
  let stack : Array[(Node, Int32)] = [(D(d), 0)]
  let mut deepest = 0
  while stack.pop() is Some((node, at)) {
    let (leaf, children) = node_shape(node)
    if at + leaf > deepest {
      deepest = at + leaf
    }
    for child in children {
      stack.push((child.1, at + child.0))
    }
  }
  deepest
}

///|
/// Whether a definition's JSON would be deeper than the codec reads.
fn definition_too_deep(d : @ast.Definition) -> Bool {
  definition_root_depth + json_depth(d) > @ast.max_depth
}
