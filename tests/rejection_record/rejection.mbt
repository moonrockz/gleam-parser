///|
/// Record the Gleam compiler's verdicts for the rejection fixtures.
///
/// Usage: rejection.mbtx record <fixtures-dir> <oracle-binary> <gleam_version.txt> <verdicts.json>
///
/// Every `.gleam` file under `<fixtures-dir>` goes through the oracle once.
/// The verdicts file maps each fixture (its path relative to the fixtures
/// directory) to its SHA-256 and, under `gleam-<version>`, `{"accepted":
/// true}` or the first error's kind, lexical kind and location.

///|
let usage : String = "Usage: rejection.mbtx record <fixtures-dir> <oracle-binary> <gleam_version.txt> <verdicts.json>"

///|
fn verdict_key(gleam_version : String) -> String {
  "gleam-\{gleam_version}"
}

///|
/// The verdict for one oracle output line.
fn verdict(line : String) -> Json raise {
  guard @json.parse(line) is Object(o) else {
    fail("oracle: not JSON: \{line}")
  }
  match o.get("error") {
    None => { "accepted": true }
    Some(Object(e)) => {
      guard e.get("kind") is Some(String(kind)) &&
        e.get("lexical_kind") is Some(lexical_kind) &&
        e.get("location") is Some(Object(location)) &&
        location.get("start") is Some(Number(_)) &&
        location.get("end") is Some(Number(_)) else {
        fail("oracle: malformed error: \{line}")
      }
      {
        "accepted": false,
        "kind": Json(kind),
        "lexical_kind": lexical_kind,
        "location": Json::object(location),
      }
    }
    Some(_) => fail("oracle: malformed error: \{line}")
  }
}

///|
/// The `.gleam` paths among `paths`, relative to `dir`, sorted by code unit.
fn fixtures_under(dir : String, paths : Array[String]) -> Array[String] {
  let prefix = "\{dir}/"
  let found = paths
    .filter(p => p.has_suffix(".gleam") && p.has_prefix(prefix))
    .map(p => p.view(start_offset=prefix.length()).to_owned())
  found.sort_by(@tooling.compare_lexical)
  found
}

///|
/// Every file under `dir`, recursively, as full paths.
async fn all_files(dir : String) -> Array[String] {
  let found = []
  async fn go(current : String) -> Unit {
    for entry in @fs.readdir(current, sort=true) {
      let path = "\{current}/\{entry}"
      match @fs.kind(path) {
        Directory => go(path)
        Regular => found.push(path)
        _ => ()
      }
    }
  }
  go(dir)
  found
}

///|
async fn record(
  fixtures : String,
  oracle : String,
  version_file : String,
  out : String,
) -> Unit {
  let key = verdict_key(@fs.read_file(version_file).text().trim().to_owned())
  let files = fixtures_under(fixtures, all_files(fixtures))
  if files.is_empty() {
    eprintln("no .gleam fixtures under \{fixtures}")
    @sys.exit(1)
  }
  let (code, stdout) = @process.collect_stdout(
    oracle,
    files.map(f => "\{fixtures}/\{f}"),
  )
  if code != 0 {
    eprintln("oracle failed with exit code \{code}")
    @sys.exit(code)
    return
  }
  let lines = stdout
    .text()
    .split("\n")
    .map(l => l.to_owned())
    .filter(l => l != "")
    .collect()
  if lines.length() != files.length() {
    eprintln("oracle: \{lines.length()} results for \{files.length()} fixtures")
    @sys.exit(1)
    return
  }
  let recorded : Map[String, Json] = Map([])
  for i in 0..<files.length() {
    let file = files[i]
    let v = verdict(lines[i]) catch {
      err => {
        eprintln("\{file}: \{err}")
        @sys.exit(1)
        return
      }
    }
    let entry : Map[String, Json] = Map([
      (
        "sha256",
        Json(@tooling.sha256_hex(@fs.read_file("\{fixtures}/\{file}").binary())),
      ),
      (key, v),
    ])
    recorded[file] = Json::object(entry)
    let word = if v is Object(o) && o.get("accepted") is Some(True) {
      "accepts"
    } else {
      "rejects"
    }
    println("\{file}: \{word}")
  }
  @fs.write_file(out, Json::object(recorded).stringify(indent=2) + "\n")
  println("rejection: recorded \{files.length()} fixtures in \{out}")
}

///|
async fn main {
  match @env.args()[1:] {
    ["record", fixtures, oracle, version_file, out] =>
      record(fixtures, oracle, version_file, out)
    _ => {
      eprintln(usage)
      @sys.exit(2)
    }
  }
}

///|
/// Scenario state for `features/rejection.feature`.
struct RejectionWorld {
  mut line : String
  mut files : Array[String]
}

///|
fn RejectionWorld::new() -> RejectionWorld {
  { line: "", files: [], }
}

///|
impl @moonspec.World for RejectionWorld with fn configure(self, setup) {
  setup.given1("the oracle line {string}", fn(line : String) {
    self.line = line
  })
  setup.then1("the verdict is {string}", fn(expected : String) raise {
    @expect.expect(verdict(self.line).stringify()).to_equal(
      @json.parse(expected).stringify(),
    )
  })
  setup.then1("reading the verdict fails with {string}", fn(
    message : String,
  ) raise {
    let actual = try verdict(self.line) catch {
      err => err.to_string()
    } noraise {
      _ => "no error"
    }
    @expect.expect(actual).to_contain(message)
  })
  setup.given1("the fixture files {string}", fn(files : String) {
    self.files = files.split(", ").map(f => f.to_owned()).collect()
  })
  setup.then2("the fixtures under {string} are {string}", fn(
    dir : String,
    expected : String,
  ) raise {
    @expect.expect(fixtures_under(dir, self.files).join(", ")).to_equal(
      expected,
    )
  })
  setup.then2("the verdict key for version {string} is {string}", fn(
    version : String,
    expected : String,
  ) raise {
    @expect.expect(verdict_key(version)).to_equal(expected)
  })
}

///|
async test "rejection feature" {
  @moonspec.run_or_fail(
    RejectionWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("../scripts/features/rejection.feature"),
    ]),
  )
  |> ignore
}
