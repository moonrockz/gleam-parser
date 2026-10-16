///|
test "traversal constructors reject negative indexes and depths" {
  let errors = []
  ignore(@syntax.ChildIndex(-1)) catch {
    error => errors.push(error)
  }
  ignore(@syntax.NodeDepth(-1)) catch {
    error => errors.push(error)
  }
  let root = @syntax.NodeDepth(0)
  @expect.expect_all(e => {
    e
    .expect(errors)
    .to_equal([@syntax.InvalidChildIndex(-1), @syntax.InvalidNodeDepth(-1)])
    e.expect(@syntax.NodeDepth::from_int(0)).to_equal(Some(root))
  })
}
