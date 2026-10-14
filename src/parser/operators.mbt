///|
/// An operator waiting on the operator stack of the simple precedence
/// parser (`handle_operator` in the compiler).
priv struct OpEntry {
  token : @scanner.Token
  precedence : Int32
}

///|
/// The simple precedence parser's step: `None` as `next` means the input
/// ended. All operators are left associative. Returns the fully reduced
/// expression at the end, `None` while operators remain or when the
/// expression stack is empty.
fn[A] handle_operator(
  next : OpEntry?,
  opstack : Array[OpEntry],
  estack : Array[A],
  reduce : (@scanner.Token, Array[A]) -> Unit,
) -> A? {
  let mut next = next
  while true {
    match (opstack.pop(), next) {
      (None, None) => return estack.pop()
      (None, Some(operator)) => {
        opstack.push(operator)
        break
      }
      (Some(left), None) => reduce(left.token, estack)
      (Some(left), Some(right)) =>
        if left.precedence >= right.precedence {
          reduce(left.token, estack)
          next = Some(right)
        } else {
          opstack.push(left)
          opstack.push(right)
          break
        }
    }
  }
  None
}

///|
/// The expression precedence of a token: `|>` is 6; a binary operator has
/// its `BinOp` precedence; anything else is not an operator.
fn precedence(kind : @scanner.TokenKind) -> Int32? {
  if kind is Pipe {
    return Some(6)
  }
  token_to_binop(kind).map(binop_precedence)
}

///|
/// The compiler's `BinOp::precedence`.
fn binop_precedence(op : @ast.BinOp) -> Int32 {
  match op {
    Or => 1
    And => 2
    Eq | NotEq => 3
    LtInt
    | LtEqInt
    | LtFloat
    | LtEqFloat
    | GtEqInt
    | GtInt
    | GtEqFloat
    | GtFloat => 4
    Concatenate => 5
    AddInt | AddFloat | SubInt | SubFloat => 7
    MultInt | MultFloat | DivInt | DivFloat | RemainderInt => 8
  }
}

///|
/// The clause-guard precedence of a token (`Token::guard_precedence`): no
/// pipe, and `+ -` 6, `* / %` 7.
fn guard_precedence(kind : @scanner.TokenKind) -> Int32? {
  match kind {
    VbarVbar => Some(1)
    AmperAmper => Some(2)
    EqualEqual | NotEqual => Some(3)
    Less
    | LessEqual
    | LessDot
    | LessEqualDot
    | GreaterEqual
    | Greater
    | GreaterEqualDot
    | GreaterDot => Some(4)
    Concatenate => Some(5)
    Plus | PlusDot | Minus | MinusDot => Some(6)
    Star | StarDot | Slash | SlashDot | Percent => Some(7)
    _ => None
  }
}

///|
fn token_to_binop(kind : @scanner.TokenKind) -> @ast.BinOp? {
  match kind {
    VbarVbar => Some(Or)
    AmperAmper => Some(And)
    EqualEqual => Some(Eq)
    NotEqual => Some(NotEq)
    Less => Some(LtInt)
    LessEqual => Some(LtEqInt)
    Greater => Some(GtInt)
    GreaterEqual => Some(GtEqInt)
    LessDot => Some(LtFloat)
    LessEqualDot => Some(LtEqFloat)
    GreaterDot => Some(GtFloat)
    GreaterEqualDot => Some(GtEqFloat)
    Plus => Some(AddInt)
    Minus => Some(SubInt)
    PlusDot => Some(AddFloat)
    MinusDot => Some(SubFloat)
    Percent => Some(RemainderInt)
    Star => Some(MultInt)
    StarDot => Some(MultFloat)
    Slash => Some(DivInt)
    SlashDot => Some(DivFloat)
    Concatenate => Some(Concatenate)
    _ => None
  }
}

///|
fn token_to_int_operator(kind : @scanner.TokenKind) -> @ast.IntOperator? {
  match kind {
    Plus => Some(Add)
    Minus => Some(Subtract)
    Star => Some(Multiply)
    Slash => Some(Divide)
    Percent => Some(Remainder)
    _ => None
  }
}

///|
fn int_operator_precedence(op : @ast.IntOperator) -> Int32 {
  match op {
    Add | Subtract => 7
    Multiply | Divide | Remainder => 8
  }
}

///|
/// Reduce two expressions with `operator`: a pipe extends a `Pipeline`
/// (or starts one), any other operator is a `BinOp`.
fn reduce_expression(
  operator : @scanner.Token,
  estack : Array[@ast.Expr],
) -> Unit {
  guard estack.pop() is Some(right) && estack.pop() is Some(left) else {
    return
  }
  if operator.kind is Pipe {
    let expressions : Array[@ast.Expr] = match left {
      Pipeline(expressions~) => expressions.to_owned()
      other => [other]
    }
    expressions.push(right)
    estack.push(Pipeline(expressions=expressions[:]))
  } else if token_to_binop(operator.kind) is Some(op) {
    estack.push(
      BinOp(
        location=sp(left.location().start, right.location().end),
        operator=op,
        operator_start=operator.span.start,
        left~,
        right~,
      ),
    )
  }
}

///|
fn reduce_clause_guard(
  operator : @scanner.Token,
  estack : Array[@ast.ClauseGuard],
) -> Unit {
  guard estack.pop() is Some(right) && estack.pop() is Some(left) else {
    return
  }
  guard token_to_binop(operator.kind) is Some(op) else { return }
  estack.push(
    BinaryOperator(
      location=sp(left.location().start, right.location().end),
      operator=op,
      operator_start=operator.span.start,
      left~,
      right~,
    ),
  )
}

///|
fn reduce_constant(
  operator : @scanner.Token,
  estack : Array[@ast.Constant],
) -> Unit {
  guard estack.pop() is Some(right) && estack.pop() is Some(left) else {
    return
  }
  guard token_to_binop(operator.kind) is Some(op) else { return }
  estack.push(
    BinaryOperator(
      location=sp(left.location().start, right.location().end),
      operator_start=operator.span.start,
      operator=op,
      left~,
      right~,
    ),
  )
}

///|
fn reduce_bit_array_size(
  operator : @scanner.Token,
  estack : Array[@ast.BitArraySize],
) -> Unit {
  guard estack.pop() is Some(right) && estack.pop() is Some(left) else {
    return
  }
  guard token_to_int_operator(operator.kind) is Some(op) else { return }
  estack.push(
    BinaryOperator(
      location=sp(left.location().start, right.location().end),
      operator=op,
      left~,
      right~,
    ),
  )
}
