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
