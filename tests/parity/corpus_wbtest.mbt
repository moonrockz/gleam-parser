///|
/// Parity check over the pinned corpus, controlled by `GLEAM_PARITY_MODE`:
///
/// - unset: skip (so `moon test` works without the fetched corpus).
/// - `check`: score gleam-parser against `tests/corpus/goldens.lock`; fail
///   when a count drops below `tests/corpus/baseline.json`.
/// - `ratchet`: score, then write the counts to `tests/corpus/baseline.json`.
/// - `write-lock`: hash the raw oracle output in `.dev/out/goldens/raw` and
///   write `tests/corpus/goldens.lock`.
priv enum Mode {
  Check
  Ratchet
  WriteLock
} derive(Eq, Debug)

///|
let manifest_path : String = "../tests/corpus/manifest.json"

///|
let lock_path : String = "../tests/corpus/goldens.lock"

///|
let baseline_path : String = "../tests/corpus/baseline.json"

///|
let version_path : String = "../tests/corpus/gleam_version.txt"

///|
let cargo_path : String = "../tools/gleam-ast-oracle/Cargo.toml"

///|
let corpus_dir : String = "../.corpus"

///|
let raw_goldens_dir : String = "../.dev/out/goldens/raw"

///|
fn parity_mode() -> Mode? raise {
  match @env.get_env_var("GLEAM_PARITY_MODE") {
    None | Some("") => None
    Some("check") => Some(Check)
    Some("ratchet") => Some(Ratchet)
    Some("write-lock") => Some(WriteLock)
    Some(other) => fail("unknown GLEAM_PARITY_MODE: \{other}")
  }
}

///|
/// Corpus keys and source SHA-256 from the manifest, in manifest order.
fn manifest_sources() -> Array[(String, String)] raise {
  guard @json.parse(@fs.read_file_to_string(manifest_path)) is Object(root) &&
    root.get("packages") is Some(Array(packages)) else {
    fail("\{manifest_path}: missing packages array")
  }
  let sources = []
  for p in packages {
    guard p is Object(pkg) &&
      pkg.get("name") is Some(String(name)) &&
      pkg.get("version") is Some(String(version)) &&
      pkg.get("files") is Some(Array(files)) else {
      fail("\{manifest_path}: malformed package entry")
    }
    for f in files {
      guard f is Object(file) &&
        file.get("path") is Some(String(path)) &&
        file.get("sha256") is Some(String(sha)) else {
        fail("\{manifest_path}: malformed file entry in \{name}")
      }
      sources.push(("\{name}@\{version}/\{path}", sha))
    }
  }
  sources
}

///|
/// Read a corpus file after checking it against its expected SHA-256.
fn verified_source(key : String, expected_sha256 : String) -> String raise {
  let path = "\{corpus_dir}/\{key}"
  if !@fs.path_exists(path) {
    fail("missing corpus file \{path}; run mise run corpus:fetch")
  }
  let bytes = @fs.read_file_to_bytes(path)
  if sha256_bytes_hex(bytes) != expected_sha256 {
    fail(
      "corpus file \{path} does not match its pinned hash; run rm -rf .corpus && mise run corpus:fetch",
    )
  }
  @fs.read_file_to_string(path)
}

///|
fn write_lock() -> Unit raise {
  let entries = []
  for source in manifest_sources() {
    let (key, source_sha256) = source
    // The oracle parsed this file, so it must be the pinned source.
    ignore(verified_source(key, source_sha256))
    let raw = "\{raw_goldens_dir}/\{key}"
    let golden = if @fs.path_exists("\{raw}.json") {
      Hash(golden_hash(@json.parse(@fs.read_file_to_string("\{raw}.json"))))
    } else if @fs.path_exists("\{raw}.error") {
      ParseError
    } else {
      fail("missing oracle output for \{key}; run mise run corpus:goldens")
    }
    entries.push({ key, source_sha256, golden, })
  }
  @fs.write_string_to_file(lock_path, format_lock(entries))
  println("parity: wrote \{lock_path} (\{entries.length()} files)")
}

///|
/// The Gleam version the corpus and the oracle are pinned to.
fn pinned_gleam_version() -> String raise {
  @fs.read_file_to_string(version_path).trim().to_owned()
}

///|
test "the oracle's Cargo.toml and gleam_version.txt name the same Gleam tag" {
  let cargo = @fs.read_file_to_string(cargo_path)
  @expect.expect(cargo).to_contain("tag = \"v\{pinned_gleam_version()}\"")
}

///|
test "parity corpus" {
  match parity_mode() {
    None =>
      println(
        "parity: skipped (set GLEAM_PARITY_MODE or run mise run test:parity)",
      )
    Some(WriteLock) => write_lock()
    Some(_) => fail("scoring is added in Task 3")
  }
}
