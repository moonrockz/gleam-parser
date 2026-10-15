///|
/// A long left-nested operator chain has no syntactic nesting, so the
/// parser accepts it; the codec must round-trip the deep AST it builds.
test "a 2000-term operator chain parses and round-trips on every target" {
  let sb = StringBuilder()
  sb.write_string("fn f() {\n  1")
  for _ in 0..<2000 {
    sb.write_string(" + 1")
  }
  sb.write_string("\n}\n")
  let r = @parser.parse_text(sb.to_string())
  @expect.expect_all(e => {
    e.expect(r.diagnostics.map(d => d.code)).to_equal([])
    e.expect(r.module_.definitions.length()).to_equal(1)
    let parsed = r.parsed()
    let text = @ast.canonical(@ast.encode_parsed(parsed))
    let back = @ast.canonical(
      @ast.encode_parsed(@ast.decode_parsed(@ast.encode_parsed(parsed))),
    ) catch {
      _ => "decode failed"
    }
    e.expect(back == text).to_be_true()
  })
}
