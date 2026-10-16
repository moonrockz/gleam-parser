///|
/// A label's style: the primary label (the diagnostic's span and message) or
/// an extra label.
priv enum Style {
  Primary
  Secondary
} derive(Eq)

///|
/// Output with optional ANSI colours, the `WriteStyle` of codespan.
priv struct Out {
  sb : StringBuilder
  color : Bool
  severity : @diagnostic.Severity
}

///|
fn Out::write(self : Out, s : String) -> Unit {
  self.sb.write_string(s)
}

///|
fn Out::code(self : Out, code : String) -> Unit {
  if self.color {
    self.sb.write_string("\u{1b}[\{code}m")
  }
}

///|
fn Out::set_header(self : Out) -> Unit {
  self.code(if self.severity is Error { "1;91" } else { "1;93" })
}

///|
fn Out::set_header_message(self : Out) -> Unit {
  self.code("1")
}

///|
fn Out::set_border(self : Out) -> Unit {
  self.code("34")
}

///|
fn Out::set_label(self : Out, style : Style) -> Unit {
  match style {
    Primary => self.code(if self.severity is Error { "31" } else { "33" })
    Secondary => self.code("34")
  }
}

///|
fn Out::reset(self : Out) -> Unit {
  self.code("0")
}

///|
/// One character of a source line: its byte index in the line, its display
/// width (a tab reaches the next tab stop; everything else is 1) and its
/// text.
priv struct CharInfo {
  byte : @span.ByteOffset
  width : Int32
  text : String
}

///|
priv struct SingleLabel {
  style : Style
  start : @span.ByteOffset
  end : @span.ByteOffset
  message : String
}

///|
priv enum MultiLabel {
  Top(@span.ByteOffset)
  Left
  Bottom(@span.ByteOffset, String)
}

///|
priv struct MultiEntry {
  index : Int32
  style : Style
  label : MultiLabel
}

///|
priv struct Line {
  number : @span.LineNumber
  start : @span.ByteOffset
  end : @span.ByteOffset
  single : Array[SingleLabel]
  multi : Array[MultiEntry]
  mut must_render : Bool
}

///|
let tab_width : Int32 = 4

///|
fn sp(a : @span.ByteOffset, b : @span.ByteOffset) -> @span.SrcSpan {
  @span.SrcSpan::from_compiler(a, b).unwrap()
}

///|
/// Byte offsets where lines start: 0 and the byte after each `\n`.
fn line_starts(source : @scanner.SourceText) -> Array[@span.ByteOffset] {
  let starts = [@span.ByteOffset::zero()]
  let text = source.text()
  for i in 0..<text.length() {
    if text.code_unit_at(i) == '\n'.to_int().to_uint16() {
      match source.byte_offset_of(@span.Utf16Offset::from_int(i + 1).unwrap()) {
        Some(b) => starts.push(b)
        None => ()
      }
    }
  }
  starts
}

