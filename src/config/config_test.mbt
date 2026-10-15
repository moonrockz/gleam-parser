///|
fn budget(n : Int32) -> @fuel.Budget {
  @fuel.Budget::new(n).unwrap()
}

///|
fn quiet() -> @dialect.Dialect {
  { ..@dialect.Dialect::gleam_1_19(), deprecations: [][:], }
}

///|
fn error_of(
  f : () -> Unit raise @config.ConfigError,
) -> (@config.Source, String)? {
  try {
    f()
    None
  } catch {
    @config.ConfigError(source~, message~) => Some((source, message))
  }
}

///|
test "the default config is gleam 1.19 with the default budget" {
  let c = @config.Config::default()
  @expect.expect_all(e => {
    e.expect(c.dialect).to_equal(@dialect.Dialect::gleam_1_19())
    e.expect(c.fuel).to_equal(@fuel.default_budget)
  })
}

///|
test "with_fallback: set fields win, unset fields come from the fallback" {
  let a : @config.Partial = { dialect: None, fuel: Some(budget(7)), }
  let b : @config.Partial = { dialect: Some(quiet()), fuel: Some(budget(9)), }
  @expect.expect_all(e => {
    e
    .expect(a.with_fallback(b))
    .to_equal({ dialect: Some(quiet()), fuel: Some(budget(7)), })
    e
    .expect(b.with_fallback(a))
    .to_equal({ dialect: Some(quiet()), fuel: Some(budget(9)), })
    e
    .expect(a.to_config(@config.Config::default()))
    .to_equal({ dialect: @dialect.Dialect::gleam_1_19(), fuel: budget(7), })
    e
    .expect(@config.Config::default().with_fallback(b))
    .to_equal({ dialect: quiet(), fuel: budget(9), })
    e
    .expect(@config.Config::default().to_partial())
    .to_equal({
      dialect: Some(@dialect.Dialect::gleam_1_19()),
      fuel: Some(@fuel.default_budget),
    })
    e.expect(@config.Partial::empty()).to_equal({ dialect: None, fuel: None, })
  })
}

///|
test "from_toml reads the [parser] table and leaves missing keys unset" {
  @expect.expect_all(e => {
    e
    .expect(
      @config.Config::from_toml("[parser]\ngleam = \"1.19\"\nfuel = 550\n"),
    )
    .to_equal({
      dialect: Some(@dialect.Dialect::gleam_1_19()),
      fuel: Some(budget(550)),
    })
    e
    .expect(@config.Config::from_toml("[parser]\nfuel = 1\n"))
    .to_equal({ dialect: None, fuel: Some(budget(1)), })
    e.expect(@config.Config::from_toml("")).to_equal(@config.Partial::empty())
    e
    .expect(@config.Config::from_toml("# only a comment\n"))
    .to_equal(@config.Partial::empty())
  })
}

///|
test "from_toml names the key of every bad value" {
  let bad = (text : String) => {
    error_of(() => @config.Config::from_toml(text) |> ignore)
  }
  @expect.expect_all(e => {
    e
    .expect(bad("[parser]\nfuel = 0\n"))
    .to_equal(
      Some((@config.Source::TomlKey("parser.fuel"), "must be at least 1")),
    )
    e
    .expect(bad("[parser]\nfuel = -4294967196\n"))
    .to_equal(
      Some((@config.Source::TomlKey("parser.fuel"), "must be at least 1")),
    )
    e
    .expect(bad("[parser]\nfuel = 4294967396\n"))
    .to_equal(
      Some(
        (@config.Source::TomlKey("parser.fuel"), "must be at most 2147483647"),
      ),
    )
    e
    .expect(bad("[parser\nfuel = 1\nfuel = 2\n"))
    .to_equal(Some((@config.Source::TomlSyntax, "Expected ']'")))
    e
    .expect(bad("[parser]\nfuel = \"100\"\n"))
    .to_equal(
      Some(
        (
          @config.Source::TomlKey("parser.fuel"),
          "expected an integer, found a string",
        ),
      ),
    )
    e
    .expect(bad("[parser]\ngleam = \"1.18\"\n"))
    .to_equal(
      Some(
        (
          @config.Source::TomlKey("parser.gleam"),
          "unknown Gleam version \"1.18\"; known: 1.19",
        ),
      ),
    )
    e
    .expect(bad("[parser]\ngleam = 119\n"))
    .to_equal(
      Some(
        (
          @config.Source::TomlKey("parser.gleam"),
          "expected a string, found an integer",
        ),
      ),
    )
    e
    .expect(bad("[parser]\nwidth = 80\n"))
    .to_equal(Some((@config.Source::TomlKey("parser.width"), "unknown key")))
    e
    .expect(bad("[format]\nwidth = 80\n"))
    .to_equal(Some((@config.Source::TomlKey("format"), "unknown table")))
    e
    .expect(bad("parser = 1\n"))
    .to_equal(
      Some(
        (
          @config.Source::TomlKey("parser"),
          "expected a table, found an integer",
        ),
      ),
    )
    e
    .expect(bad("[parser\nfuel = \n").map(p => p.0))
    .to_equal(Some(@config.Source::TomlSyntax))
  })
}

