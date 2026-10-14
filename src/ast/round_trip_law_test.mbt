///|
fn round_trip(p : @ast.Parsed) -> @ast.Parsed raise {
  @ast.decode_parsed(@json.parse(@ast.canonical(@ast.encode_parsed(p))))
}

///|
/// Edges: see `@lawkit.GleamAst` (every node kind, empty lists, `None` in
/// every option, big ints, every float lexeme form, strings with quotes,
/// backslashes, controls and non-ASCII).
test "law: decoding an encoded AST gives it back" {
  @quickcheck.check(
    (a : @lawkit.GleamAst) => {
      let p = a.parsed()
      try round_trip(p) catch {
        _ => false
      } noraise {
        back => back == p
      }
    },
    count=150,
    max_size=10,
    seed=2040,
  )
}

///|
test "law: the canonical text is a fixpoint through decode" {
  @quickcheck.check(
    (a : @lawkit.GleamAst) => {
      let text = @ast.canonical(@ast.encode_parsed(a.parsed()))
      try round_trip(a.parsed()) catch {
        _ => false
      } noraise {
        back => @ast.canonical(@ast.encode_parsed(back)) == text
      }
    },
    count=150,
    max_size=10,
    seed=2041,
  )
}

///|

///|
/// Code-unit order, as serde_json's BTreeMap sorts bytes (ASCII keys).
fn byte_less(a : String, b : String) -> Bool {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i = 0; i < n; i = i + 1 {
    let d = a.code_unit_at(i).to_int() - b.code_unit_at(i).to_int()
    if d != 0 {
      return d < 0
    }
  }
  a.length() < b.length()
}

///|
test "law: canonical text parses as JSON with sorted keys at every level" {
  fn sorted(j : Json) -> Bool {
    match j {
      Object(m) => {
        let keys = m.keys().collect()
        let mut ok = true
        for i = 1; i < keys.length(); i = i + 1 {
          ok = ok && byte_less(keys[i - 1], keys[i])
        }
        ok && m.values().all(sorted)
      }
      Array(xs) => xs.iter().all(sorted)
      _ => true
    }
  }
  @quickcheck.check(
    (a : @lawkit.GleamAst) => {
      try @json.parse(@ast.canonical(@ast.encode_parsed(a.parsed()))) catch {
        _ => false
      } noraise {
        j => sorted(j)
      }
    },
    count=100,
    max_size=8,
    seed=2042,
  )
}
