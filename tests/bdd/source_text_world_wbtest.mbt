///|
/// Scenario state for `tests/features/source_text.feature`.
struct SourceTextWorld {
  mut text : @gleam.SourceText?
  mut position : @gleam.Position?
  mut constructed : Bool
} derive(Default)

///|
fn SourceTextWorld::new() -> SourceTextWorld {
  Default::default()
}

///|
/// Gherkin gives `\n` and `\r` as two characters each; make them real.
fn unescape(s : String) -> String {
  s.replace_all(old="\\r", new="\r").replace_all(old="\\n", new="\n")
}

///|
impl @moonspec.World for SourceTextWorld with fn configure(self, setup) {
  setup.when2("I construct a {string} from {int}", fn(
    kind : String,
    value : Int32,
  ) raise {
    self.constructed = match kind {
      "byte offset" => @gleam.ByteOffset::new(value) is Some(_)
      "UTF-16 offset" => @gleam.Utf16Offset::new(value) is Some(_)
      "byte length" => @gleam.ByteLength::new(value) is Some(_)
      "line number" => @gleam.LineNumber::new(value) is Some(_)
      "column number" => @gleam.ColumnNumber::new(value) is Some(_)
      "line count" => @gleam.LineCount::new(value) is Some(_)
      "tuple index" => @gleam.TupleIndex::new(value.to_int64()) is Some(_)
      "bit array unit" => @gleam.BitArrayUnit::new(value) is Some(_)
      "child index" => @gleam.ChildIndex::new(value) is Some(_)
      "node depth" => @gleam.NodeDepth::new(value) is Some(_)
      _ => fail("unknown domain type: \{kind}")
    }
  })
  setup.then1("construction {string}", fn(result : String) raise {
    @expect.expect(self.constructed).to_equal(result == "succeeds")
  })
  setup.given1("the source text {string}", fn(text : String) {
    self.text = Some(@gleam.SourceText(unescape(text)))
  })
  setup.when1("I look up byte offset {int}", fn(byte : Int32) raise {
    guard self.text is Some(text) else { fail("no source text") }
    self.position = @gleam.ByteOffset::new(byte).bind(x => text.position_of(x))
  })
  setup.then2("the position is line {int} column {int}", fn(
    line : Int32,
    column : Int32,
  ) raise {
    @expect.expect(self.position).to_equal(
      Some(@gleam.Position::new(line, column).unwrap()),
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
