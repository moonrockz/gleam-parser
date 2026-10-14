///|
/// Scenario state for `tests/features/source_text.feature`.
struct SourceTextWorld {
  mut text : @gleam.SourceText?
  mut position : @gleam.Position?
} derive(Default)

///|
fn SourceTextWorld::new() -> SourceTextWorld {
  SourceTextWorld::default()
}

///|
/// Gherkin gives `\n` and `\r` as two characters each; make them real.
fn unescape(s : String) -> String {
  s.replace(old="\\r", new="\r").replace(old="\\n", new="\n")
}

///|
impl @moonspec.World for SourceTextWorld with fn configure(self, setup) {
  setup.given1("the source text {string}", fn(text : String) {
    self.text = Some(@gleam.SourceText::new(unescape(text)))
  })
  setup.when1("I look up byte offset {int}", fn(byte : Int32) raise {
    guard self.text is Some(text) else { fail("no source text") }
    self.position = text.position_of(byte)
  })
  setup.then2("the position is line {int} column {int}", fn(
    line : Int32,
    column : Int32,
  ) raise {
    @expect.expect(self.position).to_equal(
      Some(@gleam.Position::new(line, column)),
    )
  })
  setup.then("there is no position", fn(_ctx) raise {
    @expect.expect(self.position).to_equal(None)
  })
}

///|
async test "source text feature" {
  @moonspec.run_or_fail(
    SourceTextWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/source_text.feature"),
    ]),
  )
  |> ignore
}
