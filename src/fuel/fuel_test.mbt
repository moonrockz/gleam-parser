///|
test "a budget is at least one unit" {
  @expect.expect_all(e => {
    e.expect(@fuel.Budget::new(1).map(b => b.units())).to_equal(Some(1))
    e.expect(@fuel.Budget::new(100).map(b => b.units())).to_equal(Some(100))
    e.expect(@fuel.Budget::new(0)).to_equal(None)
    e.expect(@fuel.Budget::new(-5)).to_equal(None)
    e.expect(@fuel.default_budget.units()).to_equal(100)
  })
}

///|
test "spend takes one unit per nested entry and keeps the receiver" {
  let b = @fuel.Budget::new(3).unwrap()
  let f0 = @fuel.Fuel(budget=b)
  let f1 = f0.spend(@fuel.Operation("expression"))
  let f2 = f1.spend(@fuel.Operation("expression"))
  let f3 = f2.spend(@fuel.Operation("pattern"))
  @expect.expect_all(e => {
    e.expect(f0.left()).to_equal(3)
    e.expect(f1.left()).to_equal(2)
    e.expect(f3.left()).to_equal(0)
    e.expect(f3.budget()).to_equal(b)
    // outermost first, with counts
    e
    .expect(f3.spent())
    .to_equal([
      { operation: @fuel.Operation("expression"), levels: 2, },
      { operation: @fuel.Operation("pattern"), levels: 1, },
    ])
    e.expect(f0.left()).to_equal(3)
  })
}

///|
test "spending past the budget raises FuelExhausted with the budget and the stack" {
  let b = @fuel.Budget::new(2).unwrap()
  let f = @fuel.Fuel(budget=b)
    .spend(@fuel.Operation("expression"))
    .spend(@fuel.Operation("expression"))
  let got = try {
    f.spend(@fuel.Operation("pattern")) |> ignore
    None
  } catch {
    @fuel.FuelExhausted(budget~, spent~) => Some((budget, spent))
  }
  @expect.expect(got).to_equal(
    Some((b, [{ operation: @fuel.Operation("expression"), levels: 2, }])),
  )
}

///|
test "the default fuel is the default budget" {
  @expect.expect(@fuel.Fuel().budget()).to_equal(@fuel.default_budget)
  @expect.expect(@fuel.Fuel().left()).to_equal(100)
}
