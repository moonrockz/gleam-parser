///|
/// The lexer's view of the text: the compiler's `char0`/`char1` lookahead
/// with its line-end rule (`next_source_char`: `\r\n` and a lone `\r` are
/// `\n`, at the `\r`'s byte), UTF-8 byte positions for spans, and UTF-16
/// unit indexes for lexemes.
priv struct Cursor {
  text : String
  mut unit : Int32
  mut byte : Int32
}

///|
fn Cursor::new(text : String) -> Cursor {
  { text, unit: 0, byte: 0, }
}

///|
fn is_high_surrogate(c : Int32) -> Bool {
  c >= 0xD800 && c <= 0xDBFF
}

///|
fn is_low_surrogate(c : Int32) -> Bool {
  c >= 0xDC00 && c <= 0xDFFF
}

///|
/// The character at unit `i` as the compiler reads it, and its width in
/// UTF-16 units and in UTF-8 bytes. A surrogate pair reads as its high unit
/// (the lexer compares with ASCII only), 2 units, 4 bytes. A lone surrogate
/// is 1 unit, 3 bytes. `None` at or past the end.
fn Cursor::read_at(self : Cursor, i : Int32) -> (Char, Int32, Int32)? {
  let n = self.text.length()
  if i >= n {
    return None
  }
  let c = self.text.code_unit_at(i).to_int()
  if c == '\r'.to_int() {
    if i + 1 < n && self.text.code_unit_at(i + 1).to_int() == '\n'.to_int() {
      Some(('\n', 2, 2))
    } else {
      Some(('\n', 1, 1))
    }
  } else if c < 0x80 {
    Some((c.unsafe_to_char(), 1, 1))
  } else if c < 0x800 {
    Some((c.unsafe_to_char(), 1, 2))
  } else if is_high_surrogate(c) &&
    i + 1 < n &&
    is_low_surrogate(self.text.code_unit_at(i + 1).to_int()) {
    Some((c.unsafe_to_char(), 2, 4))
  } else {
    Some((c.unsafe_to_char(), 1, 3))
  }
}

///|
/// The compiler's `char0`.
fn Cursor::peek(self : Cursor) -> Char? {
  self.read_at(self.unit).map(r => r.0)
}

///|
/// The compiler's `char1`.
fn Cursor::peek1(self : Cursor) -> Char? {
  match self.read_at(self.unit) {
    None => None
    Some((_, units, _)) => self.read_at(self.unit + units).map(r => r.0)
  }
}

///|
/// Past `char0`. At the end nothing changes.
fn Cursor::advance(self : Cursor) -> Unit {
  match self.read_at(self.unit) {
    None => ()
    Some((_, units, bytes)) => {
      self.unit += units
      self.byte += bytes
    }
  }
}

///|
/// The compiler's `get_position()`: the byte offset of `char0`, or the byte
/// length of the text at the end.
fn Cursor::position(self : Cursor) -> Int32 {
  self.byte
}

///|
fn Cursor::unit(self : Cursor) -> Int32 {
  self.unit
}

///|
fn Cursor::at_end(self : Cursor) -> Bool {
  self.unit >= self.text.length()
}

///|
/// The text from unit `start_unit` to `char0`, raw (`\r\n` stays `\r\n`).
fn Cursor::slice(self : Cursor, start_unit : Int32) -> String {
  self.text.unsafe_substring(start=start_unit, end=self.unit)
}
