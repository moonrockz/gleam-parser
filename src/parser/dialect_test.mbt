///|
test "the parser honors a dialect's keyword subset and preserves scanner tokens" {
  let base = @config.Config::default()
  let dialect = {
    ..base.dialect,
    keywords: base.dialect.keywords
    .iter()
    .filter(k => k != @scanner.Keyword::Echo)
    .collect()[:],
  }
  let text = "const echo = 1\n"
  let scanned = @scanner.tokenize_text(text)
  let result = @parser.parse_module(scanned, config={ ..base, dialect, })
  @expect.expect_all(e => {
    e.expect(result.has_errors()).to_be_false()
    e.expect(result.module_.definitions.length()).to_equal(1)
    e.expect(result.cst.tokens).to_equal(scanned.tokens)
    e.expect(result.cst.to_source()).to_equal(text)
    e.expect(@parser.parse_text(text).has_errors()).to_be_true()
  })
}

///|
test "every omitted keyword can be an expression name" {
  let base = @config.Config::default()
  @expect.expect_all(e => {
    for keyword in base.dialect.keywords {
      let dialect = {
        ..base.dialect,
        keywords: base.dialect.keywords
        .iter()
        .filter(k => k != keyword)
        .collect()[:],
      }
      let success = try {
        match
          @parser.parse_expression_text(keyword.text(), config={
            ..base,
            dialect,
          }) {
          Var(name~, ..) => name == keyword.text()
          _ => false
        }
      } catch {
        _ => false
      }
      e.expect((keyword, success)).to_equal((keyword, true))
    }
  })
}

///|
test "recovery ignores definition keywords omitted by the dialect" {
  let base = @config.Config::default()
  let dialect = {
    ..base.dialect,
    keywords: base.dialect.keywords
    .iter()
    .filter(k => k != @scanner.Keyword::Const)
    .collect()[:],
  }
  let text = "fn bad() { + }\nconst gap = 1\nfn kept() { 1 }\n"
  let result = @parser.parse_text(text, config={ ..base, dialect, })
  @expect.expect_all(e => {
    e.expect(result.has_errors()).to_be_true()
    e.expect(result.module_.definitions.length()).to_equal(1)
    e.expect(result.cst.definitions.length()).to_equal(2)
    e
    .expect(result.cst.definitions[0].to_source().contains("const gap"))
    .to_be_true()
    e.expect(result.cst.to_source()).to_equal(text)
  })
}
