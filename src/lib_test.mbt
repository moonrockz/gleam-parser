///|
test "version() has three numeric parts" {
  let parts = @gleam.version().split(".").collect()
  @expect.expect(parts.length()).to_equal(3)
  for part in parts {
    @expect.expect(part.length() > 0).to_be_true()
  }
}
