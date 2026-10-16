///|
/// Scenario state for `tests/features/ast_json.feature`.
struct AstWorld {
  mut fixture : String
  mut decoded : @gleam.OracleOutput?
  mut encoded : String
  mut decode_error : String
} derive(Default)

///|
impl @moonspec.World for AstWorld with fn configure(self, setup) {
  setup.given("the expression JSON:", fn(ctx) raise {
    guard ctx[0] is { value: @moonspec.StepValue::DocStringVal(doc), .. } else {
      fail("expected expression JSON")
    }
    self.fixture = doc.content
  })
  setup.when("I decode the expression", fn(_ctx) raise {
    let json = @json.parse(self.fixture)
    self.decode_error = try {
      @gleam.decode_expr(json) |> ignore
      "no error"
    } catch {
      @gleam.DecodeError::DecodeError(path~, message~) => "\{path}: \{message}"
    }
  })
  setup.then1("the decode error is {string}", fn(expected : String) raise {
    @expect.expect(self.decode_error).to_equal(expected)
  })
  setup.given1("the AST fixture {string}", fn(name : String) raise {
    self.fixture = @fs.read_file_to_string("fixtures/ast/\{name}.json")
  })
  setup.when("I decode and encode the fixture", fn(_ctx) raise {
    let out = @gleam.decode_oracle_output(@json.parse(self.fixture))
    self.decoded = Some(out)
    self.encoded = @gleam.canonical(@gleam.encode_oracle_output(out)) + "\n"
  })
  setup.when("I decode the fixture", fn(_ctx) raise {
    self.decoded = Some(@gleam.decode_oracle_output(@json.parse(self.fixture)))
  })
  setup.then("the encoded JSON equals the fixture byte for byte", fn(
    _ctx,
  ) raise {
    @expect.expect(self.encoded).to_equal(self.fixture)
  })
  setup.then2("constant {int} has the string value {string}", fn(
    index : Int32,
    value : String,
  ) raise {
    guard self.decoded is Some(Parsed(p)) else {
      fail("expected a parsed module")
    }
    guard p.module_.definitions[index].definition is ModuleConstant(c) else {
      fail("expected a constant")
    }
    guard c.value is String(value=actual, ..) else { fail("expected a string") }
    @expect.expect(actual).to_equal(value)
  })
}

///|
async test "ast json feature" {
  @moonspec.run_or_fail(
    () => (Default::default() : AstWorld),
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/ast_json.feature"),
    ]),
  )
  |> ignore
}
