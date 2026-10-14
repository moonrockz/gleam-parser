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

///|
/// Per-family laws: a whole module halves `size` at every level, so the
/// laws above rarely reach deep kinds (guards, bit array options); these
/// start at each family with the full size.
test "law: expressions round-trip through JSON" {
  @quickcheck.check(
    (seed : Int32) => {
      let rs = @splitmix.RandomState(seed=seed.to_uint64())
      let e = @lawkit.gen_expr(8, rs)
      try
        @ast.decode_expr(@json.parse(@ast.canonical(@ast.encode_expr(e))))
      catch {
        _ => false
      } noraise {
        back => back == e
      }
    },
    count=300,
    seed=2043,
  )
}

///|
test "law: patterns round-trip through JSON" {
  @quickcheck.check(
    (seed : Int32) => {
      let rs = @splitmix.RandomState(seed=seed.to_uint64())
      let p = @lawkit.gen_pattern(8, rs)
      try
        @ast.decode_pattern(@json.parse(@ast.canonical(@ast.encode_pattern(p))))
      catch {
        _ => false
      } noraise {
        back => back == p
      }
    },
    count=300,
    seed=2044,
  )
}

///|
test "law: constants round-trip through JSON" {
  @quickcheck.check(
    (seed : Int32) => {
      let rs = @splitmix.RandomState(seed=seed.to_uint64())
      let c = @lawkit.gen_constant(8, rs)
      try
        @ast.decode_constant(
          @json.parse(@ast.canonical(@ast.encode_constant(c))),
        )
      catch {
        _ => false
      } noraise {
        back => back == c
      }
    },
    count=300,
    seed=2045,
  )
}

///|
test "law: clause guards round-trip through JSON" {
  @quickcheck.check(
    (seed : Int32) => {
      let rs = @splitmix.RandomState(seed=seed.to_uint64())
      let g = @lawkit.gen_clause_guard(8, rs)
      try
        @ast.decode_clause_guard(
          @json.parse(@ast.canonical(@ast.encode_clause_guard(g))),
        )
      catch {
        _ => false
      } noraise {
        back => back == g
      }
    },
    count=300,
    seed=2046,
  )
}

///|
test "law: type annotations round-trip through JSON" {
  @quickcheck.check(
    (seed : Int32) => {
      let rs = @splitmix.RandomState(seed=seed.to_uint64())
      let t = @lawkit.gen_type_ast(8, rs)
      try
        @ast.decode_type_ast(
          @json.parse(@ast.canonical(@ast.encode_type_ast(t))),
        )
      catch {
        _ => false
      } noraise {
        back => back == t
      }
    },
    count=300,
    seed=2047,
  )
}
