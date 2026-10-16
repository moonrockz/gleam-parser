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
/// How many times the comment `needle` occurs in `text`: anywhere on a line
/// (the formatter can put a comment after `|`), but `// c2` does not count
/// inside `// c25`.
fn count_comment(text : String, needle : String) -> Int32 {
  let mut n = 0
  let pieces = text.split(needle).map(p => p.to_owned()).collect()
  for i in 1..<pieces.length() {
    match pieces[i].iter().head() {
      Some(c) => if !c.is_ascii_digit() { n += 1 }
      None => n += 1
    }
  }
  n
}

///|
test "count_comment counts a comment on a code line and not a longer number" {
  @expect.expect_all(s => {
    s.expect(count_comment("| // c2\n  // c25\n// c2", "// c2")).to_equal(2)
    s.expect(count_comment("// c25", "// c2")).to_equal(0)
    s.expect(count_comment("", "// c0")).to_equal(0)
  })
}

///|
test "law: every comment at a hard position (before `)`, `]`, `|>`, `->`, `|`, `as`, `..`) is in the output exactly once, and the output parses and is idempotent" {
  @quickcheck.check(
    (h : @lawkit.HardCommented) => {
      if @parser.parse_text(h.text()).diagnostics.length() != 0 {
        return false
      }
      let out = @format.format(h.text()) catch { _ => return false }
      let kept = h
        .comments()
        .iter()
        .all(needle => count_comment(out, needle) == 1)
      let again = @format.format(out) catch { _ => return false }
      // Errors only: the compiler moves a comment inside an attribute's
      // parentheses before the attribute, which detaches a doc comment
      // (a warning), and the port does the same.
      kept && again == out && errors_of(out) == 0
    },
    count=150,
    max_size=25,
    seed=2037,
  )
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
