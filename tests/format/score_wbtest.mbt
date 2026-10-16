///|
test "regressions names the counts below the baseline" {
  let base : Counts = {
    fixtures: 10,
    fixtures_matched: 5,
    corpus: 3,
    corpus_matched: 2,
  }
  @expect.expect_all(s => {
    s
    .expect(regressions({ ..base, fixtures_matched: 4, }, base))
    .to_equal(["fixtures_matched: 4 < baseline 5"])
    s.expect(regressions(base, base)).to_equal([])
    s.expect(counts_from_json(counts_to_json(base))).to_equal(base)
  })
}

///|
test "first_difference reports the first differing line" {
  @expect.expect_all(s => {
    s
    .expect(first_difference("a\nb\n", "a\nc\n"))
    .to_equal("line 2:\n  expected: b\n  actual:   c")
    // "a\n" splits into two lines, the second one empty.
    s
    .expect(first_difference("a\n", "a\nb\n"))
    .to_equal("line 2:\n  expected: \n  actual:   b")
    s
    .expect(first_difference("a", "a\nb"))
    .to_equal("line 2: expected 1 lines, actual 2")
  })
}

///|
/// Format parity counts.
priv struct Counts {
  fixtures : Int32
  fixtures_matched : Int32
  corpus : Int32
  corpus_matched : Int32
} derive(Eq, Debug)

///|
fn counts_to_json(c : Counts) -> Json {
  {
    "fixtures": Json(c.fixtures),
    "fixtures_matched": Json(c.fixtures_matched),
    "corpus": Json(c.corpus),
    "corpus_matched": Json(c.corpus_matched),
  }
}

///|
fn counts_from_json(json : Json) -> Counts raise {
  guard json is Object(o) &&
    o.get("fixtures") is Some(Number(a, ..)) &&
    o.get("fixtures_matched") is Some(Number(b, ..)) &&
    o.get("corpus") is Some(Number(c, ..)) &&
    o.get("corpus_matched") is Some(Number(d, ..)) else {
    fail(
      "baseline: expected fixtures, fixtures_matched, corpus and corpus_matched",
    )
  }
  {
    fixtures: a.to_int(),
    fixtures_matched: b.to_int(),
    corpus: c.to_int(),
    corpus_matched: d.to_int(),
  }
}

///|
fn scoreboard(c : Counts) -> String {
  "format parity: \{c.fixtures_matched}/\{c.fixtures} fixtures, \{c.corpus_matched}/\{c.corpus} corpus files"
}

///|
/// Names of the counts below the baseline, with both values.
fn regressions(current : Counts, baseline : Counts) -> Array[String] {
  let found = []
  for
    p in [
      ("fixtures_matched", current.fixtures_matched, baseline.fixtures_matched),
      ("corpus_matched", current.corpus_matched, baseline.corpus_matched),
    ] {
    let (name, now, min) = p
    if now < min {
      found.push("\{name}: \{now} < baseline \{min}")
    }
  }
  found
}

///|
/// The first line that differs, with both texts, for a mismatch report.
fn first_difference(expected : String, actual : String) -> String {
  let e = expected.split("\n").map(l => l.to_owned()).to_array()
  let a = actual.split("\n").map(l => l.to_owned()).to_array()
  let n = if e.length() < a.length() { e.length() } else { a.length() }
  for i in 0..<n {
    if e[i] != a[i] {
      return "line \{i + 1}:\n  expected: \{e[i]}\n  actual:   \{a[i]}"
    }
  }
  "line \{n + 1}: expected \{e.length()} lines, actual \{a.length()}"
}
