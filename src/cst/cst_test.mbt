///|
test "definitions tile the tokens and to_source rebuilds the text" {
  let text = "import gleam/io\n\n// c\npub fn main() {\n  io.println(\"hi\")\n}\n"
  let stream = @scanner.tokenize_text(text)
  let tokens = stream.tokens
  let import_ = @cst.DefinitionCst(
    kind=Import,
    name=Some("gleam/io"),
    tokens=tokens[0:4],
  )
  let main = @cst.DefinitionCst(
    kind=Function,
    name=Some("main"),
    tokens=tokens[4:],
  )
  let cst = @cst.ModuleCst(stream, [import_, main])
  @expect.expect_all(e => {
    e.expect(cst.to_source()).to_equal(text)
    e.expect(cst.definitions.length()).to_equal(2)
    e
    .expect(cst.definitions[0].span)
    .to_equal(@span.SrcSpan::from_ints(0, 15).unwrap())
    // Trivia between two tokens belongs to the second token.
    e.expect(cst.definitions[0].to_source()).to_equal("import gleam/io")
    e
    .expect(cst.definitions[1].to_source().has_prefix("\n\n// c\npub fn"))
    .to_be_true()
    e
    .expect(cst.definitions[1].span.start)
    .to_equal(@span.ByteOffset::from_int(22).unwrap())
    e.expect(cst.definitions[1].kind).to_equal(@cst.DefinitionKind::Function)
  })
}

///|
test "a module with no tokens keeps its trivia" {
  let text = "// only a comment\n"
  let cst = @cst.ModuleCst(@scanner.tokenize_text(text), [])
  @expect.expect_all(e => {
    e.expect(cst.to_source()).to_equal(text)
    e.expect(cst.definitions.length()).to_equal(0)
  })
}

///|
test "an empty definition has the empty span" {
  let d = @cst.DefinitionCst(kind=Skipped, name=None, tokens=[][:])
  @expect.expect(d.span).to_equal(@span.SrcSpan::from_ints(0, 0).unwrap())
}

///|
test "law: a module CST over any text is lossless" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      let stream = @scanner.tokenize_text(text)
      let all = @cst.DefinitionCst(
        kind=Skipped,
        name=None,
        tokens=stream.tokens,
      )
      @cst.ModuleCst(stream, [all]).to_source() == text
    },
    count=200,
    max_size=30,
    seed=2026,
  )
}
