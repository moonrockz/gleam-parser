///|
test "oracle output: a parsed module and an error round-trip" {
  let ok : @ast.OracleOutput = Parsed({
    module_: { definitions: [][:], },
    extra: @ast.ModuleExtra::empty(),
    warnings: [][:],
  })
  let err : @ast.OracleOutput = Error(
    kind="LexError",
    lexical_kind=Some("BadStringEscape"),
    location=@span.SrcSpan::new(3, 4).unwrap(),
  )
  @expect.expect_all(e => {
    e
    .expect(@ast.canonical(@ast.encode_oracle_output(err)))
    .to_equal(
      (
        #|{"error":{"kind":"LexError","lexical_kind":"BadStringEscape","location":{"end":4,"start":3}}}
      ),
    )
    e
    .expect(@ast.canonical(@ast.encode_oracle_output(ok)))
    .to_equal(
      (
        #|{"extra":{"comments":[],"doc_comments":[],"empty_lines":[],"module_comments":[],"new_lines":[],"trailing_commas":[]},"module":{"definitions":[]},"warnings":[]}
      ),
    )
    e
    .expect(
      @ast.decode_oracle_output(
        @json.parse(@ast.canonical(@ast.encode_oracle_output(err))),
      ),
    )
    .to_equal(err)
    e
    .expect(
      @ast.decode_oracle_output(
        @json.parse(@ast.canonical(@ast.encode_oracle_output(ok))),
      ),
    )
    .to_equal(ok)
  })
}
