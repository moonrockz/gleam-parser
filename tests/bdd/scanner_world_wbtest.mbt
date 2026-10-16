///|
/// Scenario state for `tests/features/scanner.feature`.
struct ScannerWorld {
  mut source : String
  mut stream : @gleam.TokenStream?
} derive(Default)

///|
fn ScannerWorld::new() -> ScannerWorld {
  Default::default()
}

///|
/// A short form of a token kind: the variant name, with the text of a name,
/// keyword, number or string in parentheses.
fn short_kind(k : @gleam.TokenKind) -> String {
  match k {
    Name(n) | UpName(n) | DiscardName(n) => "\{kind_word(k)}(\{n})"
    Int(value~, ..) | Float(value~, ..) => "\{kind_word(k)}(\{value})"
    String(s) => "String(\{s})"
    Keyword(_) => kind_word(k)
    _ => kind_word(k)
  }
}

///|
fn kind_word(k : @gleam.TokenKind) -> String {
  match k {
    Name(_) => "Name"
    UpName(_) => "UpName"
    DiscardName(_) => "DiscardName"
    Int(..) => "Int"
    Float(..) => "Float"
    String(_) => "String"
    other => @debug.to_string(other)
  }
}

///|
fn ScannerWorld::tokens(self : ScannerWorld) -> ArrayView[@gleam.Token] raise {
  guard self.stream is Some(s) else { fail("no scan") }
  s.tokens
}

///|
impl @moonspec.World for ScannerWorld with fn configure(self, setup) {
  setup.given("the Gleam source:", fn(ctx) {
    match ctx[0] {
      { value: @moonspec.StepValue::DocStringVal(doc), .. } =>
        self.source = doc.content
      _ => ()
    }
  })
  setup.given1("the Gleam source {string}", fn(text : String) {
    self.source = text
  })
  setup.when("I scan the source", fn(_ctx) {
    self.stream = Some(@gleam.tokenize_text(self.source))
  })
  setup.then("the scan has no diagnostics", fn(_ctx) raise {
    guard self.stream is Some(s) else { fail("no scan") }
    @expect.expect(s.diagnostics.length()).to_equal(0)
  })
  setup.then1("the token kinds are {string}", fn(expected : String) raise {
    let actual = self
      .tokens()
      .iter()
      .map(t => short_kind(t.kind))
      .collect()
      .join(", ")
    @expect.expect(actual).to_equal(expected)
  })
  setup.then("the trivia and lexemes rebuild the source", fn(_ctx) raise {
    guard self.stream is Some(s) else { fail("no scan") }
    @expect.expect(s.to_source()).to_equal(self.source)
  })
  setup.then(
    "the first token has a module comment and a line break before it",
    fn(_ctx) raise {
      let first = self.tokens()[0]
      guard first.trivia_before[0] is @gleam.Trivia::Comment(c) else {
        fail("expected a comment first")
      }
      @expect.expect_all(e => {
        e.expect(c.kind).to_equal(@gleam.CommentKind::Module)
        e
        .expect(first.trivia_before[1] is @gleam.Trivia::Newline(_, _))
        .to_be_true()
      })
    },
  )
  setup.then3("diagnostic {int} has kind {string} and message {string}", fn(
    index : Int32,
    kind : String,
    message : String,
  ) raise {
    guard self.stream is Some(s) else { fail("no scan") }
    let d = s.diagnostics[index - 1]
    @expect.expect_all(e => {
      e.expect(d.kind).to_equal(kind)
      e.expect(d.message).to_equal(message)
    })
  })
  setup.then3("diagnostic {int} spans bytes {int} to {int}", fn(
    index : Int32,
    start : Int32,
    end : Int32,
  ) raise {
    guard self.stream is Some(s) else { fail("no scan") }
    @expect.expect(s.diagnostics[index - 1].span).to_equal(
      @gleam.SrcSpan::new(start, end).unwrap(),
    )
  })
}

///|
async test "scanner feature" {
  @moonspec.run_or_fail(
    ScannerWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/scanner.feature"),
    ]),
  )
  |> ignore
}
