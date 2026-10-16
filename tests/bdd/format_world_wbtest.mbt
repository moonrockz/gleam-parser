///|
/// Scenario state for `tests/features/format.feature`.
struct FormatWorld {
  mut source : String
  mut result : Result[String, @gleam.FormatError]?
  mut from_parsed : Result[String, @gleam.FormatError]?
}

///|
fn FormatWorld::new() -> FormatWorld {
  { source: "", result: None, from_parsed: None, }
}

///|
fn format_result(text : String) -> Result[String, @gleam.FormatError] {
  Ok(@gleam.format(text)) catch {
    e => Err(e)
  }
}

///|
impl @moonspec.World for FormatWorld with fn configure(self, setup) {
  setup.given1("the Gleam source {string}", fn(text : String) {
    self.source = unescape(text)
  })
  setup.when0("I format it", fn() {
    self.result = Some(format_result(self.source))
  })
  setup.then1("parsing gives {int} warning diagnostic and no error", fn(
    n : Int32,
  ) raise {
    let ds = @gleam.parse_text(self.source).diagnostics
    @expect.expect_all(s => {
      s.expect(ds.filter(d => d.severity is Warning).length()).to_equal(n)
      s.expect(ds.filter(d => d.severity is Error).length()).to_equal(0)
    })
  })
  setup.when0("I format it and its parse result", fn() {
    self.result = Some(format_result(self.source))
    self.from_parsed = Some(
      Ok(@gleam.format_parsed(@gleam.parse_text(self.source))) catch {
        e => Err(e)
      },
    )
  })
  setup.then1("the formatted text is {string}", fn(text : String) raise {
    @expect.expect(self.result).to_equal(Some(Ok(unescape(text))))
  })
  setup.then1("formatting fails with {int} error diagnostics", fn(
    n : Int32,
  ) raise {
    match self.result {
      Some(Err(ParseFailed(ds))) => @expect.expect(ds.length()).to_equal(n)
      _ => fail("expected ParseFailed")
    }
  })
  setup.then0("both texts are equal", fn() raise {
    @expect.expect(self.from_parsed).to_equal(self.result)
  })
}

///|
async test "format feature" {
  @moonspec.run_or_fail(
    FormatWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/format.feature"),
    ]),
  )
  |> ignore
}
