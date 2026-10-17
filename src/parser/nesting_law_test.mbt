///|
fn nesting_kinds(r : @parser.ParseResult) -> Array[String] {
  r.diagnostics.map(d => "\{d.code} \{d.kind}")
}

///|
test "an explicit budget rejects deep lists in function bodies without overflowing" {
  let text = "pub fn f() {\n  " +
    "[".repeat(120) +
    "1" +
    "]".repeat(120) +
    "\n}\n"
  let result = @parser.parse_text(text, config=with_fuel(100))
  @expect.expect_all(e => {
    e.expect(nesting_kinds(result)).to_equal(["GL-PARSE-004 TooMuchNesting"])
    e.expect(result.cst.to_source()).to_equal(text)
  })
}

///|
fn round_trips(r : @parser.ParseResult) -> Bool {
  let parsed = r.parsed()
  let text = @ast.canonical(@ast.encode_parsed(parsed))
  try @ast.decode_parsed(@json.parse(text)) catch {
    _ => false
  } noraise {
    back => back == parsed
  }
}

///|
test "law: every construct nested 20 deep parses and round-trips; 200 deep is one TooMuchNesting" {
  @expect.expect_all(e => {
    for c in @lawkit.Construct::all() {
      let shallow = @parser.parse_text(@lawkit.nested(c, 20))
      e.expect((c, nesting_kinds(shallow))).to_equal((c, []))
      e.expect((c, round_trips(shallow))).to_equal((c, true))
      let deep_text = @lawkit.nested(c, 200)
      let deep = @parser.parse_text(deep_text, config=with_fuel(100))
      e
      .expect((c, nesting_kinds(deep)))
      .to_equal((c, ["GL-PARSE-004 TooMuchNesting"]))
      e.expect((c, deep.module_.definitions.length())).to_equal((c, 0))
      e.expect((c, deep.cst.to_source() == deep_text)).to_equal((c, true))
    }
  })
}

///|
test "law: the deepest accepted nesting round-trips, and one level more is rejected" {
  @expect.expect_all(e => {
    for c in @lawkit.Construct::all() {
      let mut depth = 1
      while depth < 400 {
        if @parser.parse_text(@lawkit.nested(c, depth), config=with_fuel(100)).has_errors() {
          break
        }
        depth += 1
      }
      // The limit is reached well before 400 levels for every construct.
      e.expect((c, depth < 400)).to_equal((c, true))
      let last_ok = @parser.parse_text(
        @lawkit.nested(c, depth - 1),
        config=with_fuel(100),
      )
      e.expect((c, nesting_kinds(last_ok))).to_equal((c, []))
      e.expect((c, round_trips(last_ok))).to_equal((c, true))
      let rejected = @parser.parse_text(
        @lawkit.nested(c, depth),
        config=with_fuel(100),
      )
      e
      .expect((c, nesting_kinds(rejected)))
      .to_equal((c, ["GL-PARSE-004 TooMuchNesting"]))
    }
  })
}

///|
fn with_fuel(units : Int32) -> @config.Config {
  {
    ..@config.Config::default(),
    fuel: Limited(@fuel.Budget::from_int(units).unwrap()),
  }
}

///|
test "law: fuel n accepts depth n and rejects depth n + 1 for every construct" {
  @expect.expect_all(e => {
    for c in @lawkit.Construct::all() {
      // The depth an explicit budget of 100 accepts last.
      let mut depth = 1
      while depth < 400 {
        if @parser.parse_text(@lawkit.nested(c, depth), config=with_fuel(100)).has_errors() {
          break
        }
        depth += 1
      }
      let last_ok = depth - 1
      // One unit less rejects that depth; one unit more accepts one level more.
      let less = @parser.parse_text(
        @lawkit.nested(c, last_ok),
        config=with_fuel(99),
      )
      let more = @parser.parse_text(
        @lawkit.nested(c, depth),
        config=with_fuel(101),
      )
      e
      .expect((c, nesting_kinds(less)))
      .to_equal((c, ["GL-PARSE-004 TooMuchNesting"]))
      e.expect((c, nesting_kinds(more))).to_equal((c, []))
      e.expect((c, round_trips(more))).to_equal((c, true))
    }
  })
}

///|
test "law: a budget of 1 parses a flat module and rejects one nested list" {
  let flat = @parser.parse_text("const x = 1\n", config=with_fuel(1))
  let nested = @parser.parse_text("const x = [1]\n", config=with_fuel(1))
  @expect.expect_all(e => {
    e.expect(nesting_kinds(flat)).to_equal([])
    e.expect(nesting_kinds(nested)).to_equal(["GL-PARSE-004 TooMuchNesting"])
  })
}

///|
test "the definition after a nesting error parses with the full budget" {
  let text = "fn a() {\n  [[[[[[1]]]]]]\n}\n\nfn b() {\n  [[[[1]]]]\n}\n"
  let r = @parser.parse_text(text, config=with_fuel(5))
  @expect.expect_all(e => {
    e.expect(nesting_kinds(r)).to_equal(["GL-PARSE-004 TooMuchNesting"])
    e.expect(r.module_.definitions.length()).to_equal(1)
    e
    .expect(r.cst.definitions.map(d => d.kind))
    .to_equal([@cst.DefinitionKind::Skipped, Function])
  })
}

///|
test "the nesting error names the budget and the operations, outermost first" {
  let text = "fn f(x) {\n  case x {\n    [[[[y]]]] -> 1\n  }\n}\n"
  let r = @parser.parse_text(text, config=with_fuel(4))
  guard r.diagnostics.length() == 1 else { fail("one diagnostic expected") }
  let d = r.diagnostics[0]
  @expect.expect_all(e => {
    e.expect(d.code).to_equal("GL-PARSE-004")
    e.expect(d.message).to_equal("Recursion limit exceeded")
    e
    .expect(d.text)
    .to_equal(
      "The fuel budget of 4 ran out while nesting expression ×1, pattern ×3. gleam-parser spends one unit of fuel per nested level of syntax; the Gleam compiler has no such limit.",
    )
    e
    .expect(d.hint)
    .to_equal(
      Some(
        "Increase the configured budget, or use Config with fuel: Unlimited to remove the nesting limit.",
      ),
    )
  })
}

///|
/// The units a construct spends besides its own levels (the literal inside
/// the innermost list, the function body) are a fixed cost `k`; a budget
/// of `n + k` accepts depth `n` and rejects depth `n + 1`, for every small
/// `n`, not only at the default budget.
test "law: every small budget accepts exactly its depth of nested lists" {
  let mut last_ok = 0
  while last_ok < 400 &&
        !@parser.parse_text(
          @lawkit.nested(List, last_ok + 1),
          config=with_fuel(100),
        ).has_errors() {
    last_ok += 1
  }
  let k = @fuel.default_budget.units() - last_ok
  @expect.expect_all(e => {
    e.expect(k >= 1).to_be_true()
    for n in 1..<=10 {
      let ok = @parser.parse_text(
        @lawkit.nested(List, n),
        config=with_fuel(n + k),
      )
      let too_deep = @parser.parse_text(
        @lawkit.nested(List, n + 1),
        config=with_fuel(n + k),
      )
      e.expect((n, nesting_kinds(ok))).to_equal((n, []))
      e
      .expect((n, nesting_kinds(too_deep)))
      .to_equal((n, ["GL-PARSE-004 TooMuchNesting"]))
    }
  })
}
