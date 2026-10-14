///|
test "location of every node kind that has no location field is derived" {
  let a : @ast.Expr = Var(location=sp(0, 1), name="a")
  let b : @ast.Expr = Var(location=sp(5, 6), name="b")
  let pipeline : @ast.Expr = Pipeline(expressions=[a, b][:])
  let guard_var : @ast.ClauseGuard = Var(location=sp(10, 11), name="x")
  let access : @ast.ClauseGuard = FieldAccess(
    label_location=sp(12, 15),
    index=None,
    label="foo",
    container=guard_var,
  )
  let constant : @ast.Constant = Int(
    location=sp(20, 21),
    value="1",
    int_value=BigInt::from_int(1),
  )
  let guard_const : @ast.ClauseGuard = Constant(constant)
  let size : @ast.BitArraySize = Block(
    location=sp(30, 35),
    inner=Int(location=sp(31, 32), value="8", int_value=BigInt::from_int(8)),
  )
  let pattern_size : @ast.Pattern = BitArraySize(size)
  let statement : @ast.Statement = Expression(pipeline)
  let type_fn : @ast.TypeAst = Fn({
    location: sp(40, 50),
    arguments: [][:],
    return_: Var({ location: sp(47, 50), name: "a", }),
  })
  @expect.expect_all(e => {
    e.expect(pipeline.location()).to_equal(sp(0, 6))
    e.expect(access.location()).to_equal(sp(10, 15))
    e.expect(guard_const.location()).to_equal(sp(20, 21))
    e.expect(pattern_size.location()).to_equal(sp(30, 35))
    e.expect(statement.location()).to_equal(sp(0, 6))
    e.expect(type_fn.location()).to_equal(sp(40, 50))
    e.expect(a.location()).to_equal(sp(0, 1))
  })
}

///|
test "an assign pattern's location runs from its inner pattern to the name" {
  let inner : @ast.Pattern = Variable(location=sp(0, 1), name="x")
  let assign : @ast.Pattern = Assign(name="y", location=sp(5, 6), pattern=inner)
  @expect.expect(assign.location()).to_equal(sp(0, 6))
}
