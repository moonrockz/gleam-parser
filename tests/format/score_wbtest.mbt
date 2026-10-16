///|
test "regressions names the counts below the baseline and the totals that differ" {
  let base : Counts = {
    fixtures: 10,
    fixtures_matched: 5,
    fixtures_idempotent: 10,
    fixtures_reparsed: 10,
    corpus: 3,
    corpus_matched: 2,
    corpus_idempotent: 3,
    corpus_reparsed: 3,
  }
  @expect.expect_all(s => {
    s
    .expect(regressions({ ..base, fixtures_matched: 4, }, base))
    .to_equal(["fixtures_matched: 4 < baseline 5"])
    s
    .expect(regressions({ ..base, corpus_idempotent: 2, }, base))
    .to_equal(["corpus_idempotent: 2 < baseline 3"])
    s
    .expect(regressions({ ..base, fixtures: 9, }, base))
    .to_equal(["fixtures: 9 != baseline 10"])
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
/// Format parity counts: per source, the files, the files whose output is
/// the binary's, the files whose output formats to itself, and the files
/// whose output parses with no error.
priv struct Counts {
  fixtures : Int32
  fixtures_matched : Int32
  fixtures_idempotent : Int32
  fixtures_reparsed : Int32
  corpus : Int32
  corpus_matched : Int32
  corpus_idempotent : Int32
  corpus_reparsed : Int32
} derive(Eq, Debug)

///|
fn counts_to_json(c : Counts) -> Json {
  {
    "fixtures": Json(c.fixtures),
    "fixtures_matched": Json(c.fixtures_matched),
    "fixtures_idempotent": Json(c.fixtures_idempotent),
    "fixtures_reparsed": Json(c.fixtures_reparsed),
    "corpus": Json(c.corpus),
    "corpus_matched": Json(c.corpus_matched),
    "corpus_idempotent": Json(c.corpus_idempotent),
    "corpus_reparsed": Json(c.corpus_reparsed),
  }
}

///|
fn counts_from_json(json : Json) -> Counts raise {
  guard json is Object(o) else { fail("baseline: expected an object") }
  let field = (name : String) => {
    match o.get(name) {
      Some(Number(n, ..)) => n.to_int()
      _ => fail("baseline: missing count \{name}")
    }
  }
  {
    fixtures: field("fixtures"),
    fixtures_matched: field("fixtures_matched"),
    fixtures_idempotent: field("fixtures_idempotent"),
    fixtures_reparsed: field("fixtures_reparsed"),
    corpus: field("corpus"),
    corpus_matched: field("corpus_matched"),
    corpus_idempotent: field("corpus_idempotent"),
    corpus_reparsed: field("corpus_reparsed"),
  }
}

///|
fn scoreboard(c : Counts) -> String {
  "format parity: \{c.fixtures_matched}/\{c.fixtures} fixtures (\{c.fixtures_idempotent} idempotent, \{c.fixtures_reparsed} reparsed), \{c.corpus_matched}/\{c.corpus} corpus files (\{c.corpus_idempotent} idempotent, \{c.corpus_reparsed} reparsed)"
}

///|
/// The totals that differ from the baseline and the matched counts below
/// it, with both values.
fn regressions(current : Counts, baseline : Counts) -> Array[String] {
  let found = []
  for
    p in [
      ("fixtures", current.fixtures, baseline.fixtures),
      ("corpus", current.corpus, baseline.corpus),
    ] {
    let (name, now, expected) = p
    if now != expected {
      found.push("\{name}: \{now} != baseline \{expected}")
    }
  }
  for
    p in [
      ("fixtures_matched", current.fixtures_matched, baseline.fixtures_matched),
      (
        "fixtures_idempotent",
        current.fixtures_idempotent,
        baseline.fixtures_idempotent,
      ),
      (
        "fixtures_reparsed",
        current.fixtures_reparsed,
        baseline.fixtures_reparsed,
      ),
      ("corpus_matched", current.corpus_matched, baseline.corpus_matched),
      (
        "corpus_idempotent",
        current.corpus_idempotent,
        baseline.corpus_idempotent,
      ),
      ("corpus_reparsed", current.corpus_reparsed, baseline.corpus_reparsed),
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

///|
test "a lock without a fetched corpus is an instruction, not a regression" {
  @expect.expect_all(s => {
    s
    .expect(corpus_problem(lock_exists=true, corpus_exists=false))
    .to_equal(
      Some(
        "tests/corpus/format.lock exists but .corpus does not; run mise run corpus:fetch",
      ),
    )
    s
    .expect(corpus_problem(lock_exists=false, corpus_exists=false))
    .to_equal(None)
    s
    .expect(corpus_problem(lock_exists=true, corpus_exists=true))
    .to_equal(None)
  })
}

///|
test "the ratchet keeps the maximum only when a source's total is unchanged" {
  let base : Counts = {
    fixtures: 10,
    fixtures_matched: 9,
    fixtures_idempotent: 10,
    fixtures_reparsed: 10,
    corpus: 3,
    corpus_matched: 3,
    corpus_idempotent: 3,
    corpus_reparsed: 3,
  }
  @expect.expect_all(s => {
    // Same totals: a lower count keeps the baseline, a higher one raises it.
    s
    .expect(
      ratchet_counts(
        { ..base, fixtures_matched: 8, corpus_matched: 3, },
        Some(base),
      ),
    )
    .to_equal(base)
    s
    .expect(ratchet_counts({ ..base, fixtures_matched: 10, }, Some(base)))
    .to_equal({ ..base, fixtures_matched: 10, })
    // A fixture went away: the fixture counts are the current ones, the
    // corpus counts keep the maximum.
    let fewer : Counts = {
      ..base,
      fixtures: 9,
      fixtures_matched: 9,
      fixtures_idempotent: 9,
      fixtures_reparsed: 9,
      corpus_matched: 2,
    }
    s
    .expect(ratchet_counts(fewer, Some(base)))
    .to_equal({ ..fewer, corpus_matched: 3, })
    s.expect(ratchet_counts(fewer, None)).to_equal(fewer)
  })
}
