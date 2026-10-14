///|
test "GleamText reaches every edge piece and shrinks toward fewer pieces" {
  let seen : Set[String] = Set::new()
  let rs = @splitmix.RandomState::new(seed=2026)
  for _ in 0..<2000 {
    let t : @lawkit.GleamText = @quickcheck.Arbitrary::arbitrary(12, rs)
    for p in t.0 {
      seen.add(p)
    }
  }
  @expect.expect_all(e => {
    for edge in @lawkit.edge_chars() {
      e.expect(seen.contains(edge)).to_be_true()
    }
    e.expect(seen.contains("\"")).to_be_true()
    e.expect(seen.contains("//")).to_be_true()
    e.expect(seen.contains("0x")).to_be_true()
  })
  let t = @lawkit.GleamText(["ab", "c"])
  let shrunk = @quickcheck.Shrink::shrink(t).collect()
  @expect.expect(shrunk.length()).to_equal(3)
}

///|
test "GleamTokens text has one space between lexemes" {
  let t = @lawkit.GleamTokens([("fn", "Keyword(Fn)"), ("x", "Name")])
  @expect.expect_all(e => {
    e.expect(t.text()).to_equal("fn x")
    e.expect(t.expected()).to_equal(["Keyword(Fn)", "Name"])
  })
}
