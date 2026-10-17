///|
test "structural equality includes the derived float field that JSON omits" {
  let location = @span.SrcSpan(0, 3)
  let expr : @ast.Expr = Float(location~, value="1.0", float_value=1.0)
  let other_expr : @ast.Expr = Float(location~, value="1.0", float_value=2.0)
  let pattern : @ast.Pattern = Float(location~, value="1.0", float_value=1.0)
  let other_pattern : @ast.Pattern = Float(
    location~,
    value="1.0",
    float_value=2.0,
  )
  let constant : @ast.Constant = Float(location~, value="1.0", float_value=1.0)
  let other_constant : @ast.Constant = Float(
    location~,
    value="1.0",
    float_value=2.0,
  )
  @expect.expect_all(s => {
    s.expect(expr == other_expr).to_be_false()
    s.expect(pattern == other_pattern).to_be_false()
    s.expect(constant == other_constant).to_be_false()
    s
    .expect(@ast.canonical(@ast.encode_expr(expr)))
    .to_equal(@ast.canonical(@ast.encode_expr(other_expr)))
  })
  // Debug must also keep the actual field, rather than deriving it from JSON.
  debug_inspect(
    other_expr,
    content=(
      #|Float(
      #|  location={ start: { value: 0 }, end: { value: 3 } },
      #|  value="1.0",
      #|  float_value=2,
      #|)
    ),
  )
}
