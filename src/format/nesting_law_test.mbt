///|
test "law: format never crashes on any text: formatted text or ParseFailed" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      try {
        @format.format(text) |> ignore
        true
      } catch {
        ParseFailed(_) => true
        OutOfFuel(_) | DialectMismatch(..) => false
      }
    },
    count=200,
    max_size=40,
    seed=2032,
  )
}

///|
/// The never-crash law above reaches the formatter in about one case in
/// ten (`GleamText` is mostly invalid text); this law reaches it always.
test "law: a generated module formats with no error" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      try {
        @format.format(m.text()) |> ignore
        true
      } catch {
        _ => false
      }
    },
    count=200,
    max_size=30,
    seed=2033,
  )
}
