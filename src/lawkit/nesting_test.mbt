///|
test "nested builds a module with the construct at the given depth" {
  @expect.expect_all(e => {
    e.expect(@lawkit.nested(List, 3)).to_equal("fn f() {\n  [[[1]]]\n}\n")
    e.expect(@lawkit.nested(Call, 2)).to_equal("fn f() {\n  f(f(1))\n}\n")
    e
    .expect(@lawkit.nested(PatternList, 2))
    .to_equal("fn f(x) {\n  case x {\n    [[_]] -> 1\n  }\n}\n")
    e.expect(@lawkit.nested(TypeTuple, 2)).to_equal("type T =\n  #(#(Int))\n")
    e.expect(@lawkit.nested(ConstantList, 1)).to_equal("const x = [1]\n")
    e.expect(@lawkit.nested(Negation, 3)).to_equal("fn f(x) {\n  !!!x\n}\n")
    e.expect(@lawkit.Construct::all().length()).to_equal(10)
  })
}
