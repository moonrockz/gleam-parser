///|
struct TargetsWorld {
  mut config : @gleam.Config
  mut source : String
  mut result : @gleam.ParseResult?
}

///|
fn TargetsWorld::new() -> TargetsWorld {
  { config: @gleam.Config::default(), source: "", result: None, }
}

///|
impl @moonspec.World for TargetsWorld with fn configure(self, setup) {
  setup.given1("the registered target {string}", fn(name : String) raise {
    self.config = {
      ..self.config,
      dialect: self.config.dialect.register_target(
        @gleam.Target::extension(name),
      ),
    }
  })
  setup.when1("I parse target-profile source:", fn(doc : @moonspec.DocString) {
    self.source = doc.content
    self.result = Some(@gleam.parse_text(doc.content, config=self.config))
  })
  setup.then0("the target-profile source parses", fn() raise {
    @expect.expect(self.result.unwrap().has_errors()).to_be_false()
  })
  setup.then1("the target-profile error is {string}", fn(kind : String) raise {
    let result = self.result.unwrap()
    @expect.expect(result.has_errors()).to_be_true()
    @expect.expect(result.diagnostics[0].kind).to_equal(kind)
  })
  setup.then0("the target-profile source is lossless", fn() raise {
    @expect.expect(self.result.unwrap().cst.to_source()).to_equal(self.source)
  })
  setup.then2("definition {int} has target {string}", fn(
    index : Int32,
    name : String,
  ) raise {
    @expect.expect(
      self.result.unwrap().module_.definitions[index].target
      .map(t => t.name())
      .unwrap_or(""),
    ).to_equal(name)
  })
  setup.then2("definition {int} has {int} external bindings", fn(
    index : Int32,
    count : Int32,
  ) raise {
    @expect.expect(
      self.result.unwrap().module_.definitions[index].definition
      .external_bindings()
      .all()
      .length(),
    ).to_equal(count)
  })
  setup.then0("compiler-compatible export rejects the extension", fn() raise {
    let rejected = try {
      let _ = @gleam.encode_parsed(self.result.unwrap().parsed())
      false
    } catch {
      _ => true
    }
    @expect.expect(rejected).to_be_true()
  })
  setup.then0("target-profile JSON and formatting preserve the metadata", fn() raise {
    let result = self.result.unwrap()
    let document = @gleam.decode_extended(@gleam.encode_extended(result))
    let formatted = @gleam.format_parsed(result)
    let back = @gleam.parse_text(formatted, config=self.config)
    @expect.expect_all(s => {
      s.expect(document.parsed).to_equal(result.parsed())
      s.expect(back.has_errors()).to_be_false()
      s.expect(@gleam.format_parsed(back)).to_equal(formatted)
      s
      .expect(back.module_.definitions.map(d => d.target))
      .to_equal(result.module_.definitions.map(d => d.target))
      s
      .expect(
        back.module_.definitions.map(d => {
          d.definition
          .external_bindings()
          .all()
          .map(b => (b.target, b.external.module_, b.external.function))
        }),
      )
      .to_equal(
        result.module_.definitions.map(d => {
          d.definition
          .external_bindings()
          .all()
          .map(b => (b.target, b.external.module_, b.external.function))
        }),
      )
    })
  })
}

///|
async test "target profiles feature" {
  @moonspec.run_or_fail(
    TargetsWorld::new,
    @moonspec.RunOptions::new([
      @moonspec.FeatureSource::File("features/targets.feature"),
    ]),
  )
  |> ignore
}
