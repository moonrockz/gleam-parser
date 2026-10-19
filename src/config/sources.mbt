///|
/// The variables a configuration reads: the process environment, or a
/// map (for tests and for callers that bring their own).
pub struct Environment((String) -> String?)

///|
/// The process environment (`@env.get_env_var`), on every target.
pub fn Environment::system() -> Environment {
  Environment(name => @env.get_env_var(name))
}

///|
/// A fixed set of variables.
pub fn Environment::of(vars : Map[String, String]) -> Environment {
  Environment(name => vars.get(name))
}

///|
/// The value of the variable `name`, or `None` when it is not set.
pub fn Environment::get(self : Environment, name : String) -> String? {
  (self.0)(name)
}

///|
/// The keys a configuration knows: the single source of their TOML and
/// environment names and of their value parsers, so a value means the
/// same thing from both sources.
priv enum Key {
  Gleam
  Fuel
}

///|
fn Key::all() -> Array[Key] {
  [Gleam, Fuel]
}

///|
fn Key::env_name(self : Key) -> String {
  match self {
    Gleam => "GLEAM_PARSER_GLEAM"
    Fuel => "GLEAM_PARSER_FUEL"
  }
}

///|
fn Key::of_toml(name : String) -> Key? {
  match name {
    "gleam" => Some(Gleam)
    "fuel" => Some(Fuel)
    _ => None
  }
}

///|
fn[T] bad(source : Source, message : String) -> T raise ConfigError {
  raise ConfigError(source~, message~)
}

///|
fn parse_gleam(
  text : String,
  source : Source,
) -> @dialect.Dialect raise ConfigError {
  match @dialect.Dialect::from_version(text) {
    Some(d) => d
    None =>
      bad(
        source,
        "unknown Gleam version \"\{text}\"; known: \{@dialect.Dialect::known_versions().join(", ")}",
      )
  }
}

///|
fn parse_fuel(units : Int64, source : Source) -> @fuel.Budget raise ConfigError {
  // Both bounds before `to_int`: a value outside the Int range would wrap.
  if units < 1L {
    bad(source, "must be at least 1")
  }
  if units > 2147483647L {
    bad(source, "must be at most 2147483647")
  }
  match @fuel.Budget::from_int(units.to_int()) {
    Some(b) => b
    None => bad(source, "must be at least 1")
  }
}

///|
/// The TOML parser's message without its internal location: the text
/// after `FAILED: ` and before ` at {`.
fn toml_message(raw : String) -> String {
  let text = match raw.find("FAILED: ") {
    Some(i) => raw[i + 8:].to_owned()
    None => raw
  }
  match text.find(" at {") {
    Some(i) => text[:i].to_owned()
    None => text
  }
}

///|
/// "an integer", "a string": the TOML type name with its article.
fn article(type_name : String) -> String {
  match type_name {
    "integer" | "array" => "an \{type_name}"
    _ => "a \{type_name}"
  }
}

