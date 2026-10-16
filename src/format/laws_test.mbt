///|
/// The error diagnostics of a parse of `text`.
fn errors_of(text : String) -> Int32 {
  @parser.parse_text(text).diagnostics.filter(d => d.severity is Error).length()
}

///|
test "law: format is idempotent on generated modules" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let once = @format.format(m.text()) catch { _ => return false }
      let twice = @format.format(once) catch { _ => return false }
      once == twice
    },
    count=200,
    max_size=30,
    seed=2034,
  )
}

///|
test "law: the output of format parses with no diagnostic and the same definition count" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let before = @parser.parse_text(m.text())
      let out = @format.format(m.text()) catch { _ => return false }
      let after = @parser.parse_text(out)
      after.diagnostics.length() == 0 &&
      after.module_.definitions.length() == before.module_.definitions.length()
    },
    count=200,
    max_size=30,
    seed=2035,
  )
}

///|
/// How many times `needle` occurs in `text` as a whole comment line.
fn count_comment(text : String, needle : String) -> Int32 {
  let mut n = 0
  for line in text.split("\n") {
    if line.trim() == needle {
      n += 1
    }
  }
  n
}

///|
test "law: every comment of the input is in the output exactly once, and the output is idempotent" {
  @quickcheck.check(
    (c : @lawkit.Commented) => {
      // The input is valid and clean: a comment between a doc comment or an
      // attribute and its definition would be a detached-doc warning.
      if @parser.parse_text(c.text()).diagnostics.length() != 0 {
        return false
      }
      let out = @format.format(c.text()) catch { _ => return false }
      let kept = c
        .comments()
        .iter()
        .all(needle => count_comment(out, needle) == 1)
      let again = @format.format(out) catch { _ => return false }
      kept && again == out && errors_of(out) == 0
    },
    count=150,
    max_size=25,
    seed=2036,
  )
}
