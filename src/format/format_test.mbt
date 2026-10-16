///|
test "the empty module and comment-only modules format as the compiler does" {
  @expect.expect_all(s => {
    s.expect(@format.format("\n")).to_equal("\n")
    s.expect(@format.format("")).to_equal("\n")
    s.expect(@format.format("// a\n")).to_equal("// a\n")
    s.expect(@format.format("// a\n\n// b\n")).to_equal("// a\n\n// b\n")
    s
    .expect(@format.format("//// module doc\n"))
    .to_equal("//// module doc\n\n")
    s.expect(@format.format("//// m\n\n// a\n")).to_equal("//// m\n\n// a\n")
    // A trailing doc comment with no definition is kept after the comments.
    s.expect(@format.format("/// doc\n")).to_equal("/// doc\n")
  })
}

///|
test "a syntax error raises ParseFailed with the parser's error diagnostics" {
  let failed = try {
    @format.format("pub fn (") |> ignore
    None
  } catch {
    ParseFailed(ds) => Some(ds.length())
    OutOfFuel(_) => None
  }
  debug_inspect(failed, content="Some(1)")
}

///|
test "CRLF input formats to LF output, also inside a string" {
  inspect(
    @format.format("pub fn f() {\r\n  // c\r\n  \"a\r\nb\"\r\n}\r\n"),
    content="pub fn f() {\n  // c\n  \"a\nb\"\n}\n",
  )
}

///|
test "width counts grapheme clusters at the limit: 69 two-code-point clusters stay on one line" {
  // `const ` counts 5 columns, so 11 + 69 + 1 columns fit in 80; counted
  // as code points the line would be 150 columns wide and break.
  let word = "e\u{301}".repeat(69)
  let text = "const a = \"" + word + "\"\n"
  inspect(@format.format(text) == text, content="true")
}

///|
test "width counts grapheme clusters at the limit: 70 two-code-point clusters break the line" {
  let word = "e\u{301}".repeat(70)
  inspect(
    @format.format("const a = \"" + word + "\"\n"),
    content="const a =\n  \"" + word + "\"\n",
  )
}
