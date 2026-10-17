///|
suberror Failed {
  AtLeaf
} derive(Eq, Debug)

///|
async fn descend(
  runner : @work.Runner,
  depth : Int32,
  fail_at_leaf : Bool,
) -> Int32 raise Failed + nocancel {
  runner.pause()
  defer runner.pause()
  if depth == 0 {
    if fail_at_leaf {
      raise AtLeaf
    }
    0
  } else {
    descend(runner, depth - 1, fail_at_leaf) + 1
  }
}

///|
test "law: deep descent, returns and errors use the executor's loop" {
  let runner = @work.Runner()
  @expect.expect(runner.run(() => descend(runner, 100000, false))).to_equal(
    100000,
  )
  let error = try {
    ignore(runner.run(() => descend(runner, 100000, true)))
    None
  } catch {
    error => Some(error)
  }
  @expect.expect(error).to_equal(Some(AtLeaf))
}

///|
test "executors are independent and can run inside another computation" {
  let outer = @work.Runner()
  let inner = @work.Runner()
  let result = outer.run(() => {
    outer.pause()
    let value = inner.run(() => descend(inner, 10000, false))
    outer.pause()
    value + descend(outer, 10000, false)
  })
  @expect.expect(result).to_equal(20000)
}
