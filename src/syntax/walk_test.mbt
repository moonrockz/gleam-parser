///|
test "walk enters in pre-order, leaves after the children, and SkipChildren skips" {
  let root = root_of("pub fn f(x) {\n  x\n}\n")
  let log = []
  @syntax.walk(
    root,
    n => {
      log.push("+" + n.kind())
      if n.category() == "arg" {
        SkipChildren
      } else {
        Continue
      }
    },
    leave=n => log.push("-" + n.kind()),
  )
  @expect.expect(log.join(" ")).to_equal(
    "+module +function +arg -arg +expression +var -var -expression -function -module",
  )
}

///|
test "Stop ends the walk at once: no leave after it" {
  let root = root_of("pub fn f(x) {\n  x\n}\n")
  let log = []
  @syntax.walk(
    root,
    n => {
      log.push("+" + n.kind())
      if n.category() == "arg" {
        Stop
      } else {
        Continue
      }
    },
    leave=n => log.push("-" + n.kind()),
  )
  @expect.expect(log.join(" ")).to_equal("+module +function +arg")
}

///|
test "fold threads an accumulator through enter and leave" {
  let root = root_of("pub fn f() {\n  [[1]]\n}\n")
  let (count, _, deepest) = @syntax.fold(
    root,
    (0, 0, 0),
    (acc, n) => {
      let (count, depth, deepest) = acc
      let count = count + (if n.category() == "expression" { 1 } else { 0 })
      let depth = depth + 1
      let deepest = if depth > deepest { depth } else { deepest }
      ((count, depth, deepest), Continue)
    },
    leave=(acc, _) => (acc.0, acc.1 - 1, acc.2),
  )
  @expect.expect_all(e => {
    e.expect(count).to_equal(3)
    e.expect(deepest).to_equal(6)
  })
}

///|
fn deep_list(n : Int32) -> @syntax.NodeRef {
  let sp = @span.SrcSpan::from_ints(0, 1).unwrap()
  let mut deep : @ast.Expr = Int(
    location=sp,
    value="1",
    int_value=BigInt::from_int(1),
  )
  for _ in 0..<n {
    deep = List(location=sp, elements=[deep][:], tail=None)
  }
  @syntax.NodeRef::Expr(deep)
}

///|
test "a walk of 3000 nested lists runs on every target" {
  let mut n = 0
  @syntax.walk(deep_list(3000), _ => {
    n += 1
    Continue
  })
  @expect.expect(n).to_equal(3001)
}
