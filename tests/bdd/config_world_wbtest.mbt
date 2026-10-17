///|
/// Scenario state for `tests/features/config.feature`.
struct ConfigWorld {
  mut toml : String?
  vars : Map[String, String]
  mut caller : @gleam.Partial
  mut result : Result[@gleam.Config, @gleam.ConfigError]?
}

///|
fn ConfigWorld::new() -> ConfigWorld {
  { toml: None, vars: Map([]), caller: @gleam.Partial::empty(), result: None, }
}

///|
impl @moonspec.World for ConfigWorld with fn configure(self, setup) {
  setup.given1("the TOML text {string}", fn(text : String) {
    if text != "" {
      self.toml = Some(unescape(text))
    }
  })
  setup.given2("the environment variable {string} is {string}", fn(
    name : String,
    value : String,
  ) {
    if name != "" {
      self.vars[name] = value
    }
  })
  setup.given1("the caller sets the fuel to {int}", fn(n : Int32) {
    self.caller = {
      ..self.caller,
      fuel: @gleam.Budget::from_int(n).map(b => Limited(b)),
    }
  })
  setup.when("I resolve the configuration", fn(_ctx) {
    self.result = Some(
      try {
        let file = match self.toml {
          Some(t) => @gleam.Config::from_toml(t)
          None => @gleam.Partial::empty()
        }
        let env = @gleam.Config::from_env(@gleam.Environment::of(self.vars))
        Ok(
          self.caller
          .with_fallback(env)
          .with_fallback(file)
          .to_config(@gleam.Config::default()),
        )
      } catch {
        e => Err(e)
      },
    )
  })
  setup.then1("the fuel budget is {int}", fn(n : Int32) raise {
    guard self.result is Some(Ok(c)) else {
      match self.result {
        Some(Err(ConfigError(message~, ..))) =>
          fail("no configuration: \{message}")
        _ => fail("no configuration")
      }
    }
    @expect.expect(c.fuel.budget().map(b => b.units())).to_equal(Some(n))
  })
  setup.then0("nesting is unlimited", fn() raise {
    guard self.result is Some(Ok(c)) else { fail("no configuration") }
    @expect.expect(c.fuel).to_equal(Unlimited)
  })
  setup.then1("the dialect is {string}", fn(name : String) raise {
    guard self.result is Some(Ok(c)) else { fail("no configuration") }
    @expect.expect(c.dialect.name).to_equal(name)
  })
  setup.then2("the configuration error names {string} with {}", fn(
    source : String,
    message : String,
  ) raise {
    guard self.result is Some(Err(ConfigError(source=s, message=m))) else {
      fail("expected a configuration error")
    }
    let name = match s {
      TomlKey(k) => k
      EnvVar(v) => v
      TomlSyntax => "toml"
      File(p) => p
      Default => "default"
      Caller => "caller"
    }
    // `{}` keeps the quotes the feature writes around the message.
    let expected = if message.has_prefix("\"") && message.has_suffix("\"") {
      message[1:message.length() - 1].to_owned()
    } else {
      message
    }
    @expect.expect_all(e => {
      e.expect(name).to_equal(source)
      e.expect(m).to_equal(expected)
    })
  })
}

///|
async test "config feature" {
  @moonspec.run_or_fail(
    ConfigWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/config.feature"),
    ]),
  )
  |> ignore
}
