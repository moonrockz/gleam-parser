///|
test "Morphir composes with an independently supplied profile through core APIs" {
  let scala = @gleam.Profile(
    "example/scala@1",
    [@gleam.Target::extension("scala")][:],
  )
  let go = @gleam.Profile("example/go@1", [@gleam.Target::extension("go")][:])
  let dialect = @gleam.Dialect::gleam_1_19()
    .with_profile(@morphir.profile())
    .with_profile(scala)
    .with_profile(go)
  let config = { ..@gleam.Config::default(), dialect, }
  let source = "@external(erlang, \"lists\", \"length\")\n@external(javascript, \"./ffi.mjs\", \"length\")\n@external(morphir, \"morphir/sdk/list\", \"length\")\n@external(scala, \"example.ListOps\", \"length\")\n@external(go, \"example/listops\", \"Length\")\npub fn length(items: List(a)) -> Int\n"
  let result = @gleam.parse_text(source, config~)
  assert_eq(result.has_errors(), false)
  guard result.module_.definitions[0].definition is Function(function) else {
    fail("function")
  }
  assert_eq(function.externals.all().length(), 5)
  assert_eq(result.module_.definitions[0].target, None)
  assert_eq(
    @gleam.decode_extended(@gleam.encode_extended(result)).parsed,
    result.parsed(),
  )
  let formatted = @gleam.format_parsed(result)
  let back = @gleam.parse_text(formatted, config~)
  assert_eq(back.has_errors(), false)
  assert_eq(
    back.module_.definitions[0].definition.external_bindings().all().length(),
    5,
  )
  assert_eq(@gleam.format_parsed(back), formatted)
  assert_eq(@gleam.parse_text(source).has_errors(), true)
}
