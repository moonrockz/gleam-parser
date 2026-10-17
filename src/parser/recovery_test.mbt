///|
test "recovery discards deprecations and trailing commas from a failed definition" {
  let text = "fn bad() {\n  let ys = [1, 2,]\n  [head..xs] +\n}\nconst kept = [4,]\n"
  let result = @parser.parse_text(text)
  let commas = @scanner.tokenize_text(text).tokens.filter(t => t.lexeme == ",")
  @expect.expect_all(e => {
    e.expect(result.has_errors()).to_be_true()
    e.expect(result.module_.definitions.length()).to_equal(1)
    e.expect(result.warnings).to_equal([][:])
    e
    .expect(result.extra.trailing_commas)
    .to_equal([commas.last().unwrap().span.end][:])
    e.expect(result.cst.to_source()).to_equal(text)
  })
}

///|
test "recovery discards detached-doc warnings discovered in a failed definition" {
  let broken = "/// broken docs\n// detach\nfn bad() { + }\n"
  let kept = "/// kept docs\n// detach\nfn kept() { 1 }\n"
  let result = @parser.parse_text(broken + kept)
  let expected = @parser.parse_text(kept)
  guard expected.warnings is [DetachedDocComment(location~)] else {
    fail("the kept definition must have one detached-doc warning")
  }
  let shift = @scanner.SourceText(broken).byte_length().to_int()
  let span = @span.SrcSpan::from_offsets(
    location.start.shift(shift).unwrap(),
    location.end.shift(shift).unwrap(),
  ).unwrap()
  @expect.expect(result.warnings).to_equal(
    [@ast.Warning::DetachedDocComment(location=span)][:],
  )
}

///|
test "law: a failed definition does not change a following module's metadata" {
  let broken = "fn bad() { let ys = [1, 2,]\n [head..xs] + }\n"
  let delta = @scanner.SourceText(broken).byte_length().to_int()
  @quickcheck.check(
    (module_ : @lawkit.GleamModule) => {
      let text = module_.text()
      let valid = @parser.parse_text(text)
      // Valid generated modules must parse, and deliberately have no deprecations.
      if valid.has_errors() || valid.warnings.length() != 0 {
        return false
      }
      let recovered = @parser.parse_text(broken + text)
      recovered.has_errors() &&
      recovered.warnings.length() == 0 &&
      recovered.module_.definitions.length() ==
      valid.module_.definitions.length() &&
      recovered.extra.trailing_commas ==
      valid.extra.trailing_commas.map(p => p.shift(delta).unwrap())[:] &&
      recovered.cst.to_source() == broken + text
    },
    count=80,
    max_size=5,
    seed=2403,
  )
}

///|
test "recovery preserves metadata of successful definitions before and after failure" {
  let before = "fn before() { let ys = [1,]\n [left..xs] }\n"
  let broken = "fn bad() { let ys = [3,]\n [middle..xs] + }\n"
  let after = "fn after() { let ys = [5,]\n [right..xs] }\n"
  let text = before + broken + after
  let tokens = @scanner.tokenize_text(text).tokens
  let spreads = tokens.filter(t => t.lexeme == "..").map(t => t.span)
  let commas = tokens.filter(t => t.lexeme == ",").map(t => t.span.end)
  guard spreads.length() == 3 && commas.length() == 3 else {
    fail("fixture must contain three spreads and commas")
  }
  let result = @parser.parse_text(text)
  @expect.expect_all(e => {
    e.expect(result.module_.definitions.length()).to_equal(2)
    e
    .expect(result.warnings)
    .to_equal(
      [
        @ast.Warning::DeprecatedListPrepend(location=spreads[0]),
        @ast.Warning::DeprecatedListPrepend(location=spreads[2]),
      ][:],
    )
    e.expect(result.extra.trailing_commas).to_equal([commas[0], commas[2]][:])
    e.expect(result.cst.to_source()).to_equal(text)
  })
}
