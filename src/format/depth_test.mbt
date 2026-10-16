///|
/// The deepest module the parser accepts for `construct` (the parser's
/// limit is the fuel budget).
fn deepest(construct : @lawkit.Construct) -> Int32 {
  let mut depth = 1
  while !@parser.parse_text(@lawkit.nested(construct, depth + 1)).has_errors() {
    depth += 1
  }
  depth
}

///|
test "the deepest module the parser accepts formats on every target, for every construct" {
  @expect.expect_all(s => {
    for construct in @lawkit.Construct::all() {
      let depth = deepest(construct)
      let text = @lawkit.nested(construct, depth)
      let formatted = try {
        @format.format(text) |> ignore
        "formatted"
      } catch {
        ParseFailed(_) => "ParseFailed"
        OutOfFuel(_) => "OutOfFuel"
      }
      s.expect((construct, formatted)).to_equal((construct, "formatted"))
      // One level deeper, the parser stops first: ParseFailed, not OutOfFuel.
      let deeper = try {
        @format.format(@lawkit.nested(construct, depth + 1)) |> ignore
        "formatted"
      } catch {
        ParseFailed(_) => "ParseFailed"
        OutOfFuel(_) => "OutOfFuel"
      }
      s.expect((construct, deeper)).to_equal((construct, "ParseFailed"))
    }
  })
}

///|
test "a smaller fuel budget stops the formatter with OutOfFuel when the parser got through" {
  // Parse with the default budget, format with a budget of 3.
  let r = @parser.parse_text(@lawkit.nested(List, 20))
  let small : @config.Config = {
    ..@config.Config::default(),
    fuel: @fuel.Budget::new(3).unwrap(),
  }
  let out = try {
    @format.format_parsed(r, config=small) |> ignore
    "formatted"
  } catch {
    OutOfFuel(FuelExhausted(budget~, ..)) =>
      "OutOfFuel budget=\{budget.units()}"
    ParseFailed(_) => "ParseFailed"
  }
  inspect(out, content="OutOfFuel budget=3")
}

///|
test "a list of 10,000 items formats on every target" {
  let items = []
  for _ in 0..<10_000 {
    items.push("    1,")
  }
  let text = "pub fn main() {\n  [\n" + items.join("\n") + "\n  ]\n}\n"
  let formatted = @format.format(text)
  @expect.expect_all(s => {
    s.expect(formatted == text).to_equal(true)
    s
    .expect(formatted.has_prefix("pub fn main() {\n  [\n    1,"))
    .to_equal(true)
  })
}
