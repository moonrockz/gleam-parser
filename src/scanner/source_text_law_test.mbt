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
      st.byte_length().to_int() == reference_byte_length(u.text()) &&
      st.line_count().to_int() == reference_line_count(u.text())
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
        match st.byte_offset_of(@span.Utf16Offset::new(i).unwrap()) {
          Some(b) =>
            ok = ok &&
              st.utf16_offset_of(b) == Some(@span.Utf16Offset::new(i).unwrap())
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
      let mut previous : @span.Position? = None
      for b = 0; b <= st.byte_length().to_int(); b = b + 1 {
        match @span.ByteOffset::new(b).bind(x => st.position_of(x)) {
          None => ()
          Some(p) => {
            if previous is Some(prev) {
              let same_line = p.line == prev.line &&
                p.column.to_int() == prev.column.to_int() + 1
              let next_line = p.line.to_int() == prev.line.to_int() + 1 &&
                p.column.to_int() == 1
              ok = ok && (same_line || next_line)
            } else {
              ok = ok && p == @span.Position::new(1, 1).unwrap()
            }
            previous = Some(p)
          }
        }
      }
      ok && previous.map(p => p.line.to_int()) == Some(st.line_count().to_int())
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
      for b = -2; b <= st.byte_length().to_int() + 2; b = b + 1 {
        @span.ByteOffset::new(b).bind(x => st.position_of(x)) |> ignore
        @span.ByteOffset::new(b).bind(x => st.utf16_offset_of(x)) |> ignore
        @span.Utf16Offset::new(b).bind(x => st.byte_offset_of(x)) |> ignore
      }
      true
    },
    count=100,
    max_size=24,
    seed=2029,
  )
}

///|
/// Reference position: walk the units, count code points per line, and start
/// a new line after `\n`, after a lone `\r`, and after the `\n` of CRLF.
/// `None` when `byte` is not a code point boundary.
fn reference_position(text : String, byte : Int32) -> @span.Position? {
  let mut line = 1
  let mut column = 1
  let mut bytes = 0
  let mut i = 0
  while true {
    if bytes == byte {
      return Some(@span.Position::new(line, column).unwrap())
    }
    if i >= text.length() || bytes > byte {
      return None
    }
    let c = text.code_unit_at(i).to_int()
    if c == '\n'.to_int() {
      bytes += 1
      i += 1
      line += 1
      column = 1
    } else if c == '\r'.to_int() {
      bytes += 1
      i += 1
      if i < text.length() && text.code_unit_at(i).to_int() == '\n'.to_int() {
        // The boundary between `\r` and `\n` is still on the old line.
        if bytes == byte {
          return Some(@span.Position::new(line, column + 1).unwrap())
        }
        bytes += 1
        i += 1
      }
      line += 1
      column = 1
    } else {
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
      column += 1
    }
  }
  None
}

///|
/// Edge values: byte 0; the boundary between `\r` and `\n`; the end of the
/// text; bytes inside multi-byte characters (both sides give `None`).
test "law: position_of agrees with a reference count over the source" {
  @quickcheck.check(
    (u : @lawkit.Units) => {
      let text = u.text()
      let st = @scanner.SourceText::new(text)
      let mut ok = true
      for b = 0; b <= st.byte_length().to_int(); b = b + 1 {
        ok = ok &&
          @span.ByteOffset::new(b).bind(x => st.position_of(x)) ==
          reference_position(text, b)
      }
      ok
    },
    count=300,
    max_size=24,
    seed=2030,
  )
}
