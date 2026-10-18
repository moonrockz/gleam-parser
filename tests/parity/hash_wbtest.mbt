///|
/// The golden hash of an oracle result: the SHA-256 of its canonical JSON.
/// gleam-parser's result goes through the same function, so key order and
/// spacing never matter.
fn golden_hash(oracle_json : Json) -> String {
  @tooling.sha256_hex(@utf8.encode(@gleam.canonical(oracle_json)))
}
