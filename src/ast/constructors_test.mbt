///|
test "bit array unit constructor rejects values outside the byte range" {
  let errors = []
  for value in [-1, 256] {
    ignore(@ast.BitArrayUnit(value)) catch {
      error => errors.push(error)
    }
  }
  let last = @ast.BitArrayUnit(255)
  @expect.expect_all(e => {
    e
    .expect(errors)
    .to_equal([@ast.InvalidBitArrayUnit(-1), @ast.InvalidBitArrayUnit(256)])
    e.expect(@ast.BitArrayUnit::from_int(256)).to_equal(None)
    e.expect(@ast.BitArrayUnit::from_int(255)).to_equal(Some(last))
  })
}
