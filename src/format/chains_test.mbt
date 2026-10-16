///|
/// A long flat chain has no syntactic nesting: the parser accepts it, so
/// the formatter must format it on every target, with no fuel spent per
/// link and no recursion per link (wasm overflows at about 1500 frames).
fn repeat_join(piece : String, n : Int32, sep : String) -> String {
  let parts = []
  for _ in 0..<n {
    parts.push(piece)
  }
  parts.join(sep)
}

///|
test "a 2000-term operator chain formats one term per line on every target" {
  let text = "pub fn f() {\n  " + repeat_join("1", 2000, " + ") + "\n}\n"
  let expected = "pub fn f() {\n  1" + "\n  + 1".repeat(1999) + "\n}\n"
  inspect(@format.format(text) == expected, content="true")
}

///|
test "a 2000-term constant operator chain formats on every target" {
  let text = "const x = " + repeat_join("1", 2000, " + ") + "\n"
  let expected = "const x =\n  1" + "\n  + 1".repeat(1999) + "\n"
  inspect(@format.format(text) == expected, content="true")
}

///|
test "500-deep field access, tuple index and call chains format on every target" {
  @expect.expect_all(s => {
    let field = "pub fn f() {\n  a" + ".b".repeat(500) + "\n}\n"
    s.expect(@format.format(field) == field).to_equal(true)
    let index = "pub fn f() {\n  a" + ".0".repeat(500) + "\n}\n"
    s.expect(@format.format(index) == index).to_equal(true)
    let call = "pub fn f() {\n  a" + "()".repeat(500) + "\n}\n"
    s.expect(@format.format(call) == call).to_equal(true)
  })
}

///|
test "a 1000-step guard chain and a 1000-term bit array size format on every target" {
  @expect.expect_all(s => {
    let guard_text = "pub fn f() {\n  case x {\n    _ if " +
      repeat_join("a", 1000, " || ") +
      " -> 1\n  }\n}\n"
    let guard_expected = "pub fn f() {\n  case x {\n    _\n      if a" +
      "\n      || a".repeat(999) +
      "\n    -> 1\n  }\n}\n"
    s.expect(@format.format(guard_text) == guard_expected).to_equal(true)
    let size_text = "pub fn f() {\n  case x {\n    <<a:size(" +
      repeat_join("1", 1000, " + ") +
      ")>> -> 1\n  }\n}\n"
    let size_expected = "pub fn f() {\n  case x {\n    <<\n      a:size(" +
      repeat_join("1", 1000, " + ") +
      "),\n    >> -> 1\n  }\n}\n"
    s.expect(@format.format(size_text) == size_expected).to_equal(true)
  })
}
