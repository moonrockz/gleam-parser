///|
test "GleamAst reaches every definition kind and every expression kind" {
  let rs = @splitmix.RandomState(seed=2026)
  let defs : Set[String] = Set([])
  let exprs : Set[String] = Set([])
  for _ in 0..<400 {
    let p = @lawkit.gen_parsed(8, rs)
    for td in p.module_.definitions {
      defs.add(
        @debug.to_string(td.definition)
        .split("(")
        .head()
        .unwrap_or("")
        .to_owned(),
      )
    }
    let e = @lawkit.gen_expr(8, rs)
    exprs.add(@debug.to_string(e).split("(").head().unwrap_or("").to_owned())
  }
  @expect.expect_all(x => {
    x.expect(defs.length()).to_equal(5)
    x.expect(exprs.length()).to_equal(21)
  })
}