///|
test "from_env reads GLEAM_PARSER_GLEAM and GLEAM_PARSER_FUEL" {
  let env = @config.Environment::of({
    "GLEAM_PARSER_FUEL": "2000",
    "OTHER": "x",
  })
  let both = @config.Environment::of({
    "GLEAM_PARSER_FUEL": "5",
    "GLEAM_PARSER_GLEAM": "1.19",
  })
  @expect.expect_all(e => {
    e
    .expect(@config.Config::from_env(env))
    .to_equal({ dialect: None, fuel: Some(budget(2000)), })
    e
    .expect(@config.Config::from_env(both))
    .to_equal({
      dialect: Some(@dialect.Dialect::gleam_1_19()),
      fuel: Some(budget(5)),
    })
    e
    .expect(@config.Config::from_env(@config.Environment::of(Map([]))))
    .to_equal(@config.Partial::empty())
    e.expect(env.get("OTHER")).to_equal(Some("x"))
    e.expect(env.get("NOPE")).to_equal(None)
  })
}

///|
test "from_env names the variable of every bad value; an empty value is an error" {
  let bad = (vars : Map[String, String]) => {
    error_of(() => {
      @config.Config::from_env(@config.Environment::of(vars)) |> ignore
    })
  }
  @expect.expect_all(e => {
    e
    .expect(bad({ "GLEAM_PARSER_FUEL": "abc" }))
    .to_equal(
      Some(
        (
          @config.Source::EnvVar("GLEAM_PARSER_FUEL"),
          "expected an integer, found \"abc\"",
        ),
      ),
    )
    e
    .expect(bad({ "GLEAM_PARSER_FUEL": "-4294967196" }))
    .to_equal(
      Some((@config.Source::EnvVar("GLEAM_PARSER_FUEL"), "must be at least 1")),
    )
    e
    .expect(bad({ "GLEAM_PARSER_FUEL": "0" }))
    .to_equal(
      Some((@config.Source::EnvVar("GLEAM_PARSER_FUEL"), "must be at least 1")),
    )
    e
    .expect(bad({ "GLEAM_PARSER_FUEL": "" }))
    .to_equal(
      Some((@config.Source::EnvVar("GLEAM_PARSER_FUEL"), "empty value")),
    )
    e
    .expect(bad({ "GLEAM_PARSER_GLEAM": "2.0" }))
    .to_equal(
      Some(
        (
          @config.Source::EnvVar("GLEAM_PARSER_GLEAM"),
          "unknown Gleam version \"2.0\"; known: 1.19",
        ),
      ),
    )
  })
}

///|
test "load: environment over file over defaults; a missing file is no layer" {
  let dir = "_build"
  let path = "\{dir}/gleam-parser-config-test.toml"
  @fs.write_string_to_file(path, "[parser]\nfuel = 300\n")
  let none = @config.Environment::of(Map([]))
  let env = @config.Environment::of({ "GLEAM_PARSER_FUEL": "400" })
  @expect.expect_all(e => {
    e.expect(@config.Config::load(path~, env=none).fuel).to_equal(budget(300))
    e.expect(@config.Config::load(path~, env~).fuel).to_equal(budget(400))
    e
    .expect(
      @config.Config::load(path="\{dir}/no-such-gleam-parser.toml", env=none),
    )
    .to_equal(@config.Config::default())
    e
    .expect(
      @config.Config::load(path="\{dir}/no-such-gleam-parser.toml", env~).fuel,
    )
    .to_equal(budget(400))
  })
  @fs.write_string_to_file(path, "[parser]\nfuel = ")
  @expect.expect(
    error_of(() => @config.Config::load(path~, env=none) |> ignore).map(p => p.0),
  ).to_equal(Some(@config.Source::TomlSyntax))
  @fs.remove_file(path)
}

///|
test "load names the file in a TOML error and keeps the read error's text" {
  let path = "_build/gleam-parser-config-error-test.toml"
  @fs.write_string_to_file(path, "[parser]\nwidth = 80\n")
  let none = @config.Environment::of(Map([]))
  let key_error = error_of(() => @config.Config::load(path~, env=none) |> ignore)
  @fs.remove_file(path)
  // A directory exists but cannot be read as a file.
  let read_error = error_of(() => {
    @config.Config::load(path="_build", env=none) |> ignore
  })
  @expect.expect_all(e => {
    e
    .expect(key_error)
    .to_equal(
      Some((@config.Source::TomlKey("parser.width"), "\{path}: unknown key")),
    )
    e
    .expect(read_error.map(p => p.0))
    .to_equal(Some(@config.Source::File("_build")))
    e
    .expect(
      read_error.map(p => {
        p.1.has_prefix("cannot read the file: ") && p.1.length() > 22
      }),
    )
    .to_equal(Some(true))
  })
}
