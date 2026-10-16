///|
test "bounded AST scalars reject invalid construction" {
  @expect.expect_all(e => {
    for value in [-2147483648, -1, 256, 2147483647] {
      e.expect(@ast.BitArrayUnit::new(value)).to_equal(None)
    }
    for value in [0, 1, 255] {
      e.expect(@ast.BitArrayUnit::new(value).unwrap().to_int()).to_equal(value)
    }
    e.expect(@ast.TupleIndex::new(-1L)).to_equal(None)
    e.expect(@ast.TupleIndex::new(-9223372036854775808L)).to_equal(None)
    e.expect(@ast.TupleIndex::new(0L).unwrap().to_uint64()).to_equal(0UL)
    e
    .expect(@ast.TupleIndex::TupleIndex(18446744073709551615UL).to_uint64())
    .to_equal(18446744073709551615UL)
  })
}

///|
test "law: bit array units exist exactly in the byte range" {
  @quickcheck.check(
    (value : Int32) => {
      match @ast.BitArrayUnit::new(value) {
        Some(unit) => value >= 0 && value <= 255 && unit.to_int() == value
        None => value < 0 || value > 255
      }
    },
    count=200,
    seed=2210,
  )
}

///|
test "law: tuple indexes keep every unsigned digit through JSON" {
  @quickcheck.check(
    (value : UInt64) => {
      let span = @span.SrcSpan::new(0, 1).unwrap()
      let expr : @ast.Expr = TupleIndex(
        location=span,
        index=@ast.TupleIndex(value),
        tuple=Var(location=span, name="x"),
      )
      try {
        let text = @ast.canonical(@ast.encode_expr(expr))
        @ast.decode_expr(@json.parse(text)) == expr
      } catch {
        _ => false
      }
    },
    count=100,
    seed=2212,
  )
}
