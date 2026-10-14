///|
/// Scenario state for `tests/features/report.feature`.
struct ReportWorld {
  mut source : String
  mut report : String
} derive(Default)

///|
impl @moonspec.World for ReportWorld with fn configure(self, setup) {
  setup.given("the Gleam source:", fn(ctx) {
    match ctx[0] {
      { value: @moonspec.StepValue::DocStringVal(doc), .. } =>
        self.source = doc.content
      _ => ()
    }
  })
  setup.when1("I parse it and render the first diagnostic for {string}", fn(
    path : String,
  ) raise {
    let r = @gleam.parse_text(self.source)
    guard r.diagnostics.get(0) is Some(d) else { fail("no diagnostic") }
    self.report = @gleam.render_plain(
      d,
      @gleam.SourceText::new(self.source),
      path,
    )
  })
  setup.then("the report is:", fn(ctx) raise {
    match ctx[0] {
      { value: @moonspec.StepValue::DocStringVal(doc), .. } =>
        @expect.expect(self.report).to_equal(doc.content + "\n")
      _ => fail("expected a doc string")
    }
  })
}

///|
async test "report feature" {
  @moonspec.run_or_fail(
    () => (Default::default() : ReportWorld),
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/report.feature"),
    ]),
  )
  |> ignore
}
