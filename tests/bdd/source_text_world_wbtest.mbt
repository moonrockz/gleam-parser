///|
/// Scenario state for `tests/features/source_text.feature`.
struct SourceTextWorld {
  mut text : @gleam.SourceText?
  mut position : @gleam.Position?
  mut constructed : Bool
  mut construction_error : String?
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
  setup.when3("I construct a native {string} from {int} and {int}", fn(
    kind : String,
    first : Int32,
    second : Int32,
  ) raise {
    self.construction_error = None
    self.constructed = false
    try {
      match kind {
        "span" => ignore(@gleam.SrcSpan(first, second))
        "position" => ignore(@gleam.Position(first, second))
        _ => fail("unknown native constructor: \{kind}")
      }
      self.constructed = true
    } catch {
      @gleam.CoordinateError::InvalidByteOffset(_) =>
        self.construction_error = Some("invalid byte offset")
      @gleam.CoordinateError::ReversedSpan(..) =>
        self.construction_error = Some("reversed span")
      @gleam.CoordinateError::InvalidLineNumber(_) =>
        self.construction_error = Some("invalid line number")
      @gleam.CoordinateError::InvalidColumnNumber(_) =>
        self.construction_error = Some("invalid column number")
      error => raise error
    }
  })
  setup.then1("construction raises {string}", fn(error : String) raise {
    @expect.expect(self.construction_error).to_equal(Some(error))
  })
  setup.when2("I construct a {string} from {int}", fn(
    kind : String,
    value : Int32,
  ) raise {
    self.constructed = match kind {
      "byte offset" => @gleam.ByteOffset::from_int(value) is Some(_)
      "UTF-16 offset" => @gleam.Utf16Offset::from_int(value) is Some(_)
      "byte length" => @gleam.ByteLength::from_int(value) is Some(_)
      "line number" => @gleam.LineNumber::from_int(value) is Some(_)
      "column number" => @gleam.ColumnNumber::from_int(value) is Some(_)
      "line count" => @gleam.LineCount::from_int(value) is Some(_)
      "tuple index" =>
        @gleam.TupleIndex::from_int64(value.to_int64()) is Some(_)
      "bit array unit" => @gleam.BitArrayUnit::from_int(value) is Some(_)
      "child index" => @gleam.ChildIndex::from_int(value) is Some(_)
      "node depth" => @gleam.NodeDepth::from_int(value) is Some(_)
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
    self.position = @gleam.ByteOffset::from_int(byte).bind(x => {
      text.position_of(x)
    })
  })
  setup.then2("the position is line {int} column {int}", fn(
    line : Int32,
    column : Int32,
  ) raise {
    @expect.expect(self.position).to_equal(
      Some(@gleam.Position::from_ints(line, column).unwrap()),
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
