///|
test "custom types with variants, fields, parameters, opaque and external" {
  @expect.expect_all(s => {
    s
    .expect(@format.format("pub type A {\n  A\n  B(x: Int, y: String)\n}\n"))
    .to_equal("pub type A {\n  A\n  B(x: Int, y: String)\n}\n")
    s
    .expect(@format.format("type Option(a) { Some(a) None }\n"))
    .to_equal("type Option(a) {\n  Some(a)\n  None\n}\n")
    s
    .expect(@format.format("pub opaque type A { A }\n"))
    .to_equal("pub opaque type A {\n  A\n}\n")
    s.expect(@format.format("pub type Ext\n")).to_equal("pub type Ext\n")
    s
    .expect(@format.format("@external(erlang, \"m\", \"t\")\npub type Ext\n"))
    .to_equal("@external(erlang, \"m\", \"t\")\npub type Ext\n")
  })
}

///|
test "doc comments, comments and empty lines between variants are kept" {
  inspect(
    @format.format(
      "type A {\n  /// one\n  One\n\n  // two\n  Two(\n    /// f\n    f: Int,\n  )\n  // end\n}\n",
    ),
    content="type A {\n  /// one\n  One\n\n  // two\n  Two(\n    /// f\n    f: Int,\n  )\n  // end\n}\n",
  )
}

///|
test "a variant with a comment inside its empty parentheses keeps them" {
  inspect(
    @format.format("type A {\n  A(\n    // c\n  )\n}\n"),
    content="type A {\n  A(\n    // c\n  )\n}\n",
  )
}
