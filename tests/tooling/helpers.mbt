///|
/// Compare strings in UTF-16 code unit order.
pub fn compare_lexical(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = a.code_unit_at(i).compare(b.code_unit_at(i))
    if c != 0 {
      return c
    }
  }
  a.length().compare(b.length())
}

///|
/// Compute the lowercase hexadecimal SHA-256 of raw bytes.
pub fn sha256_hex(bytes : Bytes) -> String {
  @hex.encode(Bytes::from_array(@crypto.sha256(bytes)))
}
