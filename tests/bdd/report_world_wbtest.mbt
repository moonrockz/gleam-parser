///|
/// Scenario state for `tests/features/report.feature`.
struct ReportWorld {
  mut source : String
  mut report : String
  mut compiler_report : String
} derive(Default)

///|
impl @moonspec.World for ReportWorld with fn configure(self, setup) {
  setup.given1("the compiler diagnostic fixture {string}", fn(
    name : String,
  ) raise {
    let fixtures = @json.parse(
      @fs.read_file_to_string("fixtures/report/compiler_unicode.json"),
    )
    guard fixtures is Object(entries) &&
      entries.get(name)
      is Some({ "source": String(source), "report": String(report), .. }) else {
      fail("missing compiler report: \{name}")
    }
    self.source = source
    self.compiler_report = report
  })
  setup.then0("the report equals the compiler fixture", fn() raise {
    @expect.expect(self.report).to_equal(self.compiler_report)
  })
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
    self.report = @gleam.render_plain(d, @gleam.SourceText(self.source), path)
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
