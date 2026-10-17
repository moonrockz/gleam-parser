///|
test "deep parsed trees support indexing and balanced traversal" {
  let depth = 10000
  let result = @parser.parse_text(
    "fn f() { " + "[".repeat(depth) + "1" + "]".repeat(depth) + " }",
  )
  @expect.expect(result.has_errors()).to_be_false()
  let tree = @syntax.Tree(result)
  let mut enters = 0
  let mut leaves = 0
  @syntax.walk(
    tree.root(),
    _ => {
      enters += 1
      Continue
    },
    leave=_ => leaves += 1,
  )
  @expect.expect_all(s => {
    s.expect(enters).to_equal(depth + 4)
    s.expect(leaves).to_equal(enters)
  })
}
