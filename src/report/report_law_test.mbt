///|
test "law: rendering never crashes on any text, and starts with the severity" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      let r = @parser.parse_text(text)
      let source = @scanner.SourceText(text)
      r.diagnostics.all(d => {
        let out = @report.render_plain(d, source, "x.gleam")
        let prefix = if d.is_error() { "error: " } else { "warning: " }
        out.has_prefix(prefix + d.title) && out.has_suffix("\n")
      })
    },
    count=200,
    max_size=30,
    seed=2050,
  )
}

///|
test "law: locus columns use the nearest preceding source boundary" {
  let mut interiors = 0
  @quickcheck.check(
    (input : (@lawkit.Units, UInt32)) => {
      let text = input.0
        .text()
        .replace_all(old="\r", new="")
        .replace_all(old="\n", new="") +
        "x"
      let source = @scanner.SourceText(text)
      let raw = (input.1 %
      (source.byte_length().to_int() + 1).reinterpret_as_uint()).reinterpret_as_int()
      let offset = @span.ByteOffset::from_int(raw).unwrap()
      let mut boundary = offset
      while source.position_of(boundary) is None {
        boundary = boundary.shift(-1).unwrap()
      }
      if boundary != offset {
        interiors += 1
      }
      let expected = source.position_of(boundary).unwrap().column.to_int()
      let diagnostic = @diagnostic.Diagnostic(
        code="test",
        severity=Error,
        title="Locus",
        message="here",
        span=@span.SrcSpan::from_offsets(offset, offset).unwrap(),
      )
      @report.render_plain(diagnostic, source, "x.gleam").has_prefix(
        "error: Locus\n  ┌─ x.gleam:1:\{expected}\n",
      )
    },
    count=200,
    max_size=20,
    seed=2402,
  )
  @expect.expect(interiors > 0).to_be_true()
}
