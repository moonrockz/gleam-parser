///|
/// A string of these UTF-16 code units. A string literal cannot hold a lone
/// surrogate; this can.
pub fn units(xs : Array[Int32]) -> String {
  let sb = StringBuilder()
  for x in xs {
    sb.write_char(x.unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Characters at the edges of what `SourceText` and the scanner handle: a
/// lone high surrogate, a lone low surrogate, a surrogate pair, a high
/// surrogate before another high one, a lone `\r`, CRLF, LF, tab, a byte
/// order mark, ASCII, a two-byte and a three-byte character, and nothing.
pub fn edge_chars() -> Array[String] {
  [
    units([0xD800]),
    units([0xDC00]),
    units([0xD834, 0xDD1E]),
    units([0xD800, 0xD800]),
    "\r",
    "\r\n",
    "\n",
    "\t",
    "\u{FEFF}",
    "a",
    "é",
    "€",
    "",
  ]
}

///|
/// Any text: a sequence of edge characters and ASCII pieces. Edge values:
/// none, one and many pieces; every item of `edge_chars()`; line breaks of
/// all three kinds next to each other.
pub struct Units(String) derive(Debug)

///|
pub fn Units::text(self : Units) -> String {
  self.0
}

///|
fn pick(rs : @splitmix.RandomState, n : Int32) -> Int32 {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
pub impl @quickcheck.Arbitrary for Units with fn arbitrary(size, rs) {
  let edges = edge_chars()
  let pieces = Array::makei(pick(rs, size + 1), _ => {
    match pick(rs, 3) {
      0 => edges[pick(rs, edges.length())]
      1 => "x"
      _ => units([0x20 + pick(rs, 0x5F)])
    }
  })
  Units(pieces.join(""))
}

///|
pub impl @quickcheck.Shrink for Units
