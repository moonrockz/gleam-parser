///|
fn nesting_kinds(r : @parser.ParseResult) -> Array[String] {
  r.diagnostics.map(d => "\{d.code} \{d.kind}")
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
      let deep = @parser.parse_text(deep_text)
      e
      .expect((c, nesting_kinds(deep)))
      .to_equal((c, ["GL-PARSE-004 TooMuchNesting"]))
      e.expect((c, deep.module_.definitions.length())).to_equal((c, 0))
      e.expect((c, deep.cst.to_source() == deep_text)).to_equal((c, true))
    }
  })
}

///|
test "law: the deepest accepted nesting decodes, and one level more is rejected" {
  @expect.expect_all(e => {
    for c in @lawkit.Construct::all() {
      let mut depth = 1
      while depth < 400 {
        if @parser.parse_text(@lawkit.nested(c, depth)).has_errors() {
          break
        }
        depth += 1
      }
      // The limit is reached well before 400 levels for every construct.
      e.expect((c, depth < 400)).to_equal((c, true))
      let last_ok = @parser.parse_text(@lawkit.nested(c, depth - 1))
      e.expect((c, nesting_kinds(last_ok))).to_equal((c, []))
      e.expect((c, round_trips(last_ok))).to_equal((c, true))
      let d = last_ok.module_.definitions[0].definition
      e
      .expect(
        (
          c,
          @parser.definition_root_depth + @parser.json_depth(d) <=
          @ast.max_depth,
        ),
      )
      .to_equal((c, true))
      let rejected = @parser.parse_text(@lawkit.nested(c, depth))
      e
      .expect((c, nesting_kinds(rejected)))
      .to_equal((c, ["GL-PARSE-004 TooMuchNesting"]))
    }
  })
}
