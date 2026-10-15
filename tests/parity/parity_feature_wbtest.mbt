///|
/// Scenario state for `tests/features/parity.feature`.
struct ParityWorld {
  mut lock_text : String
  mut lock_result : Result[String, String]
  mut oracle_json : Json
}

///|
fn ParityWorld::new() -> ParityWorld {
  { lock_text: "", lock_result: Ok(""), oracle_json: Json::null(), }
}

///|
impl @moonspec.World for ParityWorld with fn configure(self, setup) {
  setup.given1("the lock text:", fn(doc : @moonspec.DocString) {
    self.lock_text = doc.content
  })
  setup.when0("I read and write the lock", fn() {
    self.lock_result = try format_lock(parse_lock(self.lock_text)) catch {
      err => Err(err.to_string())
    } noraise {
      text => Ok(text)
    }
  })
  setup.then1("the lock text is:", fn(doc : @moonspec.DocString) raise {
    @expect.expect(self.lock_result).to_equal(Ok(doc.content + "\n"))
  })
  setup.then0("reading the lock fails", fn() raise {
    @expect.expect(self.lock_result is Err(_)).to_be_true()
  })
  setup.given1("the oracle JSON {string}", fn(text : String) raise {
    self.oracle_json = @json.parse(text)
  })
  setup.then1("the golden hash is the SHA-256 of {string}", fn(
    canonical : String,
  ) raise {
    @expect.expect(golden_hash(self.oracle_json)).to_equal(
      sha256_hex(canonical),
    )
  })
}

///|
async test "parity feature" {
  @moonspec.run_or_fail(
    ParityWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("../tests/features/parity.feature"),
    ]),
  )
  |> ignore
}
