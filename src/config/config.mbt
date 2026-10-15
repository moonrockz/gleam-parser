// The parser's configuration: the dialect and the fuel budget, later the
// formatter and traversal settings. Values are immutable; a `Partial` is a
// layer with set and unset fields, merged HOCON style with
// `with_fallback`. `Config::load` is the only function here that touches
// the file system or the environment.

///|
/// The parser's configuration.
///
/// ```mbt check
/// test {
///   let c = @config.Config::default()
///   inspect(c.fuel.units(), content="100")
///   inspect(c.dialect.name, content="gleam-1.19")
/// }
/// ```
pub(all) struct Config {
  dialect : @dialect.Dialect
  fuel : @fuel.Budget
} derive(Eq, Debug)

///|
/// A layer of configuration: each field set or unset.
pub(all) struct Partial {
  dialect : @dialect.Dialect?
  fuel : @fuel.Budget?
} derive(Eq, Debug)

///|
/// Where a configuration value came from; an error names it.
pub(all) enum Source {
  Default
  /// A key path in the TOML file (`parser.fuel`).
  TomlKey(String)
  /// The TOML text as a whole (a syntax error).
  TomlSyntax
  /// An environment variable (`GLEAM_PARSER_FUEL`).
  EnvVar(String)
  /// A file path that could not be read.
  File(String)
  Caller
} derive(Eq, Debug)

///|
/// A configuration value that cannot be used. Nothing falls back silently.
pub(all) suberror ConfigError {
  ConfigError(source~ : Source, message~ : String)
} derive(Eq, Debug)

///|
/// `Dialect::gleam_1_19()` and `@fuel.default_budget`.
pub fn Config::default() -> Config {
  { dialect: @dialect.Dialect::gleam_1_19(), fuel: @fuel.default_budget, }
}

///|
/// Every field set.
pub fn Config::to_partial(self : Config) -> Partial {
  { dialect: Some(self.dialect), fuel: Some(self.fuel), }
}

///|
/// `over`'s set fields replace this config's fields.
pub fn Config::with_fallback(self : Config, over : Partial) -> Config {
  over.to_config(self)
}

///|
pub fn Partial::empty() -> Partial {
  { dialect: None, fuel: None, }
}

///|
/// This layer's set fields win; unset fields come from `fallback`.
///
/// ```mbt check
/// test {
///   let file : @config.Partial = { dialect: None, fuel: @fuel.Budget::new(500), }
///   let env : @config.Partial = { dialect: None, fuel: @fuel.Budget::new(2000), }
///   let c = env.with_fallback(file).to_config(@config.Config::default())
///   inspect(c.fuel.units(), content="2000")
/// }
/// ```
pub fn Partial::with_fallback(self : Partial, fallback : Partial) -> Partial {
  {
    dialect: match self.dialect {
      Some(d) => Some(d)
      None => fallback.dialect
    },
    fuel: match self.fuel {
      Some(b) => Some(b)
      None => fallback.fuel
    },
  }
}

///|
/// A full config: unset fields come from `fallback`.
pub fn Partial::to_config(self : Partial, fallback : Config) -> Config {
  {
    dialect: self.dialect.unwrap_or(fallback.dialect),
    fuel: self.fuel.unwrap_or(fallback.fuel),
  }
}
