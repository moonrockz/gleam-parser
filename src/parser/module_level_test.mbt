///|
fn kinds(r : @parser.ParseResult) -> Array[String] {
  r.diagnostics.map(d => "\{d.code} \{d.kind}")
}

///|
test "an empty text is an empty module with no diagnostics" {
  let r = @parser.parse_text("")
  @expect.expect_all(e => {
    e.expect(r.module_.definitions.length()).to_equal(0)
    e.expect(r.diagnostics.length()).to_equal(0)
    e.expect(r.extra).to_equal(@ast.ModuleExtra::empty())
    e.expect(r.cst.to_source()).to_equal("")
    e.expect(r.has_errors()).to_be_false()
  })
}

///|
test "a broken definition is reported and skipped; the next one parses" {
  let text = "fn f( {\n  1\n}\n\npub fn g() {\n  2\n}\n"
  let r = @parser.parse_text(text)
  guard r.module_.definitions is [{ definition: Function(g), .. }] else {
    fail("definitions \{@debug.to_string(r.module_.definitions)}")
  }
  guard r.cst.definitions
    is [
      { kind: Skipped, name: None, .. },
      { kind: Function, name: Some("g"), .. },
    ] else {
    fail("cst \{@debug.to_string(r.cst.definitions)}")
  }
  @expect.expect_all(e => {
    e.expect(g.name.map(n => n.name)).to_equal(Some("g"))
    e.expect(kinds(r)).to_equal(["GL-PARSE-001 UnexpectedToken"])
    e.expect(r.diagnostics[0].span).to_equal(sp(6, 7))
    e.expect(r.cst.to_source()).to_equal(text)
    e.expect(r.cst.definitions[0].span).to_equal(sp(0, 13))
    e.expect(r.has_errors()).to_be_true()
  })
}

///|
test "a stray token after the last definition is an error and a skipped run" {
  let text = "fn f() {\n  1\n}\n}\n"
  let r = @parser.parse_text(text)
  @expect.expect_all(e => {
    e.expect(r.module_.definitions.length()).to_equal(1)
    e.expect(kinds(r)).to_equal(["GL-PARSE-001 UnexpectedToken"])
    e.expect(r.diagnostics[0].span).to_equal(sp(15, 16))
    e
    .expect(r.diagnostics[0].text)
    .to_equal(
      "Found `}`, expected one of: \n- An import, const, type, or function.",
    )
    e.expect(r.cst.definitions.length()).to_equal(2)
    e.expect(r.cst.definitions[1].kind).to_equal(@cst.DefinitionKind::Skipped)
    e.expect(r.cst.to_source()).to_equal(text)
  })
}

///|
test "a lexical error the compiler's lexer reached comes before the parse error" {
  // `;` is a lexical error; the compiler's parser sees a hole, the statement
  // sequence ends, and `}` is not found: UnexpectedEof. The lexical error
  // is reported first, as the compiler does.
  let text = "fn f() {\n  1 ;\n}\n"
  let r = @parser.parse_text(text)
  @expect.expect_all(e => {
    e
    .expect(kinds(r))
    .to_equal(["GL-SCAN-001 UnrecognizedToken", "GL-PARSE-001 UnexpectedEof"])
    e.expect(r.diagnostics[1].span).to_equal(sp(0, 0))
    e.expect(r.module_.definitions.length()).to_equal(0)
    e.expect(r.cst.to_source()).to_equal(text)
  })
}

///|
test "a lexical error between definitions is skipped and both definitions parse" {
  let text = "fn f() {\n  1\n}\n;\nfn g() {\n  2\n}\n"
  let r = @parser.parse_text(text)
  @expect.expect_all(e => {
    e.expect(kinds(r)).to_equal(["GL-SCAN-001 UnrecognizedToken"])
    e.expect(r.module_.definitions.length()).to_equal(2)
    e
    .expect(r.cst.definitions.map(d => d.kind))
    .to_equal([@cst.DefinitionKind::Function, Skipped, Function])
    e.expect(r.cst.to_source()).to_equal(text)
  })
}

///|
test "a parse error before a lexical error the lexer never reached comes first" {
  let text = "const x 1\nconst y = 'a'\n"
  let r = @parser.parse_text(text)
  @expect.expect(kinds(r)[0]).to_equal("GL-PARSE-001 UnexpectedToken")
}

