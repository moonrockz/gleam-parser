///|
test "gleam-1.19 knows the compiler's attributes, targets and keywords" {
  let d = @dialect.Dialect::gleam_1_19()
  @expect.expect_all(e => {
    e.expect(d.name).to_equal("gleam-1.19")
    e.expect(d.keywords.length()).to_equal(22)
    e.expect(d.keywords.contains("opaque")).to_be_true()
    e
    .expect(d.attributes)
    .to_equal(["external", "target", "deprecated", "internal"][:])
    e.expect(d.targets).to_equal(["erlang", "javascript"][:])
    e.expect(d.knows_attribute("internal")).to_be_true()
    e.expect(d.knows_attribute("inline")).to_be_false()
    e.expect(d.knows_target("javascript")).to_be_true()
    e.expect(d.knows_target("js")).to_be_false()
    e.expect(d.deprecations.length()).to_equal(7)
    e.expect(d.warns(DeprecatedListPrepend)).to_be_true()
  })
}

///|
test "a dialect without a rule does not warn about it" {
  let base = @dialect.Dialect::gleam_1_19()
  let quiet = { ..base, deprecations: [][:], }
  @expect.expect_all(e => {
    e.expect(quiet.warns(DeprecatedTargetShorthand)).to_be_false()
    e.expect(@dialect.Rule::all().length()).to_equal(7)
    e
    .expect(@dialect.Rule::DeprecatedEmptyClauseGuard.name())
    .to_equal("deprecated-empty-clause-guard")
  })
}
