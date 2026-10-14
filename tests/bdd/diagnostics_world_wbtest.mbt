///|
/// Scenario state for `tests/features/diagnostics.feature`.
struct DiagnosticsWorld {
  mut description : String?
} derive(Default)

///|
fn DiagnosticsWorld::new() -> DiagnosticsWorld {
  Default::default()
}

///|
impl @moonspec.World for DiagnosticsWorld with fn configure(self, setup) {
  setup.when1("I look up the diagnostic code {string}", fn(code : String) {
    self.description = @gleam.diagnostic_description(code)
  })
  setup.then1("the description is {string}", fn(text : String) raise {
    @expect.expect(self.description).to_equal(Some(text))
  })
  setup.then("there is no description", fn(_ctx) raise {
    @expect.expect(self.description).to_equal(None)
  })
}

///|
async test "diagnostics feature" {
  @moonspec.run_or_fail(
    DiagnosticsWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/diagnostics.feature"),
    ]),
  )
  |> ignore
}
