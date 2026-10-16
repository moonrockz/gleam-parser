///|
test "integers get underscores from five digits, floats are normalised, prefixed literals stay" {
  @expect.expect_all(s => {
    s.expect(@format.format("const a = 1234\n")).to_equal("const a = 1234\n")
    s.expect(@format.format("const a = 12345\n")).to_equal("const a = 12_345\n")
    s
    .expect(@format.format("const a = -12345\n"))
    .to_equal("const a = -12_345\n")
    s
    .expect(@format.format("const a = 1_2_3_4_5_6\n"))
    .to_equal("const a = 123_456\n")
    s
    .expect(@format.format("const a = 0xFF_FF\n"))
    .to_equal("const a = 0xFF_FF\n")
    s.expect(@format.format("const a = 1.\n")).to_equal("const a = 1.0\n")
    s.expect(@format.format("const a = 1.500\n")).to_equal("const a = 1.5\n")
    s
    .expect(@format.format("const a = 12345.0e3\n"))
    .to_equal("const a = 12_345.0e3\n")
    s
    .expect(@format.format("const a = \"x\\ty\"\n"))
    .to_equal("const a = \"x\\ty\"\n")
  })
}
