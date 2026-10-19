///|
test "a registered target restricts definitions and supplies external bindings independently" {
  let orbit = @ast.Target::extension("orbit")
  let dialect = @config.Config::default().dialect.register_target(orbit)
  let config = { ..@config.Config::default(), dialect, }
  let source = "@target(orbit)\npub const answer = 42\n@external(orbit, \"space/list\", \"length\")\npub fn length(xs: List(a)) -> Int\n"
  let result = @parser.parse_text(source, config~)
  @expect.expect(result.diagnostics).to_equal([][:])
  guard result.module_.definitions[1].definition is Function(function) else {
    fail("expected a function")
  }
  @expect.expect_all(s => {
    s.expect(result.cst.to_source()).to_equal(source)
    s.expect(result.module_.definitions[0].target).to_equal(Some(orbit))
    s.expect(result.module_.definitions[1].target).to_equal(None)
    s
    .expect(function.external_for(orbit).map(e => e.module_))
    .to_equal(Some("space/list"))
    s
    .expect(function.external_for(orbit).map(e => e.function))
    .to_equal(Some("length"))
  })
}

///|
test "compiler compatible export rejects extension target information" {
  let orbit = @ast.Target::extension("orbit")
  let config = {
    ..@config.Config::default(),
    dialect: @config.Config::default().dialect.register_target(orbit),
  }
  let result = @parser.parse_text(
    "@target(orbit)\npub const answer = 42\n",
    config~,
  )
  let rejected = try {
    let _ = @ast.encode_parsed(result.parsed())
    false
  } catch {
    _ => true
  }
  @expect.expect(rejected).to_be_true()
}

///|
test "versioned extended JSON preserves mixed function and external type bindings" {
  let orbit = @ast.Target::extension("orbit")
  let config = {
    ..@config.Config::default(),
    dialect: @config.Config::default().dialect.register_target(orbit),
  }
  let source = "@external(erlang, \"lists\", \"length\")\n@external(orbit, \"space/list\", \"length\")\npub fn length(xs: List(a)) -> Int\n@target(orbit)\n@external(orbit, \"space\", \"Id\")\npub type Id\n"
  let result = @parser.parse_text(source, config~)
  @expect.expect(result.has_errors()).to_equal(false)
  let document = @ast.Extended(
    result.parsed(),
    dialect=config.dialect.name,
    targets=config.dialect.targets,
  )
  let json = @ast.encode_extended(document)
  let back = @ast.decode_extended(json)
  @expect.expect_all(s => {
    s.expect(back.parsed).to_equal(result.parsed())
    s
    .expect(@ast.canonical(@ast.encode_extended(back)))
    .to_equal(@ast.canonical(json))
    s.expect(@ast.canonical(json).contains("external_erlang")).to_equal(false)
  })
}
