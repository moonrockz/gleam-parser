///|
test "HardCommented puts one comment before every hard token, none inside an empty group" {
  let text = "fn f(a) -> Int {\n  let x = [1, ..rest]\n  let y = x |> g(1) |> h()\n  let assert Ok(z) = y as \"m\"\n  case x, y {\n    [a, ..], 1 | 2 -> #(a, 1)\n    _, _ -> #()\n  }\n}\n"
  let hard = @lawkit.HardCommented::of(@lawkit.GleamModule(text))
  let comments = hard.comments()
  @expect.expect_all(s => {
    // `)` after `a`, `->`, `..`, `]`, `|>`, `)` after `1`, `|>`, `as`,
    // `..`, `]`, `|`, `)` after `1`: 12; `h()` and `#()` get none, nor the
    // two `->` before a tuple, nor the `let` pattern `Ok(z)`.
    s.expect(comments.length()).to_equal(12)
    s.expect(comments[0]).to_equal("// c0")
    s.expect(comments[11]).to_equal("// c11")
    s.expect(hard.text()).to_contain("Ok(z) = y")
    s.expect(hard.text()).to_contain("| 2 -> #(a, 1")
    s.expect(hard.text()).to_contain("\n// c0\n)")
    s.expect(hard.text()).to_contain("\n// c1\n->")
    s.expect(hard.text()).to_contain("h()")
    s.expect(hard.text()).to_contain("#()")
    s.expect(@scanner.tokenize_text(hard.text()).has_errors()).to_be_false()
  })
}

///|
test "HardCommented keeps the `as` of an import alias and of an assert message, not of a pattern" {
  let text = "import a as b\n\nfn f() {\n  let \"s\" as w = x\n  let assert Ok(y) = w as \"m\"\n  case x, y {\n    [z, ..] as all, _ -> all\n  }\n}\n"
  let hard = @lawkit.HardCommented::of(@lawkit.GleamModule(text))
  @expect.expect_all(s => {
    s.expect(hard.text()).to_contain("import a \n// c0\nas b")
    s.expect(hard.text()).to_contain("let \"s\" as w = x")
    s.expect(hard.text()).to_contain("Ok(y) = w \n// c1\nas \"m\"")
    s.expect(hard.text()).to_contain("[z, \n// c2\n..] as all")
  })
}

///|
test "HardCommented puts no comment inside a bit array" {
  let text = "fn f() {\n  let <<a:size(n + 1)-unit(2), b:bits>> = g(<<1:8>>)\n}\n"
  let hard = @lawkit.HardCommented::of(@lawkit.GleamModule(text))
  @expect.expect_all(s => {
    s.expect(hard.comments()).to_equal(["// c0"])
    s.expect(hard.text()).to_contain("g(<<1:8>>\n// c0\n)")
  })
}

///|
test "HardCommented puts no comment inside an attribute, so a doc comment stays attached" {
  let text = "/// Doc\n@deprecated(\"old\")\n@external(erlang, \"m\", \"f\")\n@internal\npub fn f(a) -> Int\n"
  let hard = @lawkit.HardCommented::of(@lawkit.GleamModule(text))
  @expect.expect_all(s => {
    s.expect(hard.comments()).to_equal(["// c0", "// c1"])
    s
    .expect(hard.text())
    .to_contain(
      "@deprecated(\"old\")\n@external(erlang, \"m\", \"f\")\n@internal\npub fn f(a\n// c0\n) \n// c1\n-> Int",
    )
  })
}

///|
test "HardCommented shrinks with its module and comments the smaller module again" {
  let text = "fn f() {\n  g(1)\n}\n\nfn h() {\n  k(2)\n}\n"
  let hard = @lawkit.HardCommented::of(@lawkit.GleamModule(text))
  let smaller = hard.shrink().collect()
  @expect.expect_all(s => {
    s.expect(smaller.length()).to_equal(2)
    s.expect(smaller[0].comments().length()).to_equal(1)
    s.expect(smaller[0].text()).to_contain("k(2\n// c0\n)")
  })
}