///|
/// The `[parser]` table of a `gleam-parser.toml` text: `gleam = "1.19"`,
/// `fuel = 100` or `fuel = "unlimited"`, and `profiles = ["provider/name@1"]`.
/// Every key is optional. Resolve profile identities only through the supplied
/// `profiles` registry; its default is empty. Missing profiles and composition
/// conflicts raise `ConfigError` at `parser.profiles`. No modules are loaded.
/// An omitted fuel key inherits the fallback. The default is unlimited.
/// A syntax error, an unknown table
/// or key, a value of the wrong type, a `fuel` below 1 or an unknown Gleam
/// version is a `ConfigError` that names its source.
///
/// ```mbt check
/// test {
///   let p = @config.Config::from_toml("[parser]\nfuel = 550\n")
///   debug_inspect(
///     p.fuel.bind(limit => limit.budget()).map(b => b.units()),
///     content="Some(550)",
///   )
///   inspect(p.dialect is None, content="true")
/// }
/// ```
pub fn Config::from_toml(
  text : String,
  profiles~ : @dialect.Profiles = @dialect.Profiles::empty(),
) -> Partial raise ConfigError {
  let root = @toml.parse(text) catch {
    e => bad(TomlSyntax, toml_message("\{e}"))
  }
  let tables = match root {
    TomlTable(m) => m
    other =>
      bad(TomlSyntax, "expected a table, found \{article(other.type_name())}")
  }
  let mut partial = Partial::empty()
  let mut requested : ArrayView[String]? = None
  for name, value in tables {
    if name != "parser" {
      bad(TomlKey(name), "unknown table")
    }
    let parser = match value {
      TomlTable(m) => m
      other =>
        bad(
          TomlKey(name),
          "expected a table, found \{article(other.type_name())}",
        )
    }
    for key_name, v in parser {
      let source = TomlKey("parser.\{key_name}")
      if key_name == "profiles" {
        let names = match v {
          TomlArray(values) =>
            values.map(value => {
              match value {
                TomlString(name) => name
                other =>
                  bad(
                    source,
                    "expected a profile identity string, found \{article(other.type_name())}",
                  )
              }
            })
          other =>
            bad(
              source,
              "expected an array, found \{article(other.type_name())}",
            )
        }
        requested = Some(names[:])
        continue
      }
      match Key::of_toml(key_name) {
        None => bad(source, "unknown key")
        Some(Gleam) =>
          match v {
            TomlString(s) =>
              partial = { ..partial, dialect: Some(parse_gleam(s, source)), }
            other =>
              bad(
                source,
                "expected a string, found \{article(other.type_name())}",
              )
          }
        Some(Fuel) =>
          match v {
            TomlString("unlimited") =>
              partial = { ..partial, fuel: Some(Unlimited), }
            TomlInteger(n) =>
              partial = {
                ..partial,
                fuel: Some(Limited(parse_fuel(n, source))),
              }
            other =>
              bad(
                source,
                "expected an integer, found \{article(other.type_name())}",
              )
          }
      }
    }
  }
  if requested is Some(identities) {
    let dialect = profiles.apply(
      partial.dialect.unwrap_or(@dialect.Dialect::gleam_1_19()),
      identities,
    ) catch {
      MissingProfile(name) =>
        bad(TomlKey("parser.profiles"), "profile \"\{name}\" is not available")
      DuplicateProfile(name) =>
        bad(
          TomlKey("parser.profiles"),
          "profile \"\{name}\" is requested more than once",
        )
      InvalidIdentity(name) =>
        bad(TomlKey("parser.profiles"), "invalid profile identity \"\{name}\"")
      TargetConflict(name~, existing~, incoming~) =>
        bad(
          TomlKey("parser.profiles"),
          "target \"\{name}\" conflicts between \"\{existing}\" and \"\{incoming}\"",
        )
    }
    partial = { ..partial, dialect: Some(dialect), }
  }
  partial
}

///|
/// `GLEAM_PARSER_GLEAM` and `GLEAM_PARSER_FUEL` from `env`. An unset
/// variable leaves the field unset; an empty or bad value is a
/// `ConfigError` that names the variable.
/// `GLEAM_PARSER_FUEL=unlimited` clears a fallback's finite limit.
pub fn Config::from_env(env : Environment) -> Partial raise ConfigError {
  let mut partial = Partial::empty()
  for key in Key::all() {
    let name = key.env_name()
    let source = EnvVar(name)
    match env.get(name) {
      None => ()
      Some("") => bad(source, "empty value")
      Some(text) =>
        match key {
          Gleam =>
            partial = { ..partial, dialect: Some(parse_gleam(text, source)), }
          Fuel if text == "unlimited" =>
            partial = { ..partial, fuel: Some(Unlimited), }
          Fuel => {
            let n = @string.parse_int64(text) catch {
              _ => bad(source, "expected an integer, found \"\{text}\"")
            }
            partial = { ..partial, fuel: Some(Limited(parse_fuel(n, source))), }
          }
        }
    }
  }
  partial
}

///|
/// The configuration from the environment over the TOML file over the
/// defaults. `path` is `gleam-parser.toml` by default; a missing file
/// contributes nothing, a file that cannot be read is a `ConfigError`
/// with `File(path)` and the system's text, and a TOML error from the file
/// names the file in front of its message. The only function of this
/// package with I/O. Optional profile names resolve only through the supplied
/// `profiles` registry, which is empty by default.
///
/// ```mbt nocheck
/// fn parse_with_config(text : String) -> @gleam.ParseResult raise {
///   let config = @gleam.Config::load()
///   @gleam.parse_text(text, config~)
/// }
/// ```
pub fn Config::load(
  path~ : String = "gleam-parser.toml",
  env? : Environment,
  profiles~ : @dialect.Profiles = @dialect.Profiles::empty(),
) -> Config raise ConfigError {
  let env = match env {
    Some(e) => e
    None => Environment::system()
  }
  let file = if @fs.path_exists(path) {
    let text = @fs.read_file_to_string(path) catch {
      @fs.IOError(detail) => bad(File(path), "cannot read the file: \{detail}")
    }
    // A TOML error from the file names the file in front of its message.
    Config::from_toml(text, profiles~) catch {
      ConfigError(source~, message~) =>
        raise ConfigError(source~, message="\{path}: \{message}")
    }
  } else {
    Partial::empty()
  }
  Config::from_env(env).with_fallback(file).to_config(Config::default())
}
