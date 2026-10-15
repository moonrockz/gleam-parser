///|
fn event_label(e : @syntax.Event) -> String {
  match e {
    Enter(e) => {
      let f = match e.field {
        Some(f) => " " + f
        None => ""
      }
      "+\{e.category}/\{e.kind}\{f} \{e.start}"
    }
    Leave(e) => "-\{e.node.category()}/\{e.node.kind()}"
  }
}

///|
fn read_all(r : @syntax.EventReader) -> Array[String] {
  let out = []
  while r.next() is Some(e) {
    out.push(event_label(e))
  }
  out
}

///|
let small : String = "pub fn f(x) {\n  x\n}\n"

///|
test "an event reader gives walk's events with fields and starts" {
  @expect.expect(read_all(@syntax.EventReader::new(root_of(small)))).to_equal([
    "+module/module 0", "+definition/function definitions 0", "+arg/arg arguments 9",
    "-arg/arg", "+statement/expression body 16", "+expression/var expression 16",
    "-expression/var", "-statement/expression", "-definition/function", "-module/module",
  ])
}

///|
test "skip_children right after an Enter makes the next event its Leave" {
  @expect.expect_all(s => {
    let r = @syntax.EventReader::new(root_of(small))
    let out = []
    while r.next() is Some(e) {
      out.push(event_label(e))
      if e is Enter({ category: "definition", .. }) {
        r.skip_children()
      }
    }
    let i = out.search("+definition/function definitions 0").unwrap()
    s.expect(out[i + 1]).to_equal("-definition/function")
    s.expect(out.length()).to_equal(4)
  })
}

///|
test "skip_children elsewhere does nothing" {
  @expect.expect_all(s => {
    let root = root_of(small)
    let r = @syntax.EventReader::new(root)
    // Before the first event, after a Leave, and after the end.
    r.skip_children()
    let out = []
    while r.next() is Some(e) {
      out.push(event_label(e))
      if e is Leave(_) {
        r.skip_children()
      }
    }
    r.skip_children()
    s.expect(out).to_equal(read_all(@syntax.EventReader::new(root)))
    s.expect(r.next()).to_equal(None)
  })
}

///|
test "a finished reader returns None every time" {
  @expect.expect_all(s => {
    let r = @syntax.EventReader::new(root_of(small))
    ignore(read_all(r))
    s.expect(r.next()).to_equal(None)
    s.expect(r.next()).to_equal(None)
  })
}

///|
test "two readers over one tree do not affect each other" {
  @expect.expect_all(s => {
    let root = root_of(
      "pub fn f(x) {\n  case x {\n    1 -> [x]\n    _ -> x\n  }\n}\n",
    )
    let a = @syntax.EventReader::new(root)
    let b = @syntax.EventReader::new(root)
    let from_a = []
    let from_b = []
    // b reads two events for each one a reads.
    let mut more = true
    while more {
      more = false
      if a.next() is Some(e) {
        from_a.push(event_label(e))
        more = true
      }
      for _ in 0..<2 {
        if b.next() is Some(e) {
          from_b.push(event_label(e))
          more = true
        }
      }
    }
    let alone = read_all(@syntax.EventReader::new(root))
    s.expect(from_a).to_equal(alone)
    s.expect(from_b).to_equal(alone)
  })
}

///|
test "an event reader handles 3000 nested lists" {
  let out = read_all(@syntax.EventReader::new(deep_list(3000)))
  @expect.expect(out.length()).to_equal(2 * 3001)
}

///|
test "events carry the depth and path of their node" {
  let r = @syntax.EventReader::new(root_of(small))
  let seen = []
  while r.next() is Some(e) {
    match e {
      Enter(e) if e.kind == "var" || e.kind == "module" =>
        seen.push("+\{e.kind} \{e.depth} \{e.path}")
      Leave(e) if e.node.kind() == "var" =>
        seen.push("-var \{e.depth} \{e.path}")
      _ => ()
    }
  }
  @expect.expect(seen).to_equal([
    "+module 0 ", "+var 3 definitions[0].body[0].expression[0]", "-var 3 definitions[0].body[0].expression[0]",
  ])
}

///|
test "iter continues where next stopped, and ends after the root's Leave" {
  let root = root_of(small)
  let all = read_all(@syntax.EventReader::new(root))
  let reader = @syntax.EventReader::new(root)
  let first = reader.next().map(event_label)
  let rest = reader.iter().map(event_label).to_array()
  @expect.expect_all(s => {
    s.expect(first).to_equal(Some(all[0]))
    s.expect(rest).to_equal(all[1:].to_owned())
    s.expect(reader.iter().to_array()).to_equal([])
  })
}
