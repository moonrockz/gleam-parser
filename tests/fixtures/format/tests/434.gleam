fn clause_guard_tests(_fns) -> List(Test) {
  example(fn() {
    assert_equal(0, case Nil {
      _ if yes -> 0
      _ -> 1
    })
  })
}
