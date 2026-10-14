///|
/// A law over generated modules fails on any diagnostic: a module the
/// generator thinks valid must parse clean, or the generator is wrong.
fn clean(text : String) -> @parser.ParseResult? {
  let r = @parser.parse_text(text)
  if r.diagnostics.length() == 0 {
    Some(r)
  } else {
    None
  }
}

///|
test "law: a generated module parses with no diagnostic" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => clean(m.text()) is Some(_),
    count=200,
    max_size=12,
    seed=2060,
  )
}

///|
test "law: the CST rebuilds any text, and its definitions tile the tokens" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      let r = @parser.parse_text(text)
      let tiled = StringBuilder()
      for tr in r.cst.trivia {
        tiled.write_string(tr.text())
      }
      let mut count = 0
      for d in r.cst.definitions {
        tiled.write_string(d.to_source())
        count += d.tokens.length()
      }
      r.cst.to_source() == text &&
      tiled.to_string() == text &&
      count == r.cst.tokens.length()
    },
    count=300,
    max_size=30,
    seed=2061,
  )
}

///|
test "law: parsed CST definitions match the module's definitions one for one" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let r = @parser.parse_text(t.text())
      let parsed = r.cst.definitions.filter(d => d.kind != Skipped)
      guard parsed.length() == r.module_.definitions.length() else {
        return false
      }
      let mut ok = true
      for i, d in parsed {
        let name = match r.module_.definitions[i].definition {
          Function(f) => f.name.map(n => n.name)
          TypeAlias(a) => Some(a.alias_)
          CustomType(c) => Some(c.name)
          Import(i) => Some(i.module_)
          ModuleConstant(c) => Some(c.name)
        }
        if name != d.name {
          ok = false
        }
      }
      ok
    },
    count=300,
    max_size=30,
    seed=2062,
  )
}

///|
test "law: parsing never crashes on any text, and warnings agree with their diagnostics" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let r = @parser.parse_text(t.text())
      let warning_diagnostics = r.diagnostics.filter(d => !d.is_error())
      warning_diagnostics.length() == r.warnings.length() &&
      r.diagnostics.all(d => d.span.start <= d.span.end)
    },
    count=300,
    max_size=30,
    seed=2063,
  )
}

///|
test "law: a parsed module's JSON round-trips through the decoder" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      guard clean(m.text()) is Some(r) else { return false }
      let parsed = r.parsed()
      let text = @ast.canonical(@ast.encode_parsed(parsed))
      try @ast.decode_parsed(@json.parse(text)) catch {
        _ => false
      } noraise {
        back =>
          back == parsed && @ast.canonical(@ast.encode_parsed(back)) == text
      }
    },
    count=150,
    max_size=12,
    seed=2064,
  )
}

///|
test "law: a module parses the same from its CST text" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      guard clean(m.text()) is Some(r) else { return false }
      let again = @parser.parse_text(r.cst.to_source())
      again.parsed() == r.parsed()
    },
    count=100,
    max_size=12,
    seed=2065,
  )
}
