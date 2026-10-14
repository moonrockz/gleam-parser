///|
test "version() has three numeric parts" {
  let parts = @gleam.version().split(".").collect()
  @expect.expect(parts.length()).to_equal(3)
  for part in parts {
    @expect.expect(part.length() > 0).to_be_true()
  }
}

///|
test "the root package parses, reports and renders" {
  let text = "pub fn main() {\n  1 +\n}\n\nconst x = 1\n"
  let r = @gleam.parse_text(text)
  let source = @gleam.SourceText::new(text)
  @expect.expect_all(e => {
    e.expect(r.module_.definitions.length()).to_equal(1)
    e.expect(r.has_errors()).to_be_true()
    e.expect(r.diagnostics[0].kind).to_equal("OpNakedRight")
    e.expect(r.cst.to_source()).to_equal(text)
    e
    .expect(
      @gleam.render_plain(r.diagnostics[0], source, "src/main.gleam").has_prefix(
        "error: Syntax error\n  ┌─ src/main.gleam:2:5\n",
      ),
    )
    .to_be_true()
    e
    .expect(
      @gleam.encode_diagnostics(r.diagnostics)
      .stringify()
      .has_prefix("[{\"code\":\"GL-PARSE-001\""),
    )
    .to_be_true()
    e.expect(@gleam.Dialect::gleam_1_19().name).to_equal("gleam-1.19")
    e
    .expect(@gleam.parse_module(@gleam.tokenize_text(text)).parsed())
    .to_equal(r.parsed())
  })
}
