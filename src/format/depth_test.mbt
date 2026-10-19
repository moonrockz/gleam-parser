///|
test "every nesting construct formats beyond the former default limit" {
  for construct in @lawkit.Construct::all() {
    let text = @lawkit.nested(construct, 512)
    let formatted = @format.format(text)
    @expect.expect(@parser.parse_text(formatted).has_errors()).to_be_false()
    @expect.expect(@format.format(formatted)).to_equal(formatted)
  }
}

///|
test "deep guards and bit array sizes format without a nesting cap" {
  let texts = [
    "fn f(x) { case x { _ if " + "!".repeat(2000) + "x -> 1 } }",
    "fn f(x) { case x { <<a:size(" +
    "{".repeat(512) +
    "1" +
    "}".repeat(512) +
    ")>> -> a } }",
    "fn f(x) { [" + "!".repeat(10000) + "x] }",
    "type T = " + "fn() -> ".repeat(512) + "Int",
  ]
  for text in texts {
    let formatted = @format.format(text)
    @expect.expect_all(s => {
      s.expect(@parser.parse_text(formatted).has_errors()).to_be_false()
      s.expect(@format.format(formatted)).to_equal(formatted)
    })
  }
}

///|
test "a finite budget larger than the old stack limit works on every target" {
  let config : @config.Config = {
    ..@config.Config::default(),
    fuel: Limited(@fuel.Budget(3000)),
  }
  let text = "fn f(x) { " + "!".repeat(2000) + "x }"
  let formatted = @format.format(text, config~)
  @expect.expect(@parser.parse_text(formatted, config~).has_errors()).to_be_false()
}

///|
test "a smaller fuel budget stops the formatter with OutOfFuel when the parser got through" {
  // Parse with the default budget, format with a budget of 3.
  let r = @parser.parse_text(@lawkit.nested(List, 20))
  let small : @config.Config = {
    ..@config.Config::default(),
    fuel: Limited(@fuel.Budget::from_int(3).unwrap()),
  }
  let out = try {
    @format.format_parsed(r, config=small) |> ignore
    "formatted"
  } catch {
    OutOfFuel(FuelExhausted(budget~, ..)) =>
      "OutOfFuel budget=\{budget.units()}"
    ParseFailed(_) => "ParseFailed"
    DialectMismatch(..) => "DialectMismatch"
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
