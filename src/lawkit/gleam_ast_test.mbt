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

///|
/// The variant name of a Debug form: the text before the first `(`.
fn variant(debug : String) -> String {
  debug.split("(").head().unwrap_or("").to_owned()
}

///|
/// Edge: the laws run `max_size=8`; every family must reach every kind at
/// that size, or a law passes without ever seeing some kinds.
test "every family's generator reaches every kind at the laws' size" {
  let rs = @splitmix.RandomState(seed=2026)
  let exprs : Set[String] = Set([])
  let patterns : Set[String] = Set([])
  let constants : Set[String] = Set([])
  let guards : Set[String] = Set([])
  let types : Set[String] = Set([])
  let options : Set[String] = Set([])
  for _ in 0..<600 {
    exprs.add(variant(@debug.to_string(@lawkit.gen_expr(8, rs))))
    patterns.add(variant(@debug.to_string(@lawkit.gen_pattern(8, rs))))
    constants.add(variant(@debug.to_string(@lawkit.gen_constant(8, rs))))
    guards.add(variant(@debug.to_string(@lawkit.gen_clause_guard(8, rs))))
    types.add(variant(@debug.to_string(@lawkit.gen_type_ast(8, rs))))
    for o in @lawkit.gen_bit_array_options(8, rs) {
      options.add(variant(@debug.to_string(o)))
    }
  }
  @expect.expect_all(x => {
    x.expect(exprs.length()).to_equal(21)
    x.expect(patterns.length()).to_equal(12)
    x.expect(constants.length()).to_equal(11)
    x.expect(guards.length()).to_equal(7)
    x.expect(types.length()).to_equal(5)
    x.expect(options.length()).to_equal(17)
  })
}
