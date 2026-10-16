///|
/// Scenario state for `tests/features/rejection.feature`.
struct RejectionWorld {
  texts : Map[String, String]
  verdicts : Map[String, Json]
  /// The sha256 the verdict was recorded for, when not the current text's.
  recorded_sha : Map[String, String]
  mut pending_text : String
  mut pending : Array[Pending]
}

///|
fn RejectionWorld::new() -> RejectionWorld {
  {
    texts: Map([]),
    verdicts: Map([]),
    recorded_sha: Map([]),
    pending_text: "",
    pending: [],
  }
}

///|
let world_key : String = "gleam-1.19.2"

///|
fn unescape(text : String) -> String {
  text.replace_all(old="\\n", new="\n").replace_all(old="\\r", new="\r")
}

///|
fn RejectionWorld::verdicts_json(self : RejectionWorld) -> Json {
  let entries : Map[String, Json] = Map([])
  for fixture, v in self.verdicts {
    let text = self.texts.get(fixture).unwrap_or("")
    let sha = match self.recorded_sha.get(fixture) {
      Some(recorded) => recorded
      None => sha256_bytes_hex(@utf8.encode(text))
    }
    let entry : Map[String, Json] = Map([("sha256", Json(sha)), (world_key, v)])
    entries[fixture] = Json::object(entry)
  }
  Json::object(entries)
}

///|
fn RejectionWorld::run(self : RejectionWorld) -> Result[Array[Pending], String] {
  try
    mismatches(self.verdicts_json(), world_key, fixture => {
      @utf8.encode(self.texts.get(fixture).unwrap_or(""))
    })
  catch {
    err => Err(err.to_string())
  } noraise {
    found => Ok(found)
  }
}

///|
impl @moonspec.World for RejectionWorld with fn configure(self, setup) {
  setup.given2("the fixture {string} is {string}", fn(
    fixture : String,
    text : String,
  ) {
    self.texts[fixture] = unescape(text)
  })
  setup.given2("the oracle verdict for {string} is {string}", fn(
    fixture : String,
    json : String,
  ) raise {
    self.verdicts[fixture] = @json.parse(json)
  })
  setup.given1(
    "the oracle verdict for {string} is the first error gleam-parser reports",
    fn(fixture : String) raise {
      guard first_error(self.texts.get(fixture).unwrap_or("")) is Some(d) else {
        fail("gleam-parser accepts \{fixture}")
      }
      let (kind, lexical, span) = error_identity(d)
      self.verdicts[fixture] = {
        "accepted": false,
        "kind": Json(kind),
        "lexical_kind": match lexical {
          Some(l) => Json(l)
          None => Json::null()
        },
        "location": {
          "start": Json(span.start.to_int()),
          "end": Json(span.end.to_int()),
        },
      }
    },
  )
  setup.given1(
    "the oracle verdict for {string} was recorded for another text",
    fn(fixture : String) {
      let original = self.texts.get(fixture).unwrap_or("")
      self.verdicts[fixture] = { "accepted": true }
      self.recorded_sha[fixture] = sha256_bytes_hex(@utf8.encode(original))
      self.texts[fixture] = original + "// changed\n"
    },
  )
  setup.then1("the mismatches are {string}", fn(expected : String) raise {
    guard self.run() is Ok(found) else {
      fail("checking failed: \{Repr(self.run())}")
    }
    @expect.expect(found.map(describe).join(", ")).to_equal(expected)
  })
  setup.then1("checking fails with {string}", fn(message : String) raise {
    guard self.run() is Err(actual) else { fail("expected a failure") }
    @expect.expect(actual).to_contain(message)
  })
  setup.given1("the pending entries {string}", fn(text : String) {
    self.pending = text
      .split(", ")
      .map(item => {
        let parts = item.split(" ").map(p => p.to_owned()).collect()
        { fixture: parts[0], check: parts[1], }
      })
      .collect()
  })
  setup.when0("I write and read the pending list", fn() raise {
    self.pending_text = format_pending(self.pending)
    self.pending = parse_pending(self.pending_text)
  })
  setup.then1("the pending entries are {string}", fn(expected : String) raise {
    @expect.expect(self.pending.map(describe).join(", ")).to_equal(expected)
  })
  setup.then2("the unrecorded problems for the files {string} are {string}", fn(
    files : String,
    expected : String,
  ) raise {
    let list = if files == "" {
      []
    } else {
      files.split(", ").map(f => f.to_owned()).collect()
    }
    @expect.expect(unrecorded(self.verdicts_json(), list).join("; ")).to_equal(
      expected,
    )
  })
}

///|
async test "rejection feature" {
  @moonspec.run_or_fail(
    RejectionWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("../tests/features/rejection.feature"),
    ]),
  )
  |> ignore
}
