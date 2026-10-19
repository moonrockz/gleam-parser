///|
fn profile_config(name : String) -> @gleam.Config raise {
  let target = @gleam.Target::extension(name)
  {
    ..@gleam.Config::default(),
    dialect: @gleam.Dialect::gleam_1_19().register_target(target),
  }
}

///|
test "invalid target names and reserved identities fail before parsing" {
  @expect.expect_all(s => {
    for
      name in [
        "", "js", "erl", "javascript", "erlang", "fn", "echo", "Orbit", "_orbit",
        "two names", "orbit-1", "orbit()", "orbit\n", "orbit//comment",
      ] {
      s
      .expect((name, @gleam.TargetName::from_string(name)))
      .to_equal((name, None))
    }
    for target in [@gleam.Target::Erlang, @gleam.Target::JavaScript] {
      let failed = try {
        let _ = @gleam.TargetRegistry::standard().register(target)
        false
      } catch {
        _ => true
      }
      s.expect(failed).to_be_true()
    }
  })
}

///|
test "malformed extension annotations report errors and preserve source during recovery" {
  let config = profile_config("orbit")
  let cases = [
    (
      "@external(orbit, \"m\", \"f\")\n@external(orbit, \"n\", \"g\")\npub fn f() -> Int\n",
      "DuplicateAttribute",
    ),
    ("@target(orbit)\n@target(erlang)\npub const x = 1\n", "DuplicateAttribute"),
    ("@target(unknown)\npub const x = 1\n", "UnknownTarget"),
    ("@external(unknown, \"m\", \"f\")\npub fn f() -> Int\n", "UnknownTarget"),
    ("@external(orbit, 1, \"f\")\npub fn f() -> Int\n", "UnexpectedToken"),
    ("@external(orbit, \"m\")\npub fn f() -> Int\n", "UnexpectedToken"),
    (
      "@external(orbit, \"m\", \"f\")\npub const x = 1\n", "ExpectedFunctionDefinition",
    ),
    (
      "@external(orbit, \"m\", \"f\")\nimport other\n", "ExpectedFunctionDefinition",
    ),
    (
      "@external(orbit, \"m\", \"f\")\npub type Id = Int\n", "ExpectedFunctionDefinition",
    ),
    (
      "pub type Id {\n@external(orbit, \"m\", \"f\")\nId\n}\n", "UnknownAttributeRecordVariant",
    ),
  ]
  @expect.expect_all(s => {
    for (broken, kind) in cases {
      let source = broken + "\npub const recovered = 42\n"
      let result = @gleam.parse_text(source, config~)
      s.expect((broken, result.has_errors())).to_equal((broken, true))
      s.expect(result.diagnostics[0].kind).to_equal(kind)
      s
      .expect(result.diagnostics[0].span.start.to_int() < broken.length())
      .to_be_true()
      s.expect(result.cst.to_source()).to_equal(source)
      s
      .expect(
        result.module_.definitions.any(d => {
          match d.definition {
            ModuleConstant(c) => c.name == "recovered"
            _ => false
          }
        }),
      )
      .to_be_true()
    }
  })
}

///|
test "both standard shorthand rules remain unchanged under an additive profile" {
  let config = profile_config("orbit")
  @expect.expect_all(s => {
    for shorthand in ["erl", "js"] {
      let source = "@target(\{shorthand}) pub const x = 1"
      let standard = @gleam.parse_text(source)
      let extended = @gleam.parse_text(source, config~)
      s.expect(extended.parsed()).to_equal(standard.parsed())
      s.expect(extended.diagnostics).to_equal(standard.diagnostics)
      s.expect(extended.warnings.length()).to_equal(1)
      let external = "@external(\{shorthand}, \"m\", \"f\") pub fn f() -> Int"
      s
      .expect(@gleam.parse_text(external, config~).diagnostics)
      .to_equal(@gleam.parse_text(external).diagnostics)
    }
  })
}