///|
test "deprecated syntax parses with a warning diagnostic; a quiet dialect gives none" {
  // `[1..x]` lexes `1.` as a float, so the string form is used here.
  let text = "fn f(x) {\n  [\"a\"..x]\n}\n"
  let r = @parser.parse_text(text)
  @expect.expect_all(e => {
    e.expect(kinds(r)).to_equal(["GL-PARSE-002 DeprecatedListPrepend"])
    e.expect(r.diagnostics[0].span).to_equal(sp(16, 18))
    e
    .expect(r.warnings)
    .to_equal([@ast.Warning::DeprecatedListPrepend(location=sp(16, 18))][:])
    e.expect(r.has_errors()).to_be_false()
    e.expect(r.module_.definitions.length()).to_equal(1)
  })
  let quiet = { ..@dialect.Dialect::gleam_1_19(), deprecations: [][:], }
  let q = @parser.parse_text(text, config={
    ..@config.Config::default(),
    dialect: quiet,
  })
  @expect.expect(q.diagnostics.length()).to_equal(0)
}

///|
test "doc comments attach, detach and are shared as the compiler does" {
  let text = "/// a\n// b\nfn f() {\n  1\n}\n\n/// c\n@internal\npub fn g() {\n  /// inside\n  2\n}\n\nfn h() {\n  3\n}\n"
  let r = @parser.parse_text(text)
  guard r.module_.definitions
    is [
      { definition: Function(f), .. },
      { definition: Function(g), .. },
      { definition: Function(h), .. },
    ] else {
    fail("definitions \{@debug.to_string(r.module_.definitions)}")
  }
  @expect.expect_all(e => {
    e.expect(f.documentation).to_equal(None)
    e
    .expect(g.documentation)
    .to_equal(
      Some({ start: @span.ByteOffset::new(30).unwrap(), text: " c\n", }),
    )
    e
    .expect(h.documentation)
    .to_equal(
      Some({ start: @span.ByteOffset::new(61).unwrap(), text: " inside\n", }),
    )
    e.expect(kinds(r)).to_equal(["GL-PARSE-003 DetachedDocComment"])
    e.expect(r.diagnostics[0].span).to_equal(sp(3, 5))
    e
    .expect(r.warnings)
    .to_equal([@ast.Warning::DetachedDocComment(location=sp(3, 5))][:])
    e
    .expect(g.publicity)
    .to_equal(@ast.Publicity::Internal(attribute_location=Some(sp(33, 42))))
  })
}

///|
test "attributes and targets" {
  let text = "@target(erl)\n@deprecated(\"old\")\n@external(erlang, \"m\", \"f\")\n@external(javascript, \"./m.mjs\", \"f\")\npub fn f() -> Int\n"
  let r = @parser.parse_text(text)
  guard r.module_.definitions
    is [{ definition: Function(f), target: Some(Erlang), }] else {
    fail("definitions \{@debug.to_string(r.module_.definitions)}")
  }
  @expect.expect_all(e => {
    e
    .expect(f.deprecation)
    .to_equal(@ast.Deprecation::Deprecated(message="old"))
    e
    .expect(f.external_erlang)
    .to_equal(Some({ module_: "m", function: "f", location: sp(32, 59), }))
    e
    .expect(f.external_javascript.map(x => x.location))
    .to_equal(Some(sp(60, 97)))
    e.expect(f.body.length()).to_equal(0)
    e.expect(f.body_start).to_equal(None)
    // A function without a body ends at its `)`.
    e.expect(f.location).to_equal(sp(98, 108))
    e.expect(f.end_position).to_equal(@span.ByteOffset::new(108).unwrap())
    e.expect(kinds(r)).to_equal(["GL-PARSE-002 DeprecatedTargetShorthand"])
  })
}

