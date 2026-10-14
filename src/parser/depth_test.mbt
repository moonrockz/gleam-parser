///|
test "json_depth agrees with the canonical JSON's depth on small modules" {
  // Count the depth of the encoded JSON with a walk over the Json value and
  // compare with json_depth for several shapes.
  fn depth_of(j : Json) -> Int32 {
    match j {
      Object(m) => {
        let mut best = 0
        for _, v in m {
          let d = 1 + depth_of(v)
          if d > best {
            best = d
          }
        }
        best
      }
      Array(xs) => {
        let mut best = 0
        for v in xs {
          let d = 1 + depth_of(v)
          if d > best {
            best = d
          }
        }
        best
      }
      _ => 0
    }
  }

  let texts = [
    "const x = 1", "import gleam/io.{a, type B}", "pub type T(a) {\n  A(label: List(a), Int)\n}",
    "type A =\n  fn(a, #(b, _)) -> mod.Thing(a)", "fn f(a: Int, b) -> Int {\n  let assert Ok(x) = g(a, b, _) as \"m\"\n  use y, z: Int <- h()\n  case x, y {\n    #(p, [q, ..r]) | _, Some(..) if p.0 == q && !r -> <<x:size(y)-unit(2), 1>>\n    _, _ -> Point(..z, a: 1)\n  }\n  echo x |> f(1, _) |> g\n}",
    "@external(erlang, \"a\", \"b\")\npub fn f() -> Int", "const c = <<1, 2:size(8)>>",
    "const d = Wibble(..base, a: 1)", "const e = [1, ..f]", "fn g(x) {\n  todo as \"m\"\n  panic\n  !x\n  -x\n  x.1\n  x.field\n  { 1 }\n  fn() { x }\n  [x, ..x]\n  #(x)\n}",
  ]
  @expect.expect_all(e => {
    for text in texts {
      let r = @parser.parse_text(text)
      e.expect(r.has_errors()).to_be_false()
      let d = r.module_.definitions[0].definition
      e
      .expect((text, @parser.json_depth(d)))
      .to_equal((text, depth_of(@ast.encode_definition(d))))
    }
  })
}
