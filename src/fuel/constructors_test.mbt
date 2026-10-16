///|
test "budget constructor reports invalid units" {
  let error = try {
    ignore(@fuel.Budget(0))
    None
  } catch {
    error => Some(error)
  }
  let budget = @fuel.Budget(1)
  @expect.expect_all(e => {
    e.expect(error).to_equal(Some(@fuel.InvalidBudget(0)))
    e.expect(@fuel.Budget::from_int(0)).to_equal(None)
    e.expect(@fuel.Budget::from_int(1)).to_equal(Some(budget))
  })
}