///|
test "module-level errors have the compiler's kinds and spans" {
  fn first(text : String) -> (String, @span.SrcSpan) {
    let r = @parser.parse_text(text)
    for d in r.diagnostics {
      if d.is_error() {
        return (d.kind, d.span)
      }
    }
    ("ok", sp(0, 0))
  }

  @expect.expect_all(e => {
    e
    .expect(first("@inline\nfn f() {\n  1\n}\n"))
    .to_equal(("UnknownAttribute", sp(0, 7)))
    e
    .expect(first("@internal\n@internal\npub fn f() {\n  1\n}\n"))
    .to_equal(("DuplicateAttribute", sp(10, 19)))
    e
    .expect(first("@internal\nfn f() {\n  1\n}\n"))
    .to_equal(("RedundantInternalAttribute", sp(0, 9)))
    e
    .expect(first("@external(erlang, \"a\", \"b\")\nconst x = 1\n"))
    .to_equal(("ExpectedFunctionDefinition", sp(0, 27)))
    e
    .expect(first("@target(erlang)\n"))
    .to_equal(("ExpectedDefinition", sp(0, 15)))
    e
    .expect(first("@target(wasm)\nfn f() {\n  1\n}\n"))
    .to_equal(("UnknownTarget", sp(8, 12)))
    e
    .expect(first("@target()\nfn f() {\n  1\n}\n"))
    .to_equal(("ExpectedTargetName", sp(7, 8)))
    e
    .expect(first("@external\nfn f() {\n  1\n}\n"))
    .to_equal(("ExpectedExternalArguments", sp(0, 9)))
    e
    .expect(first("@deprecated\nfn f() {\n  1\n}\n"))
    .to_equal(("ExpectedDeprecationMessage", sp(0, 11)))
    e
    .expect(first("pub opaque type A =\n  Int\n"))
    .to_equal(("OpaqueTypeAlias", sp(0, 17)))
    e
    .expect(first("type Box<a> {\n  Box(a)\n}\n"))
    .to_equal(("TypeDefinitionAngleGenerics", sp(8, 9)))
    e
    .expect(first("type Box() {\n  Box\n}\n"))
    .to_equal(("TypeDefinitionNoArguments", sp(8, 10)))
    e
    .expect(first("pub type A {\n  A\n  fn f() { 1 }\n}\n"))
    .to_equal(("UnexpectedToken", sp(19, 21)))
    e
    .expect(first("pub type Wibble(a) {\n  field: Int,\n  other: a\n}\n"))
    .to_equal(("ExpectedRecordConstructor", sp(23, 45)))
    // A lower-case name alone is read as a field list: the record hint.
    e
    .expect(first("pub type A {\n  a\n}\n"))
    .to_equal(("ExpectedRecordConstructor", sp(15, 16)))
    e
    .expect(first("pub type A {\n  a b\n}\n"))
    .to_equal(("IncorrectUpName", sp(15, 16)))
    e
    .expect(first("pub type A {\n  @target(erlang)\n  A\n}\n"))
    .to_equal(("UnknownAttributeRecordVariant", sp(15, 30)))
    e
    .expect(first("import gleam.io\n"))
    .to_equal(("IncorrectImportModuleSeparator", sp(12, 13)))
    e.expect(first("import a/.{b}\n")).to_equal(("ExpectedName", sp(9, 9)))
    e.expect(first("import _a\n")).to_equal(("IncorrectName", sp(7, 9)))
    e.expect(first("const _x = 1\n")).to_equal(("IncorrectName", sp(6, 8)))
    e.expect(first("const x =\n")).to_equal(("NoValueAfterEqual", sp(8, 9)))
    e.expect(first("const x 1\n")).to_equal(("UnexpectedToken", sp(8, 9)))
    e.expect(first("fn f() {\n")).to_equal(("UnexpectedEof", sp(0, 0)))
    e.expect(first("pub type A =\n")).to_equal(("ExpectedType", sp(11, 12)))
  })
}

///|
test "a definition nested past the limit is reported and dropped; the rest parses" {
  let opens = String::make(200, '[')
  let closes = String::make(200, ']')
  let text = "fn deep() {\n  \{opens}1\{closes}\n}\n\nfn ok() {\n  1\n}\n"
  let r = @parser.parse_text(text)
  @expect.expect_all(e => {
    e.expect(kinds(r)).to_equal(["GL-PARSE-004 TooMuchNesting"])
    e.expect(r.module_.definitions.length()).to_equal(1)
    e
    .expect(r.cst.definitions.map(d => d.kind))
    .to_equal([@cst.DefinitionKind::Skipped, Function])
    e.expect(r.cst.to_source()).to_equal(text)
  })
}

///|
test "the parse result is the oracle's Parsed shape" {
  let r = @parser.parse_text("const x = 1\n")
  let p = r.parsed()
  @expect.expect_all(e => {
    e.expect(p.module_).to_equal(r.module_)
    e.expect(p.extra).to_equal(r.extra)
    e.expect(p.warnings).to_equal(r.warnings)
    e
    .expect(p.extra.new_lines.iter().map(x => x.to_int()).collect())
    .to_equal([11])
  })
}

///|
test "a lexical error the lexer reaches while reading a bad @deprecated comes first" {
  // The compiler's expect_one/expect_string consume a token when they fail,
  // so its lexer reaches the `;`.
  let r = @parser.parse_text("@deprecated a b ;\nfn f() {\n  1\n}\n")
  @expect.expect(kinds(r)[0]).to_equal("GL-SCAN-001 UnrecognizedToken")
}

///|
test "a skipped definition keeps its doc comments; the next definition gets only its own" {
  let r = @parser.parse_text(
    "/// doc c\nconst = 1\n/// doc g\nfn g() {\n  1\n}\n",
  )
  guard r.module_.definitions is [{ definition: Function(g), .. }] else {
    fail("definitions \{@debug.to_string(r.module_.definitions)}")
  }
  @expect.expect(g.documentation).to_equal(
    Some({ start: @span.ByteOffset::new(23).unwrap(), text: " doc g\n", }),
  )
}
