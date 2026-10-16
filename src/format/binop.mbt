///|
/// The operator's text.
fn binop(op : @ast.BinOp) -> @pretty.Doc {
  t(
    match op {
      And => "&&"
      Or => "||"
      LtInt => "<"
      LtEqInt => "<="
      LtFloat => "<."
      LtEqFloat => "<=."
      Eq => "=="
      NotEq => "!="
      GtEqInt => ">="
      GtInt => ">"
      GtEqFloat => ">=."
      GtFloat => ">."
      AddInt => "+"
      AddFloat => "+."
      SubInt => "-"
      SubFloat => "-."
      MultInt => "*"
      MultFloat => "*."
      DivInt => "/"
      DivFloat => "/."
      RemainderInt => "%"
      Concatenate => "<>"
    },
  )
}

///|
/// `BinOp::precedence` (the pipe is 6).
fn precedence(op : @ast.BinOp) -> Int32 {
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
priv enum OperatorKind {
  StringConcatenation
  Equality
  BooleanLogic
  IntComparison
  FloatComparison
  IntMath
  FloatMath
} derive(Eq)

///|
fn operator_kind(op : @ast.BinOp) -> OperatorKind {
  match op {
    Concatenate => StringConcatenation
    Eq | NotEq => Equality
    And | Or => BooleanLogic
    LtInt | LtEqInt | GtEqInt | GtInt => IntComparison
    LtFloat | LtEqFloat | GtEqFloat | GtFloat => FloatComparison
    AddInt | SubInt | MultInt | RemainderInt | DivInt => IntMath
    AddFloat | SubFloat | MultFloat | DivFloat => FloatMath
  }
}

///|
/// `BinOp::can_be_grouped_with`.
fn can_be_grouped_with(a : @ast.BinOp, b : @ast.BinOp) -> Bool {
  operator_kind(a) == operator_kind(b)
}

///|
/// The compiler's `operator_side`: wrap in a block when the operator binds
/// tighter than the side.
fn operator_side(doc : @pretty.Doc, op : Int32, side : Int32) -> @pretty.Doc {
  if op > side {
    group(wrap_block(doc))
  } else {
    doc
  }
}

///|
/// `u8::MAX` for a side that is not a binary operator.
let max_precedence : Int32 = 255
