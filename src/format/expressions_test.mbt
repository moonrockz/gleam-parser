///|
fn body(text : String) -> String raise {
  @format.format("pub fn f() {\n  " + text + "\n}\n")
}

///|
test "expressions: literals, vars, field access, tuple index, negations, todo, panic, echo" {
  @expect.expect_all(s => {
    s.expect(body("12345")).to_equal("pub fn f() {\n  12_345\n}\n")
    s.expect(body("a.b.c")).to_equal("pub fn f() {\n  a.b.c\n}\n")
    s.expect(body("t.0")).to_equal("pub fn f() {\n  t.0\n}\n")
    s.expect(body("{t.1}.0")).to_equal("pub fn f() {\n  t.1.0\n}\n")
    s.expect(body("!x")).to_equal("pub fn f() {\n  !x\n}\n")
    s.expect(body("!{a && b}")).to_equal("pub fn f() {\n  !{ a && b }\n}\n")
    s.expect(body("- -x")).to_equal("pub fn f() {\n  x\n}\n")
    s.expect(body("-{a + b}")).to_equal("pub fn f() {\n  -{ a + b }\n}\n")
    s
    .expect(body("todo as \"m\""))
    .to_equal("pub fn f() {\n  todo as \"m\"\n}\n")
    s.expect(body("panic")).to_equal("pub fn f() {\n  panic\n}\n")
    s.expect(body("echo x")).to_equal("pub fn f() {\n  echo x\n}\n")
    s
    .expect(body("echo x as \"m\""))
    .to_equal("pub fn f() {\n  echo x as \"m\"\n}\n")
  })
}

///|
test "calls, captures and anonymous functions" {
  @expect.expect_all(s => {
    s
    .expect(body("g(a, b: 1, c:)"))
    .to_equal("pub fn f() {\n  g(a, b: 1, c:)\n}\n")
    s.expect(body("g(_)")).to_equal("pub fn f() {\n  g\n}\n")
    s.expect(body("g(_, 1)")).to_equal("pub fn f() {\n  g(_, 1)\n}\n")
    s.expect(body("x |> g(_, 1)")).to_equal("pub fn f() {\n  x |> g(1)\n}\n")
    s.expect(body("x |> g(1, _)")).to_equal("pub fn f() {\n  x |> g(1, _)\n}\n")
    s
    .expect(body("fn(a: Int) -> Int { a }"))
    .to_equal("pub fn f() {\n  fn(a: Int) -> Int { a }\n}\n")
    s
    .expect(body("g(fn(x) {\n    x\n    x\n  })"))
    .to_equal("pub fn f() {\n  g(fn(x) {\n    x\n    x\n  })\n}\n")
  })
}

///|
test "lists, tuples, records, bit arrays and operators" {
  @expect.expect_all(s => {
    s
    .expect(body("[1, 2, ..rest]"))
    .to_equal("pub fn f() {\n  [1, 2, ..rest]\n}\n")
    s.expect(body("#(1, \"a\")")).to_equal("pub fn f() {\n  #(1, \"a\")\n}\n")
    s
    .expect(body("Rec(..base, a: 1, b:)"))
    .to_equal("pub fn f() {\n  Rec(..base, a: 1, b:)\n}\n")
    s
    .expect(body("<<1, a:size(8)-unit(1), b:utf8>>"))
    .to_equal("pub fn f() {\n  <<1, a:size(8)-unit(1), b:utf8>>\n}\n")
    s.expect(body("1 + 2 * 3")).to_equal("pub fn f() {\n  1 + 2 * 3\n}\n")
    s
    .expect(body("{ 1 + 2 } * 3"))
    .to_equal("pub fn f() {\n  { 1 + 2 } * 3\n}\n")
    s.expect(body("a |> b |> c")).to_equal("pub fn f() {\n  a |> b |> c\n}\n")
    s
    .expect(body("a\n  |> b\n  |> c"))
    .to_equal("pub fn f() {\n  a\n  |> b\n  |> c\n}\n")
    s
    .expect(body("\"a\" <> \"b\""))
    .to_equal("pub fn f() {\n  \"a\" <> \"b\"\n}\n")
  })
}

///|
test "a long call breaks its last breakable argument first; a long binary chain nests its steps" {
  @expect.expect_all(s => {
    s
    .expect(
      body(
        "g(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, [bbbbbbbbbbbbbbbbbbbbbbbb, cccccccccccccccccc])",
      ),
    )
    .to_equal(
      "pub fn f() {\n  g(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, [\n    bbbbbbbbbbbbbbbbbbbbbbbb,\n    cccccccccccccccccc,\n  ])\n}\n",
    )
    s
    .expect(
      body(
        "aaaaaaaaaaaaaaaaaaaaaaaa + bbbbbbbbbbbbbbbbbbbbbbbbbb + cccccccccccccccccccccccccc + d",
      ),
    )
    .to_equal(
      "pub fn f() {\n  aaaaaaaaaaaaaaaaaaaaaaaa\n  + bbbbbbbbbbbbbbbbbbbbbbbbbb\n  + cccccccccccccccccccccccccc\n  + d\n}\n",
    )
  })
}
