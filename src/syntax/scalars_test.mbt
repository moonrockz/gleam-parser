///|
test "child indexes and node depths reject negative values" {
  @expect.expect_all(e => {
    e.expect(@syntax.ChildIndex::new(-1)).to_equal(None)
    e.expect(@syntax.NodeDepth::new(-1)).to_equal(None)
    for value in [0, 1, 2147483647] {
      e.expect(@syntax.ChildIndex::new(value).unwrap().to_int()).to_equal(value)
      e.expect(@syntax.NodeDepth::new(value).unwrap().to_int()).to_equal(value)
    }
  })
}

///|
test "law: child indexes and node depths preserve exactly non-negative integers" {
  @quickcheck.check(
    (value : Int32) => {
      let expected = if value >= 0 { Some(value) } else { None }
      @syntax.ChildIndex::new(value).map(x => x.to_int()) == expected &&
      @syntax.NodeDepth::new(value).map(x => x.to_int()) == expected
    },
    count=200,
    seed=2211,
  )
}
