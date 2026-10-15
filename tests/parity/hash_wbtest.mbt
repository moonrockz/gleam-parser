///|
/// Lowercase hex SHA-256 of the UTF-8 bytes of `text`.
fn sha256_hex(text : String) -> String {
  @hex.encode(Bytes::from_array(@crypto.sha256(@utf8.encode(text))))
}

///|
/// Lowercase hex SHA-256 of raw bytes (corpus source files).
fn sha256_bytes_hex(bytes : Bytes) -> String {
  @hex.encode(Bytes::from_array(@crypto.sha256(bytes)))
}

///|
/// The golden hash of an oracle result: the SHA-256 of its canonical JSON.
/// gleam-parser's result goes through the same function, so key order and
/// spacing never matter.
fn golden_hash(oracle_json : Json) -> String {
  sha256_hex(@gleam.canonical(oracle_json))
}

///|
test "sha256_hex is the SHA-256 of the UTF-8 bytes" {
  @expect.expect(sha256_hex("abc")).to_equal(
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}
