///|
/// Text that is mostly not valid Gleam, for laws that must hold for any
/// text: no crash, lossless scan, spans in bounds. It is a list of pieces;
/// `text()` joins them. Pieces: Gleam tokens and keywords; edge characters;
/// edge characters inside every literal and comment form, closed or not; a
/// small valid module cut at any UTF-16 offset (inside a CRLF or a
/// surrogate pair too). It shrinks by dropping a piece or halving the
/// longest one.
pub(all) struct GleamText(Array[String]) derive(Debug)

///|
pub fn GleamText::text(self : GleamText) -> String {
  self.0.join("")
}

///|
/// Token texts of Gleam, one of each kind the lexer knows.
pub fn token_pieces() -> Array[String] {
  [
    "fn", "pub", "let", "use", "case", "type", "import", "as", "opaque", "const",
    "todo", "panic", "assert", "echo", "if", "else", "macro", "derive", "x", "foo_bar",
    "_", "_x", "Ok", "Error", "List", "0", "42", "1_000", "0x1F", "0o7", "0b10",
    "-1", "1.5", "1.", "1.0e3", "1.0e-3", "\"\"", "\"hi\"", "\"\\n\"", "\"\\u{1F600}\"",
    "(", ")", "[", "]", "{", "}", "+", "-", "*", "/", "%", "+.", "-.", "*.", "/.",
    "<", ">", "<=", ">=", "<.", ">.", "<=.", ">=.", "<>", "<<", ">>", "|>", "->",
    "<-", "..", ".", ":", ",", "#", "!", "=", "==", "!=", "|", "||", "&&", "@", " ",
    "\n", "\r\n", "\t", "//", "///", "////", "// c", "/// d", "//// m",
  ]
}

///|
/// Fragments the lexer rejects or stops in: an open string, a lone
/// backslash, bad escapes, bad numbers, procedural operators, conflict
/// markers, odd characters.
pub fn broken_pieces() -> Array[String] {
  [
    "\"", "\"abc", "\\", "\"\\q\"", "\"\\u", "\"\\u{", "\"\\u{}\"", "\"\\u{D800}\"",
    "0x", "0b2", "1_", "1.0e", "1.0e+", "1.0e99999999999", "-1.5e2147483648", "1.0e-99999999999",
    "a\u{FEFF}b", "+=", "++", "-=", "*=", "/=", "%=", "===", "=======", "<<<<<<<",
    ">>>>>>>", "&", ";", "'", "`", "~", "^", "\u{00A0}", "\u{201C}", "\u{FF08}",
    "é", "€", "\u{FEFF}",
  ]
}

///|
/// A small valid module.
pub fn small_module() -> String {
  (
    #|//// Module docs.
    #|
    #|import gleam/io
    #|
    #|/// Docs.
    #|pub fn main() {
    #|  let x = 1 + 2
    #|  io.println("hi")
    #|  x
    #|}
    #|
  )
}

///|
fn gleam_pick(rs : @splitmix.RandomState, n : Int32) -> Int32 {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn one_of(rs : @splitmix.RandomState, xs : Array[String]) -> String {
  xs[gleam_pick(rs, xs.length())]
}

///|
/// One piece: a token, a broken fragment, an edge character, an edge
/// character inside a literal or comment form (closed or not), or a cut of
/// the small module.
fn gleam_piece(rs : @splitmix.RandomState) -> String {
  match gleam_pick(rs, 10) {
    0 | 1 | 2 => one_of(rs, token_pieces())
    3 | 4 => one_of(rs, broken_pieces())
    5 | 6 => one_of(rs, edge_chars())
    7 => {
      let edge = one_of(rs, edge_chars())
      match gleam_pick(rs, 6) {
        0 => "\"" + edge + "\""
        1 => "\"" + edge
        2 => "// " + edge
        3 => "/// " + edge + "\n"
        4 => "\"\\" + edge + "\""
        _ => "\"\\u{" + edge + "}\""
      }
    }
    _ => {
      let m = small_module()
      let cut = gleam_pick(rs, m.length() + 1)
      if gleam_pick(rs, 2) == 0 {
        m.unsafe_substring(start=0, end=cut)
      } else {
        m.unsafe_substring(start=cut, end=m.length())
      }
    }
  }
}

///|
pub impl @quickcheck.Arbitrary for GleamText with fn arbitrary(size, rs) {
  GleamText(Array::makei(gleam_pick(rs, size + 1), _ => gleam_piece(rs)))
}

///|
pub impl @quickcheck.Shrink for GleamText with fn shrink(self) {
  let GleamText(parts) = self
  let out = Array::makei(parts.length(), i => {
    let fewer = parts.copy()
    ignore(fewer.remove(i))
    GleamText(fewer)
  })
  let mut longest = -1
  for i, p in parts {
    if p.length() > 1 && (longest < 0 || p.length() > parts[longest].length()) {
      longest = i
    }
  }
  if longest >= 0 {
    let halved = parts.copy()
    let p = parts[longest]
    halved[longest] = p.unsafe_substring(start=0, end=p.length() / 2)
    out.push(GleamText(halved))
  }
  out.iter()
}
