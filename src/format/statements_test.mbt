///|
test "bodies: one expression stays with the braces broken, statements and empty lines are kept" {
  @expect.expect_all(s => {
    s
    .expect(@format.format("pub fn f() { 1 }\n"))
    .to_equal("pub fn f() {\n  1\n}\n")
    s
    .expect(@format.format("pub fn f() {\n  let x = 1\n\n\n  x\n}\n"))
    .to_equal("pub fn f() {\n  let x = 1\n\n  x\n}\n")
    s
    .expect(
      @format.format("pub fn f() {\n  let assert Ok(x) = y as \"m\"\n  x\n}\n"),
    )
    .to_equal("pub fn f() {\n  let assert Ok(x) = y as \"m\"\n  x\n}\n")
    s
    .expect(@format.format("pub fn f() {\n  let x: Int = 1\n  x\n}\n"))
    .to_equal("pub fn f() {\n  let x: Int = 1\n  x\n}\n")
    s
    .expect(@format.format("pub fn f() {\n  assert 1 == 1 as \"m\"\n}\n"))
    .to_equal("pub fn f() {\n  assert 1 == 1 as \"m\"\n}\n")
  })
}

///|
test "use: a trailing use gets a todo; assignments and annotations are kept" {
  @expect.expect_all(s => {
    s
    .expect(@format.format("pub fn f() {\n  use <- g()\n}\n"))
    .to_equal("pub fn f() {\n  use <- g()\n  todo\n}\n")
    s
    .expect(@format.format("pub fn f() {\n  use a, b: Int <- g(1)\n  a\n}\n"))
    .to_equal("pub fn f() {\n  use a, b: Int <- g(1)\n  a\n}\n")
  })
}

///|
test "a comment before an as-message puts the message on its own line" {
  inspect(
    @format.format(
      "pub fn f() {\n  let assert Ok(x) = y as\n    // why\n    \"m\"\n  x\n}\n",
    ),
    content="pub fn f() {\n  let assert Ok(x) = y as\n    // why\n    \"m\"\n  x\n}\n",
  )
}

///|
test "blocks: trailing comments stay inside; a block as a value keeps its braces" {
  @expect.expect_all(s => {
    s
    .expect(
      @format.format(
        "pub fn f() {\n  let x = {\n    1\n    // c\n  }\n  x\n}\n",
      ),
    )
    .to_equal("pub fn f() {\n  let x = {\n    1\n    // c\n  }\n  x\n}\n")
    s
    .expect(@format.format("pub fn f() {\n  { 1 }\n}\n"))
    .to_equal("pub fn f() {\n  { 1 }\n}\n")
  })
}