///|
test "syntax traversal exposes target restrictions and external bindings" {
  let config = profile_config("orbit")
  let source = "@target(orbit)\n@external(orbit, \"domain\", \"Id\")\npub type Id\n"
  let result = @gleam.parse_text(source, config~)
  let found : Array[String] = []
  @gleam.walk(@gleam.NodeRef::of_result(result), node => {
    if node is Definition(definition) {
      if definition.target is Some(target) {
        found.push(target.name())
      }
      for binding in definition.definition.external_bindings().all() {
        found.push(
          binding.target.name() +
          ":" +
          binding.external.module_ +
          ":" +
          binding.external.function,
        )
      }
    }
    Continue
  })
  @expect.expect(found).to_equal(["orbit", "orbit:domain:Id"])
}

///|
test "law: a freshly named target survives JSON, formatting, and lossless reconstruction" {
  // Edges: two annotations, no restriction on a bound function, opaque escaped
  // strings, Unicode, and a fresh target name for each generated integer.
  @quickcheck.check(
    (n : UInt32) => {
      try {
        let name = "orbit_" + n.to_string()
        let config = profile_config(name)
        let source = "// λ\r\n@target(\{name})\r\npub const x = 42\r\n@external(\{name}, \"space/λ\", \"say\\\"hi\")\r\npub fn call() -> Int\r\n"
        let result = @gleam.parse_text(source, config~)
        if result.has_errors() {
          return false
        }
        let document = @gleam.decode_extended(@gleam.encode_extended(result))
        let formatted = @gleam.format_parsed(result)
        let back = @gleam.parse_text(formatted, config~)
        !back.has_errors() &&
        result.cst.to_source() == source &&
        document.parsed == result.parsed() &&
        @gleam.format_parsed(back) == formatted &&
        back.module_.definitions[0].target ==
        result.module_.definitions[0].target &&
        back.module_.definitions[1].definition
        .external_bindings()
        .all()
        .map(b => (b.target, b.external.module_, b.external.function)) ==
        result.module_.definitions[1].definition
        .external_bindings()
        .all()
        .map(b => (b.target, b.external.module_, b.external.function))
      } catch {
        _ => false
      }
    },
    count=80,
    max_size=20,
    seed=2424,
  )
}

///|
test "law: additive profiles preserve standard AST JSON diagnostics and formatting" {
  let config = profile_config("orbit")
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      try {
        let text = m.text()
        let standard = @gleam.parse_text(text)
        let extended = @gleam.parse_text(text, config~)
        !standard.has_errors() &&
        !extended.has_errors() &&
        standard.parsed() == extended.parsed() &&
        standard.diagnostics == extended.diagnostics &&
        @gleam.canonical(@gleam.encode_parsed(standard.parsed())) ==
        @gleam.canonical(@gleam.encode_parsed(extended.parsed())) &&
        @gleam.format_parsed(standard) == @gleam.format_parsed(extended)
      } catch {
        _ => false
      }
    },
    count=100,
    max_size=15,
    seed=2425,
  )
}

///|
test "law: compatible profile composition commutes and duplicate registrations fail" {
  @quickcheck.check(
    (n : UInt32) => {
      try {
        let a = @gleam.Profile(
          "example/a@1",
          [@gleam.Target::extension("a_" + n.to_string())][:],
        )
        let b = @gleam.Profile(
          "example/b@1",
          [@gleam.Target::extension("b_" + n.to_string())][:],
        )
        let base = @gleam.Dialect::gleam_1_19()
        let composed = base.with_profile(a).with_profile(b)
        let duplicate = try {
          let _ = composed.with_profile(a)
          false
        } catch {
          _ => true
        }
        duplicate && composed == base.with_profile(b).with_profile(a)
      } catch {
        _ => false
      }
    },
    count=60,
    max_size=10,
    seed=2426,
  )
}

///|
fn profile_json_field(json : Json, name : String) -> Json {
  match json {
    Object(fields) => fields.get(name).unwrap()
    _ => abort("expected object")
  }
}

