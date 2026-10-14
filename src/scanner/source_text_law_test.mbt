///|
/// Reference: count bytes of one UTF-16 unit sequence the way `SourceText`
/// must, written as simply as possible.
fn reference_byte_length(text : String) -> Int32 {
  let mut bytes = 0
  let mut i = 0
  while i < text.length() {
    let c = text.code_unit_at(i).to_int()
    if c < 0x80 {
      bytes += 1
      i += 1
    } else if c < 0x800 {
      bytes += 2
      i += 1
    } else if c >= 0xD800 &&
      c <= 0xDBFF &&
      i + 1 < text.length() &&
      text.code_unit_at(i + 1).to_int() >= 0xDC00 &&
      text.code_unit_at(i + 1).to_int() <= 0xDFFF {
      bytes += 4
      i += 2
    } else {
      bytes += 3
      i += 1
    }
  }
  bytes
}

///|
/// Reference line count: `\n`, `\r\n` and lone `\r` each break a line.
fn reference_line_count(text : String) -> Int32 {
  let mut lines = 1
  let mut i = 0
  while i < text.length() {
    let c = text.code_unit_at(i).to_int()
    if c == '\n'.to_int() {
      lines += 1
    } else if c == '\r'.to_int() {
      lines += 1
      if i + 1 < text.length() &&
        text.code_unit_at(i + 1).to_int() == '\n'.to_int() {
        i += 1
      }
    }
    i += 1
  }
  lines
}

///|
/// Edge values: empty text; every `edge_chars()` item; `\r` at the end;
/// `\r\n` split across pieces; a pair split by a line break.
test "law: byte_length and line_count agree with the reference" {
  @quickcheck.check(
    (u : @lawkit.Units) => {
      let st = @scanner.SourceText::new(u.text())
      st.byte_length() == reference_byte_length(u.text()) &&
      st.line_count() == reference_line_count(u.text())
    },
    count=300,
    max_size=24,
    seed=2026,
  )
}

///|
test "law: byte_offset_of and utf16_offset_of are inverse at every boundary" {
  @quickcheck.check(
    (u : @lawkit.Units) => {
      let text = u.text()
      let st = @scanner.SourceText::new(text)
      let mut ok = true
      for i = 0; i <= text.length(); i = i + 1 {
        match st.byte_offset_of(i) {
          Some(b) => ok = ok && st.utf16_offset_of(b) == Some(i)
          None => {
            // Only the low unit of a surrogate pair has no boundary.
            let low = i > 0 &&
              i < text.length() &&
              text.code_unit_at(i - 1).to_int() >= 0xD800 &&
              text.code_unit_at(i - 1).to_int() <= 0xDBFF &&
              text.code_unit_at(i).to_int() >= 0xDC00 &&
              text.code_unit_at(i).to_int() <= 0xDFFF
            ok = ok && low
          }
        }
      }
      ok
    },
    count=300,
    max_size=24,
    seed=2027,
  )
}

///|
test "law: positions are monotonic and columns restart after a line break" {
  @quickcheck.check(
    (u : @lawkit.Units) => {
      let text = u.text()
      let st = @scanner.SourceText::new(text)
      let mut ok = true
      let mut previous = @span.Position::new(1, 0)
      for b = 0; b <= st.byte_length(); b = b + 1 {
        match st.position_of(b) {
          None => ()
          Some(p) => {
            let same_line = p.line == previous.line &&
              p.column == previous.column + 1
            let next_line = p.line == previous.line + 1 && p.column == 1
            ok = ok && (same_line || next_line)
            previous = p
          }
        }
      }
      ok && previous.line == st.line_count()
    },
    count=300,
    max_size=24,
    seed=2028,
  )
}

///|
test "law: no byte offset makes a lookup panic" {
  @quickcheck.check(
    (u : @lawkit.Units) => {
      let st = @scanner.SourceText::new(u.text())
      for b = -2; b <= st.byte_length() + 2; b = b + 1 {
        st.position_of(b) |> ignore
        st.utf16_offset_of(b) |> ignore
        st.byte_offset_of(b) |> ignore
      }
      true
    },
    count=100,
    max_size=24,
    seed=2029,
  )
}
