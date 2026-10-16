///|
fn in_body(text : String) -> String raise {
  @format.format("pub fn f() {\n  " + text + "\n}\n")
}

///|
test "case: subjects, alternatives, guards, empty lines and comments between clauses" {
  @expect.expect_all(s => {
    s
    .expect(in_body("case x { 1 -> a\n 2 | 3 -> b\n _ -> c }"))
    .to_equal(
      "pub fn f() {\n  case x {\n    1 -> a\n    2 | 3 -> b\n    _ -> c\n  }\n}\n",
    )
    s
    .expect(in_body("case x, y { 1, 2 -> a\n _, _ -> b }"))
    .to_equal(
      "pub fn f() {\n  case x, y {\n    1, 2 -> a\n    _, _ -> b\n  }\n}\n",
    )
    s
    .expect(in_body("case x { n if n > 1 && !{n == 3} -> a\n _ -> b }"))
    .to_equal(
      "pub fn f() {\n  case x {\n    n if n > 1 && !{ n == 3 } -> a\n    _ -> b\n  }\n}\n",
    )
    s
    .expect(in_body("case x {\n  1 -> a\n\n  // c\n  _ -> b\n  // end\n}"))
    .to_equal(
      "pub fn f() {\n  case x {\n    1 -> a\n\n    // c\n    _ -> b\n    // end\n  }\n}\n",
    )
    s
    .expect(in_body("case x { Ok(t) if t.0 == c.d -> a\n _ -> b }"))
    .to_equal(
      "pub fn f() {\n  case x {\n    Ok(t) if t.0 == c.d -> a\n    _ -> b\n  }\n}\n",
    )
  })
}

///|
test "a clause whose patterns break puts the arrow on its own line when it has a guard" {
  inspect(
    in_body(
      "case x { Wibble(aaaaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbbbb) | Wobble(cccccccccccccccc) if y -> 1\n _ -> 2 }",
    ),
    content="pub fn f() {\n  case x {\n    Wibble(aaaaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbbbb)\n      | Wobble(cccccccccccccccc)\n      if y\n    -> 1\n    _ -> 2\n  }\n}\n",
  )
}

///|
test "clause values: a block and a nested case" {
  @expect.expect_all(s => {
    s
    .expect(in_body("case x { _ -> { a\n b } }"))
    .to_equal(
      "pub fn f() {\n  case x {\n    _ -> {\n      a\n      b\n    }\n  }\n}\n",
    )
    s
    .expect(in_body("case x { _ -> case y { _ -> 1 } }"))
    .to_equal(
      "pub fn f() {\n  case x {\n    _ ->\n      case y {\n        _ -> 1\n      }\n  }\n}\n",
    )
  })
}