///|
fn profile_json_set(json : Json, name : String, value : Json) -> Json {
  match json {
    Object(fields) => {
      let copy = fields.copy()
      copy.set(name, value)
      Json::object(copy)
    }
    _ => abort("expected object")
  }
}

///|
test "extended decoding rejects malformed registries identities versions and bindings" {
  let config = profile_config("orbit")
  let result = @gleam.parse_text(
    "@external(orbit, \"m\", \"f\") pub fn f() -> Int",
    config~,
  )
  let json = @gleam.encode_extended(result)
  let names = (xs : Array[String]) => Json::array(xs.map(Json::string))
  let cases = [
    profile_json_set(json, "format", Json::string("other")),
    profile_json_set(json, "version", Json::number(2)),
    profile_json_set(json, "version", Json::number(1.5)),
    profile_json_set(json, "dialect", Json::string("")),
    profile_json_set(json, "profiles", names(["p", "p"])),
    profile_json_set(json, "profiles", names([""])),
    profile_json_set(
      json,
      "targets",
      names(["erlang", "javascript", "orbit", "orbit"]),
    ),
    profile_json_set(json, "targets", names(["erlang", "javascript", "js"])),
    profile_json_set(json, "targets", names(["erlang", "javascript", "fn"])),
    profile_json_set(json, "targets", names(["erlang", "orbit"])),
    profile_json_set(json, "targets", names(["erlang", "javascript"])),
  ]
  let parsed = profile_json_field(json, "parsed")
  let module_ = profile_json_field(parsed, "module")
  guard profile_json_field(module_, "definitions") is Array(definitions) else {
    fail("definitions")
  }
  let wrapper = definitions[0]
  let definition = profile_json_field(wrapper, "definition")
  guard profile_json_field(definition, "externals") is Array(bindings) else {
    fail("bindings")
  }
  for
    changed in [
      profile_json_set(
        definition,
        "externals",
        Json::array([bindings[0], bindings[0]]),
      ),
      profile_json_set(definition, "external_erlang", Json::null()),
      profile_json_set(
        definition,
        "externals",
        Json::array([
          profile_json_set(bindings[0], "target", Json::string("unknown")),
        ]),
      ),
    ] {
    cases.push(
      profile_json_set(
        json,
        "parsed",
        profile_json_set(
          parsed,
          "module",
          profile_json_set(
            module_,
            "definitions",
            Json::array([profile_json_set(wrapper, "definition", changed)]),
          ),
        ),
      ),
    )
  }
  @expect.expect_all(s => {
    for i, invalid in cases {
      let rejected = try {
        let _ = @gleam.decode_extended(invalid)
        false
      } catch {
        @ast.DecodeError(path~, ..) => path.has_prefix("$")
      }
      s.expect((i, rejected)).to_equal((i, true))
    }
  })
}

///|
test "every compiler-compatible target-bearing export is checked" {
  let config = profile_config("orbit")
  let orbit = config.dialect.targets.resolve("orbit").unwrap()
  let parsed = @gleam.parse_text(
    "@target(orbit)\n@external(orbit, \"m\", \"f\") pub fn f() -> Int",
    config~,
  ).parsed()
  let definition = parsed.module_.definitions[0]
  let warning : @ast.Warning = DeprecatedTargetShorthand(
    target=orbit,
    location=definition.definition.location(),
  )
  let encoders : Array[() -> Json raise @ast.ExportError] = [
    () => @ast.encode_parsed(parsed),
    () => @ast.encode_module(parsed.module_),
    () => @ast.encode_targeted_definition(definition),
    () => @ast.encode_definition(definition.definition),
    () => @ast.encode_warning(warning),
    () => @ast.encode_oracle_output(Parsed(parsed)),
  ]
  @expect.expect_all(s => {
    for encode in encoders {
      let rejected = try {
        let _ = encode()
        false
      } catch {
        NonStandardTarget(target~, ..) => target == orbit
      }
      s.expect(rejected).to_be_true()
    }
  })
}
