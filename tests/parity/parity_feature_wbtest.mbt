///|
/// Scenario state for `tests/features/parity.feature`.
struct ParityWorld {
  mut lock_text : String
  mut lock_result : Result[String, String]
  mut oracle_json : Json
  mut counts : Counts
  mut baseline : Counts
  mut manifest : Array[(String, String)]
  mut golden : Json
  mut actual : Json
}

///|
fn ParityWorld::new() -> ParityWorld {
  let zero = { files: 0, tokenized: 0, parsed: 0, matched: 0, }
  {
    lock_text: "",
    lock_result: Ok(""),
    oracle_json: Json::null(),
    counts: zero,
    baseline: zero,
    manifest: [],
    golden: Json::null(),
    actual: Json::null(),
  }
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
  setup.given4(
    "the counts {int} files, {int} tokenized, {int} parsed, {int} matched",
    fn(files : Int32, tokenized : Int32, parsed : Int32, matched : Int32) {
      self.counts = { files, tokenized, parsed, matched, }
    },
  )
  setup.given4(
    "the baseline {int} files, {int} tokenized, {int} parsed, {int} matched",
    fn(files : Int32, tokenized : Int32, parsed : Int32, matched : Int32) {
      self.baseline = { files, tokenized, parsed, matched, }
    },
  )
  setup.then1("the regressions are {string}", fn(expected : String) raise {
    @expect.expect(regressions(self.counts, self.baseline).join("; ")).to_equal(
      expected,
    )
  })
  setup.then1("ratcheting gives {string}", fn(expected : String) raise {
    let actual = match ratchet(self.counts, self.baseline) {
      Ok(c) => counts_text(c)
      Err(message) => "refused: \{message}"
    }
    @expect.expect(actual).to_equal(expected)
  })
  setup.given1("the manifest sources {string}", fn(text : String) {
    self.manifest = text
      .split(", ")
      .map(item => {
        let parts = item.split(" ").map(p => p.to_owned()).collect()
        (parts[0], parts[1])
      })
      .collect()
  })
  setup.then1("the source problems are {string}", fn(expected : String) raise {
    let lock = parse_lock(self.lock_text)
    @expect.expect(source_problems(lock, self.manifest).join("; ")).to_equal(
      expected,
    )
  })
  setup.given1("the golden JSON {string}", fn(text : String) raise {
    self.golden = @json.parse(text)
  })
  setup.given1("the gleam-parser JSON {string}", fn(text : String) raise {
    self.actual = @json.parse(text)
  })
  setup.then3(
    "the first difference is at {string} with {string} against {string}",
    fn(path : String, expected : String, actual : String) raise {
      guard first_difference(self.golden, self.actual) is Some(d) else {
        fail("expected a difference")
      }
      @expect.expect_all(s => {
        s.expect(d.path).to_equal(path)
        s.expect(brief(d.expected)).to_equal(expected)
        s.expect(brief(d.actual)).to_equal(actual)
      })
    },
  )
  setup.then0(
    "the brief form of the golden JSON has 120 characters and ends with \"...\"",
    fn() raise {
      let text = brief(self.golden)
      @expect.expect_all(s => {
        s.expect(text.length()).to_equal(120)
        s.expect(text.has_suffix("...")).to_be_true()
      })
    },
  )
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
