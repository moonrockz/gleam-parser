///|
test "gen_module reaches every definition kind and construct over many seeds" {
  let markers = [
    "import ", "const ", "pub type ", "type ", " = \n", "fn ", "pub fn ", "@deprecated(",
    "@internal", "@target(", "@external(", "///", "////", "let assert ", "use ",
    "assert ", "case ", " if ", "|>", "<<", "#(", "..", " as ", "todo", "panic",
    "echo", "<>", "fn(", "Point(..", " | ",
  ]
  let seen : Set[String] = Set([])
  for seed in 0..<200 {
    let rs = @splitmix.RandomState(seed=seed.to_uint64())
    let text = @lawkit.gen_module(12, rs)
    for marker in markers {
      if text.contains(marker) {
        seen.add(marker)
      }
    }
  }
  let missing = markers.filter(m => !seen.contains(m))
  @expect.expect(missing).to_equal([])
}

///|
test "a GleamModule shrinks by dropping a definition" {
  let m = @lawkit.GleamModule("import gleam/io\n\nconst x = 1\n")
  let shrunk = m.shrink().collect()
  @expect.expect(shrunk.length()).to_equal(2)
}
