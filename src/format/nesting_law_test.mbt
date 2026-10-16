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
        OutOfFuel(_) => false
      }
    },
    count=200,
    max_size=40,
    seed=2032,
  )
}
