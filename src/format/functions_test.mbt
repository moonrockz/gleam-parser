///|
test "function heads: arguments, labels, annotations, external and attributes" {
  @expect.expect_all(s => {
    s
    .expect(
      @format.format(
        "@external(erlang, \"m\", \"f\")\npub fn f(a: Int, b b: String) -> Bool\n",
      ),
    )
    .to_equal(
      "@external(erlang, \"m\", \"f\")\npub fn f(a: Int, b b: String) -> Bool\n",
    )
    s
    .expect(
      @format.format(
        "@external(javascript, \"m\", \"f\")\nfn f(_: Int, _x: Int, l _: Int)\n",
      ),
    )
    .to_equal(
      "@external(javascript, \"m\", \"f\")\nfn f(_: Int, _x: Int, l _: Int)\n",
    )
    s
    .expect(@format.format("@deprecated(\"d\")\n@internal\npub fn f()\n"))
    .to_equal("@deprecated(\"d\")\n@internal\npub fn f()\n")
    s
    .expect(
      @format.format(
        "@external(erlang, \"m\", \"f\")\npub fn f(\n  // c\n) -> Int\n",
      ),
    )
    .to_equal("@external(erlang, \"m\", \"f\")\npub fn f(\n  // c\n) -> Int\n")
  })
}

///|
test "a long external signature breaks its arguments and keeps the return type" {
  inspect(
    @format.format(
      "@external(erlang, \"m\", \"f\")\npub fn fffffffffffffffffffffffff(aaaaaaaaaaaaaaaaaaaaa: Int, bbbbbbbbbbbbbbbbbbbb: Int) -> Int\n",
    ),
    content="@external(erlang, \"m\", \"f\")\npub fn fffffffffffffffffffffffff(\n  aaaaaaaaaaaaaaaaaaaaa: Int,\n  bbbbbbbbbbbbbbbbbbbb: Int,\n) -> Int\n",
  )
}

///|
test "a function with a body formats the body" {
  inspect(
    @format.format("pub fn f() {\n  1\n}\n"),
    content="pub fn f() {\n  1\n}\n",
  )
}