///|
fn line_index(
  starts : Array[@span.ByteOffset],
  byte : @span.ByteOffset,
) -> Int32 {
  let mut lo = 0
  let mut hi = starts.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if starts[mid] <= byte {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  lo
}

///|
fn utf8_len(c : Int32) -> Int32 {
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// The characters of a line (its `\n`, `\r` and `\0` tail removed), with
/// byte indexes and widths.
fn line_chars(text : String) -> Array[CharInfo] {
  let trimmed = text.trim_end(chars="\n\r\u{0}")
  let chars : Array[CharInfo] = []
  let mut byte = @span.ByteOffset::zero()
  let mut column = 0
  for ch in trimmed {
    let code = ch.to_int()
    let width = if ch == '\t' { tab_width - column % tab_width } else { 1 }
    chars.push({
      byte,
      width,
      text: if ch == '\t' {
        String::make(width, ' ')
      } else {
        ch.to_string()
      },
    })
    byte = byte.shift(utf8_len(code)).unwrap()
    column += width
  }
  chars
}

///|
fn line_end_offset(chars : Array[CharInfo]) -> @span.ByteOffset {
  match chars.last() {
    Some(c) =>
      c.byte
      .shift(
        utf8_len(c.text.iter().head().map(x => x.to_int()).unwrap_or(0x20)),
      )
      .unwrap()
    None => @span.ByteOffset::zero()
  }
}

///|
fn leading_whitespace_end(chars : Array[CharInfo]) -> @span.ByteOffset {
  let mut n = @span.ByteOffset::zero()
  for c in chars {
    if c.text.trim_start(chars=" \t").length() == 0 {
      n = c.byte
        .shift(
          utf8_len(c.text.iter().head().map(x => x.to_int()).unwrap_or(0x20)),
        )
        .unwrap()
    } else {
      break
    }
  }
  n
}

///|
fn overlaps(
  a_start : @span.ByteOffset,
  a_end : @span.ByteOffset,
  b_start : @span.ByteOffset,
  b_end : @span.ByteOffset,
) -> Bool {
  let start = if a_start > b_start { a_start } else { b_start }
  let end = if a_end < b_end { a_end } else { b_end }
  start < end
}

///|
fn digits(n : Int32) -> Int32 {
  let mut n = n
  let mut d = 1
  while n >= 10 {
    n /= 10
    d += 1
  }
  d
}

///|
/// Render `d` as the Gleam compiler prints it: codespan's rich layout, an
/// empty line, the text, and the hint. `path` is the file name in the
/// locus line.
fn render(
  d : @diagnostic.Diagnostic,
  source : @scanner.SourceText,
  path : String,
  color : Bool,
) -> String {
  let out : Out = { sb: StringBuilder(), color, severity: d.severity, }
  let byte_length = source.end_offset()
  fn clamp(s : @span.SrcSpan) -> @span.SrcSpan {
    let a = if s.start > byte_length { byte_length } else { s.start }
    let b = if s.end < a {
      a
    } else if s.end > byte_length {
      byte_length
    } else {
      s.end
    }
    sp(a, b)
  }

  // The compiler moves an UnexpectedEof to the text's last byte.
  let primary = if d.kind == "UnexpectedEof" {
    let e = if byte_length > @span.ByteOffset::zero() {
      byte_length.shift(-1).unwrap()
    } else {
      @span.ByteOffset::zero()
    }
    sp(e, e)
  } else {
    clamp(d.span)
  }
  let labels : Array[(Style, @span.SrcSpan, String)] = [
    (Primary, primary, d.message),
  ]
  for l in d.labels {
    labels.push((Secondary, clamp(l.span), l.text))
  }
  let starts = line_starts(source)
  fn line_range(i : Int32) -> (@span.ByteOffset, @span.ByteOffset) {
    (
      starts[i],
      if i + 1 < starts.length() {
        starts[i + 1]
      } else {
        byte_length
      },
    )
  }

  let lines : Map[Int32, Line] = Map([])
  fn line_at(i : Int32) -> Line {
    match lines.get(i) {
      Some(l) => l
      None => {
        let (s, e) = line_range(i)
        let l : Line = {
          number: @span.LineNumber::from_int(i + 1).unwrap(),
          start: s,
          end: e,
          single: [],
          multi: [],
          must_render: false,
        }
        lines[i] = l
        l
      }
    }
  }

  let mut outer_padding = 0
  let mut num_multi = 0
  for label in labels {
    let (style, span, message) = label
    let start_line = line_index(starts, span.start)
    let end_line = line_index(starts, span.end)
    outer_padding = @cmp.maximum(outer_padding, digits(start_line + 1))
    outer_padding = @cmp.maximum(outer_padding, digits(end_line + 1))
    if start_line == end_line {
      let line = line_at(start_line)
      let label_start = @span.ByteOffset::from_int(
        span.start.to_int() - line.start.to_int(),
      ).unwrap()
      let label_end = @cmp.maximum(
        @span.ByteOffset::from_int(span.end.to_int() - line.start.to_int()).unwrap(),
        label_start.shift(1).unwrap(),
      )
      // Sorted by (start, end); equal ranges keep later labels first.
      let mut index = 0
      while index < line.single.length() &&
            (line.single[index].start, line.single[index].end) <
            (label_start, label_end) {
        index += 1
      }
      line.single.insert(index, {
        style,
        start: label_start,
        end: label_end,
        message,
      })
      line.must_render = true
    } else {
      let label_index = num_multi
      num_multi += 1
      let first = line_at(start_line)
      first.multi.push({
        index: label_index,
        style,
        label: Top(
          @span.ByteOffset::from_int(span.start.to_int() - first.start.to_int()).unwrap(),
        ),
      })
      first.must_render = true
      for i in (start_line + 1)..<end_line {
        let line = line_at(i)
        outer_padding = @cmp.maximum(outer_padding, digits(i + 1))
        line.multi.push({ index: label_index, style, label: Left, })
        line.must_render = line.must_render ||
          i - start_line <= 3 ||
          end_line - i <= 1
      }
      let last = line_at(end_line)
      last.multi.push({
        index: label_index,
        style,
        label: Bottom(
          @span.ByteOffset::from_int(span.end.to_int() - last.start.to_int()).unwrap(),
          message,
        ),
      })
      last.must_render = true
    }
  }

  // Header
  out.set_header()
  out.write(if d.severity is Error { "error" } else { "warning" })
  out.set_header_message()
  out.write(": \{d.title}")
  out.reset()
  out.write("\n")

  // Snippet
  let keys = lines.keys().collect()
  keys.sort()
  if keys.length() > 0 {
    let locus_line = line_index(starts, primary.start)
    let (ls, _) = line_range(locus_line)
    let column = match source.slice(sp(ls, primary.start)) {
      Some(before) => before.iter().count() + 1
      None => 1
    }
    outer_gutter(out, outer_padding)
    out.set_border()
    out.write("┌─")
    out.reset()
    out.write(" \{path}:\{locus_line + 1}:\{column}\n")
    snippet_empty(out, outer_padding, num_multi, [])
    let rendered = keys.filter(k => lines.get(k).unwrap().must_render)
    for n, k in rendered {
      let line = lines.get(k).unwrap()
      snippet_source(
        out,
        source,
        outer_padding,
        line,
        num_multi,
        line.single,
        line.multi,
      )
      if n + 1 < rendered.length() {
        let next = rendered[n + 1]
        if next - k == 2 {
          // One line between: print it, with its multi-label gutter.
          let (s, e) = line_range(k + 1)
          let between : Line = {
            number: @span.LineNumber::from_int(k + 2).unwrap(),
            start: s,
            end: e,
            single: [],
            multi: match lines.get(k + 1) {
              Some(l) => l.multi
              None => []
            },
            must_render: true,
          }
          snippet_source(
            out,
            source,
            outer_padding,
            between,
            num_multi,
            [],
            between.multi,
          )
        } else if next - k > 2 {
          outer_gutter(out, outer_padding)
          out.set_border()
          out.write("·")
          out.reset()
          inner_gutter(out, num_multi, lines.get(next).unwrap().multi)
          out.write("\n")
        }
      }
    }
  }
  out.write("\n")

  // Text and hint, as the compiler's Diagnostic::write.
  if d.text != "" {
    out.write(d.text)
    out.write("\n")
  }
  if d.hint is Some(hint) {
    if d.text != "" {
      out.write("\n")
    }
    out.write(@scanner.wrap("Hint: \{hint}"))
    out.write("\n")
  }
  out.sb.to_string()
}

///|
fn outer_gutter(out : Out, padding : Int32) -> Unit {
  out.write(String::make(padding, ' '))
  out.write(" ")
}

///|
fn border_left(out : Out) -> Unit {
  out.set_border()
  out.write("│")
  out.reset()
}

///|
fn label_multi_left(out : Out, style : Style, underline : Style?) -> Unit {
  match underline {
    None => out.write(" ")
    Some(s) => {
      out.set_label(s)
      out.write("─")
      out.reset()
    }
  }
  out.set_label(style)
  out.write("│")
  out.reset()
}

///|
/// The inner gutter of a plain source or caret line: `│` for a label that
/// continues on this line, spaces otherwise.
fn inner_gutter(
  out : Out,
  num_multi : Int32,
  multi : Array[MultiEntry],
) -> Unit {
  let mut next = 0
  for column in 0..<num_multi {
    if next < multi.length() && multi[next].index == column {
      match multi[next].label {
        Left | Bottom(_, _) => label_multi_left(out, multi[next].style, None)
        Top(_) => out.write("  ")
      }
      next += 1
    } else {
      out.write("  ")
    }
  }
}

///|
fn snippet_empty(
  out : Out,
  padding : Int32,
  num_multi : Int32,
  multi : Array[MultiEntry],
) -> Unit {
  outer_gutter(out, padding)
  border_left(out)
  inner_gutter(out, num_multi, multi)
  out.write("\n")
}

///|
/// A source line with its labels (codespan's `render_snippet_source`).
fn snippet_source(
  out : Out,
  source : @scanner.SourceText,
  padding : Int32,
  line : Line,
  num_multi : Int32,
  single : Array[SingleLabel],
  multi : Array[MultiEntry],
) -> Unit {
  let text = source.slice(sp(line.start, line.end)).unwrap_or("")
  let chars = line_chars(text)
  let source_len = line_end_offset(chars)
  let leading = leading_whitespace_end(chars)

  // The line number, border and inner gutter
  out.code("34")
  out.write(line.number.to_int().to_string().pad_start(padding, ' '))
  out.reset()
  out.write(" ")
  border_left(out)
  let mut next = 0
  for column in 0..<num_multi {
    if next < multi.length() && multi[next].index == column {
      let entry = multi[next]
      match entry.label {
        Top(start) if start <= leading => {
          out.write(" ")
          out.set_label(entry.style)
          out.write("╭")
          out.reset()
        }
        Top(_) => out.write("  ")
        Left | Bottom(_, _) => label_multi_left(out, entry.style, None)
      }
      next += 1
    } else {
      out.write("  ")
    }
  }

  // The source text, with the primary label's characters coloured
  out.write(" ")
  let mut in_primary = false
  for c in chars {
    let c_end = c.byte
      .shift(
        utf8_len(c.text.iter().head().map(x => x.to_int()).unwrap_or(0x20)),
      )
      .unwrap()
    let is_primary = single.any(l => {
        l.style == Primary && overlaps(l.start, l.end, c.byte, c_end)
      }) ||
      multi.any(m => {
        m.style == Primary &&
        (match m.label {
          Top(start) => c.byte >= start
          Left => true
          Bottom(start, _) => c_end <= start
        })
      })
    if is_primary && !in_primary {
      out.set_label(Primary)
      in_primary = true
    } else if !is_primary && in_primary {
      out.reset()
      in_primary = false
    }
    out.write(c.text)
  }
  if in_primary {
    out.reset()
  }
  out.write("\n")

  // Single-line labels underneath
  if single.length() > 0 {
    let mut max_label_start = @span.ByteOffset::zero()
    let mut max_label_end = @span.ByteOffset::zero()
    let mut trailing : Int32? = None
    for i, label in single {
      max_label_start = @cmp.maximum(max_label_start, label.start)
      max_label_end = @cmp.maximum(max_label_end, label.end)
      if label.end == max_label_end {
        trailing = if label.message == "" { None } else { Some(i) }
      }
    }
    if trailing is Some(t) {
      let candidate = single[t]
      for i, label in single {
        if i != t &&
          overlaps(candidate.start, candidate.end, label.start, label.end) {
          trailing = None
          break
        }
      }
    }
    fn style_at(byte : @span.ByteOffset, end : @span.ByteOffset) -> Style? {
      let mut best : Style? = None
      for l in single {
        if overlaps(l.start, l.end, byte, end) {
          if l.style == Primary {
            best = Some(Primary)
          } else if best is None {
            best = Some(Secondary)
          }
        }
      }
      best
    }

    // The caret line, with the trailing message
    outer_gutter(out, padding)
    border_left(out)
    inner_gutter(out, num_multi, multi)
    out.write(" ")
    let mut previous : Style? = None
    let all_chars = chars.copy()
    all_chars.push({ byte: source_len, width: 1, text: "\u{0}", })
    for c in all_chars {
      let c_end = c.byte
        .shift(
          if c.text == "\u{0}" {
            1
          } else {
            utf8_len(c.text.iter().head().map(x => x.to_int()).unwrap_or(0x20))
          },
        )
        .unwrap()
      let current = style_at(c.byte, c_end)
      if previous != current {
        match current {
          None => out.reset()
          Some(s) => out.set_label(s)
        }
      }
      let caret : String? = match current {
        Some(Primary) => Some("^")
        Some(Secondary) => Some("-")
        None => if c.byte < max_label_end { Some(" ") } else { None }
      }
      if caret is Some(ch) {
        for _ in 0..<c.width {
          out.write(ch)
        }
      }
      previous = current
    }
    if previous is Some(_) {
      out.reset()
    }
    if trailing is Some(t) {
      out.write(" ")
      out.set_label(single[t].style)
      out.write(single[t].message)
      out.reset()
    }
    out.write("\n")

    // Hanging labels
    let hanging : Array[SingleLabel] = []
    for i, label in single {
      if label.message != "" && !(trailing is Some(t) && t == i) {
        hanging.push(label)
      }
    }
    if hanging.length() > 0 {
      fn pointers(limit : @span.ByteOffset?) {
        for c in chars {
          if limit is Some(l) && c.byte >= l {
            break
          }
          let c_end = c.byte
            .shift(
              utf8_len(
                c.text.iter().head().map(x => x.to_int()).unwrap_or(0x20),
              ),
            )
            .unwrap()
          let mut style : Style? = None
          for h in hanging {
            if h.start >= c.byte && h.start < c_end {
              if h.style == Primary {
                style = Some(Primary)
              } else if style is None {
                style = Some(Secondary)
              }
            }
          }
          let mut spaces = c.width
          if style is Some(s) {
            out.set_label(s)
            out.write("│")
            out.reset()
            spaces -= 1
          }
          if c.byte <= max_label_start {
            for _ in 0..<spaces {
              out.write(" ")
            }
          }
        }
      }

      outer_gutter(out, padding)
      border_left(out)
      inner_gutter(out, num_multi, multi)
      out.write(" ")
      pointers(None)
      out.write("\n")
      let mut i = hanging.length() - 1
      while i >= 0 {
        let label = hanging[i]
        outer_gutter(out, padding)
        border_left(out)
        inner_gutter(out, num_multi, multi)
        out.write(" ")
        pointers(Some(label.start))
        out.set_label(label.style)
        out.write(label.message)
        out.reset()
        out.write("\n")
        i -= 1
      }
    }
  }

  // Top and bottom carets of multi-line labels
  for i, entry in multi {
    let (range, message) : (@span.ByteOffset, String?) = match entry.label {
      Left => continue
      Top(start) => if start <= leading { continue } else { (start, None) }
      Bottom(end, message) => (end, Some(message))
    }
    outer_gutter(out, padding)
    border_left(out)
    let mut underline : (Style, Bool)? = None // style, is top
    let mut next = 0
    for column in 0..<num_multi {
      if next < multi.length() && multi[next].index == column {
        let other = multi[next]
        let under_style = underline.map(u => u.0)
        match other.label {
          Left => label_multi_left(out, other.style, under_style)
          Top(_) if i > next => label_multi_left(out, other.style, under_style)
          Bottom(_, _) if i < next =>
            label_multi_left(out, other.style, under_style)
          Top(_) if i == next => {
            underline = Some((other.style, true))
            out.write(" ")
            out.set_label(entry.style)
            out.write("╭")
            out.reset()
          }
          Bottom(_, _) if i == next => {
            underline = Some((other.style, false))
            out.write(" ")
            out.set_label(entry.style)
            out.write("╰")
            out.reset()
          }
          _ => inner_gutter_column(out, underline)
        }
        next += 1
      } else {
        inner_gutter_column(out, underline)
      }
    }
    out.set_label(entry.style)
    match message {
      None => {
        for c in chars {
          if c.byte < range.shift(1).unwrap() {
            for _ in 0..<c.width {
              out.write("─")
            }
          }
        }
        out.write(if entry.style == Primary { "^" } else { "'" })
      }
      Some(m) => {
        for c in chars {
          if c.byte < range {
            for _ in 0..<c.width {
              out.write("─")
            }
          }
        }
        out.write(if entry.style == Primary { "^" } else { "'" })
        if m != "" {
          out.write(" \{m}")
        }
      }
    }
    out.reset()
    out.write("\n")
  }
}

///|
fn inner_gutter_column(out : Out, underline : (Style, Bool)?) -> Unit {
  match underline {
    None => out.write("  ")
    Some((style, _)) => {
      out.set_label(style)
      out.write("──")
      out.reset()
    }
  }
}

///|
/// The diagnostic as the Gleam compiler prints it, without colours.
///
/// ```mbt check
/// test {
///   let text = "const x 1\n"
///   let r = @parser.parse_text(text)
///   let out = @report.render_plain(
///     r.diagnostics[0],
///     @scanner.SourceText(text),
///     "x.gleam",
///   )
///   inspect(
///     out.has_prefix("error: Syntax error\n  ┌─ x.gleam:1:9\n"),
///     content="true",
///   )
/// }
/// ```
pub fn render_plain(
  d : @diagnostic.Diagnostic,
  source : @scanner.SourceText,
  path : String,
) -> String {
  render(d, source, path, false)
}

///|
/// `render_plain` with ANSI colours close to the compiler's.
pub fn render_terminal(
  d : @diagnostic.Diagnostic,
  source : @scanner.SourceText,
  path : String,
) -> String {
  render(d, source, path, true)
}
