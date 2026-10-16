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
