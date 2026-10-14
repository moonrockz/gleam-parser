///|
/// The line breaks of a text that no token covers, by byte position (a
/// `\r\n` counts once, at the `\r`). A reference model for `new_lines`.
fn line_breaks_outside_tokens(
  text : String,
  stream : @scanner.TokenStream,
) -> Array[Int32] {
  let source = @scanner.SourceText::new(text)
  let out : Array[Int32] = []
  let mut i = 0
  while i < text.length() {
    let c = text.code_unit_at(i).to_int()
    // Inside a surrogate pair there is no code point boundary.
    guard source.byte_offset_of(i) is Some(byte) else {
      i += 1
      continue
    }
    let is_break = c == '\n'.to_int() ||
      (
        c == '\r'.to_int() &&
        !(i + 1 < text.length() &&
        text.code_unit_at(i + 1).to_int() == '\n'.to_int())
      )
    let cr_lf = c == '\r'.to_int() &&
      i + 1 < text.length() &&
      text.code_unit_at(i + 1).to_int() == '\n'.to_int()
    if is_break || cr_lf {
      if !stream.tokens.any(t => t.span.start <= byte && byte < t.span.end) {
        out.push(byte)
      }
    }
    i += if cr_lf { 2 } else { 1 }
  }
  out
}

///|
test "law: new_lines are the line breaks outside tokens, in order" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      let stream = @scanner.tokenize_text(text)
      let extra = @cst.trivia_extra(stream)
      extra.new_lines == line_breaks_outside_tokens(text, stream)[:]
    },
    count=300,
    max_size=30,
    seed=2068,
  )
}

///|
test "law: every empty line follows a line break by one byte, and comments are sorted" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let extra = @cst.trivia_extra(@scanner.tokenize_text(t.text()))
      let breaks = extra.new_lines
      let mut ok = true
      for e in extra.empty_lines {
        if !breaks.contains(e - 1) {
          ok = false
        }
      }
      fn sorted(xs : ArrayView[@span.SrcSpan]) -> Bool {
        let mut last = -1
        let mut s = true
        for x in xs {
          if x.start < last {
            s = false
          }
          last = x.start
        }
        s
      }

      ok &&
      sorted(extra.comments) &&
      sorted(extra.doc_comments) &&
      sorted(extra.module_comments)
    },
    count=300,
    max_size=30,
    seed=2069,
  )
}
