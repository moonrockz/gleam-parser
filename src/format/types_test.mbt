///|
test "type aliases break after the equals sign; type arguments, function types and tuples" {
  @expect.expect_all(s => {
    s.expect(@format.format("type A = B\n")).to_equal("type A =\n  B\n")
    s
    .expect(@format.format("pub type A(x,y) = List(#(x, y))\n"))
    .to_equal("pub type A(x, y) =\n  List(#(x, y))\n")
    s
    .expect(@format.format("type F = fn(Int, String) -> Bool\n"))
    .to_equal("type F =\n  fn(Int, String) -> Bool\n")
    s
    .expect(@format.format("type Q = one.Two(three.Four)\n"))
    .to_equal("type Q =\n  one.Two(three.Four)\n")
    s
    .expect(@format.format("@internal\npub type A = B\n"))
    .to_equal("@internal\npub type A =\n  B\n")
    s
    .expect(@format.format("@deprecated(\"old\")\ntype A = B\n"))
    .to_equal("@deprecated(\"old\")\ntype A =\n  B\n")
  })
}

///|
test "a long type alias breaks its arguments" {
  inspect(
    @format.format(
      "type Loooooooooooooooooooooooooooooong = Result(Loooooooooooooooooooooooooooooong, Error)\n",
    ),
    content="type Loooooooooooooooooooooooooooooong =\n  Result(Loooooooooooooooooooooooooooooong, Error)\n",
  )
}

///|
test "comments inside type arguments stay before the closing parenthesis" {
  inspect(
    @format.format("type A = B(\n  C,\n  // comment\n)\n"),
    content="type A =\n  B(\n    C,\n    // comment\n  )\n",
  )
}
