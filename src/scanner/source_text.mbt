///|
/// A source text with lookups between its UTF-16 offsets (MoonBit strings),
/// its UTF-8 byte offsets (the compiler's `SrcSpan`) and 1-based line and
/// column positions.
///
/// Code point boundaries are kept in two parallel sorted arrays:
/// `bound_bytes[k]` and `bound_units[k]` are the byte and UTF-16 offsets
/// of the k-th boundary; the last boundary is the end of the text. The low
/// unit of a surrogate pair is not a boundary. `line_bounds[l]` is the
/// boundary index of line `l + 1`'s first character.
pub struct SourceText {
  priv text : String
  priv bound_bytes : Array[Int32]
  priv bound_units : Array[Int32]
  priv line_bounds : Array[Int32]
}

///|
fn is_high(c : Int32) -> Bool {
  c >= 0xD800 && c <= 0xDBFF
}

///|
fn is_low(c : Int32) -> Bool {
  c >= 0xDC00 && c <= 0xDFFF
}

///|
/// ```mbt check
/// test {
///   let st = @scanner.SourceText::new("é\nx")
///   debug_inspect(st.byte_length(), content="4")
///   debug_inspect(st.position_of(3), content="Some({ line: 2, column: 1 })")
///   debug_inspect(st.utf16_offset_of(3), content="Some(2)")
/// }
/// ```
pub fn SourceText::new(text : String) -> SourceText {
  let n = text.length()
  let bound_bytes = [0]
  let bound_units = [0]
  let line_bounds = [0]
  let mut byte = 0
  let mut i = 0
  while i < n {
    let c = text.code_unit_at(i).to_int()
    if c == '\n'.to_int() {
      byte += 1
      i += 1
      line_bounds.push(bound_bytes.length())
    } else if c == '\r'.to_int() {
      // `\r\n` and a lone `\r` are one line break, as in the Gleam lexer.
      if i + 1 < n && text.code_unit_at(i + 1).to_int() == '\n'.to_int() {
        byte += 1
        i += 1
        bound_bytes.push(byte)
        bound_units.push(i)
      }
      byte += 1
      i += 1
      line_bounds.push(bound_bytes.length())
    } else if c < 0x80 {
      byte += 1
      i += 1
    } else if c < 0x800 {
      byte += 2
      i += 1
    } else if is_high(c) &&
      i + 1 < n &&
      is_low(text.code_unit_at(i + 1).to_int()) {
      byte += 4
      i += 2
    } else {
      // Three bytes: a BMP character, or a lone surrogate counted as WTF-8.
      byte += 3
      i += 1
    }
    bound_bytes.push(byte)
    bound_units.push(i)
  }
  { text, bound_bytes, bound_units, line_bounds, }
}

///|
pub fn SourceText::text(self : SourceText) -> String {
  self.text
}

///|
/// The length of the text in UTF-8 bytes.
pub fn SourceText::byte_length(self : SourceText) -> Int32 {
  self.bound_bytes[self.bound_bytes.length() - 1]
}

///|
/// The number of lines: one more than the number of line breaks.
pub fn SourceText::line_count(self : SourceText) -> Int32 {
  self.line_bounds.length()
}

///|
/// Index of `x` in the sorted array `xs`, or `None`.
fn find(xs : Array[Int32], x : Int32) -> Int32? {
  let mut lo = 0
  let mut hi = xs.length() - 1
  while lo <= hi {
    let mid = lo + (hi - lo) / 2
    if xs[mid] == x {
      return Some(mid)
    } else if xs[mid] < x {
      lo = mid + 1
    } else {
      hi = mid - 1
    }
  }
  None
}

///|
/// The largest index `i` with `xs[i] <= x`; `xs` is sorted and `xs[0] <= x`.
fn floor_index(xs : Array[Int32], x : Int32) -> Int32 {
  let mut lo = 0
  let mut hi = xs.length() - 1
  while lo < hi {
    let mid = lo + (hi - lo + 1) / 2
    if xs[mid] <= x {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  lo
}

///|
/// The byte offset of the code point boundary at UTF-16 offset `utf16`, or
/// `None` when `utf16` is out of range or is the low unit of a surrogate
/// pair.
pub fn SourceText::byte_offset_of(self : SourceText, utf16 : Int32) -> Int32? {
  find(self.bound_units, utf16).map(k => self.bound_bytes[k])
}

///|
/// The UTF-16 offset of the code point boundary at byte offset `byte`, or
/// `None` when `byte` is out of range or inside a multi-byte character.
pub fn SourceText::utf16_offset_of(self : SourceText, byte : Int32) -> Int32? {
  find(self.bound_bytes, byte).map(k => self.bound_units[k])
}

///|
/// The 1-based line and column of the code point boundary at byte offset
/// `byte`; columns count code points. `None` when `byte` is not a boundary.
pub fn SourceText::position_of(
  self : SourceText,
  byte : Int32,
) -> @span.Position? {
  find(self.bound_bytes, byte).map(k => {
    let line = floor_index(self.line_bounds, k)
    @span.Position::new(line + 1, k - self.line_bounds[line] + 1)
  })
}

///|
/// The text of a byte span, or `None` when an end of the span is not a code
/// point boundary of the text.
pub fn SourceText::slice(self : SourceText, span : @span.SrcSpan) -> String? {
  match (self.utf16_offset_of(span.start), self.utf16_offset_of(span.end)) {
    (Some(a), Some(b)) if a <= b => Some(self.text[a:b].to_owned())
    _ => None
  }
}
