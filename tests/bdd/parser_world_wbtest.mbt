///|
/// Scenario state for `tests/features/parser.feature`.
struct ParserWorld {
  mut source : String
  mut fixture : String
  mut result : @gleam.ParseResult?
} derive(Default)

///|
fn ParserWorld::result(self : ParserWorld) -> @gleam.ParseResult raise {
  guard self.result is Some(r) else { fail("no parse") }
  r
}

///|
impl @moonspec.World for ParserWorld with fn configure(self, setup) {
  setup.given1("the Gleam fixture {string}", fn(name : String) raise {
    self.source = @fs.read_file_to_string("fixtures/ast/\{name}.gleam")
    self.fixture = @fs.read_file_to_string("fixtures/ast/\{name}.json")
  })
  setup.when("I parse the fixture", fn(_ctx) {
    self.result = Some(@gleam.parse_text(self.source))
  })
  setup.then("there is no error diagnostic", fn(_ctx) raise {
    let r = self.result()
    let errors = r.diagnostics.filter(d => d.is_error())
    @expect.expect(errors.length()).to_equal(0)
  })
  setup.then("the parse result's canonical JSON equals the fixture", fn(
    _ctx,
  ) raise {
    let r = self.result()
    let text = @gleam.canonical(@gleam.encode_parsed(r.parsed())) + "\n"
    @expect.expect(text).to_equal(self.fixture)
  })
  setup.then("the CST rebuilds the source", fn(_ctx) raise {
    @expect.expect(self.result().cst.to_source()).to_equal(self.source)
  })
  setup.then("the first error diagnostic is the oracle's error", fn(
    _ctx,
  ) raise {
    let r = self.result()
    guard @gleam.decode_oracle_output(@json.parse(self.fixture))
      is Error(kind~, lexical_kind~, location~) else {
      fail("the fixture is not an error")
    }
    guard r.diagnostics.filter(d => d.is_error()).get(0) is Some(d) else {
      fail("no error diagnostic")
    }
    let (actual_kind, actual_lexical) = if d.code == "GL-SCAN-001" {
      ("LexError", Some(d.kind))
    } else {
      (d.kind, None)
    }
    @expect.expect_all(e => {
      e.expect(actual_kind).to_equal(kind)
      e.expect(actual_lexical).to_equal(lexical_kind)
      e.expect(d.span).to_equal(location)
    })
  })
}

///|
async test "parser feature" {
  @moonspec.run_or_fail(
    () => (Default::default() : ParserWorld),
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/parser.feature"),
    ]),
  )
  |> ignore
}
