///|
/// A target name that the scanner reads as one ordinary name.
/// Standard identities and their aliases cannot be extension names.
/// Construct this value with `Name::Name` or `Name::from_string`.
pub struct Name {
  value : String
} derive(Eq, Debug, Hash)

///|
/// An invalid name or a registration that conflicts with an existing target.
/// `Conflict` names the canonical target. Registration never replaces a value.
pub(all) suberror RegistrationError {
  InvalidName(String)
  Conflict(String)
} derive(Eq, Debug)

///|
/// Validate an extension name. Raise `InvalidName` for keywords, standard
/// target names, aliases, whitespace, or punctuation.
///
/// ```mbt check
/// test {
///   assert_eq(@targets.Name("orbit").to_string(), "orbit")
///   assert_eq(@targets.Name::from_string("js"), None)
/// }
/// ```
pub fn Name::Name(value : String) -> Name raise RegistrationError {
  match Name::from_string(value) {
    Some(name) => name
    None => raise InvalidName(value)
  }
}

///|
/// Validate a name without raising an error. Return `None` for invalid names.
pub fn Name::from_string(value : String) -> Name? {
  if value == "erlang" ||
    value == "javascript" ||
    value == "erl" ||
    value == "js" {
    return None
  }
  let stream = @scanner.tokenize_text(value)
  if stream.tokens.length() != 1 || !stream.diagnostics.is_empty() {
    return None
  }
  match stream.tokens[0].kind {
    Name(name) if name == value => Some({ value, })
    _ => None
  }
}

///|
/// Return the validated source spelling.
pub fn Name::to_string(self : Name) -> String {
  self.value
}

///|
/// An execution or translation destination. Registration enables syntax
/// and representation; it does not supply a backend or resolve foreign symbols.
/// Extension identities contain a validated name and require no new enum case.
pub(all) enum Target {
  Erlang
  JavaScript
  Extension(Name)
} derive(Eq, Debug, Hash)

///|
/// Construct an extension identity. Raise `InvalidName` for reserved or
/// malformed names. Register the identity in a dialect before parsing it.
pub fn Target::extension(name : String) -> Target raise RegistrationError {
  Extension(Name(name))
}

///|
/// Return the canonical source and JSON spelling.
pub fn Target::name(self : Target) -> String {
  match self {
    Erlang => "erlang"
    JavaScript => "javascript"
    Extension(name) => name.to_string()
  }
}

///|
/// Read a standard compiler target name. Extensions require registry lookup.
pub fn Target::of(name : String) -> Target? {
  match name {
    "erlang" => Some(Erlang)
    "javascript" => Some(JavaScript)
    _ => None
  }
}

///|
/// An immutable set of canonical target identities. Standard identities and
/// aliases are reserved. Use `standard`, then `register` for each extension.
pub struct Registry {
  targets : ArrayView[Target]
} derive(Eq, Debug)

///|
/// The strict standard registry: Erlang and JavaScript.
pub fn Registry::standard() -> Registry {
  { targets: [Erlang, JavaScript][:], }
}

///|
/// Return a new registry with this extension. Raise `Conflict` if the
/// canonical name already exists, including either standard identity.
/// The original registry is unchanged on success and failure.
///
/// ```mbt check
/// test {
///   let base = @targets.Registry::standard()
///   let orbit = @targets.Target::extension("orbit")
///   let extended = base.register(orbit)
///   assert_eq(base.resolve("orbit"), None)
///   assert_eq(extended.resolve("orbit"), Some(orbit))
/// }
/// ```
pub fn Registry::register(
  self : Registry,
  target : Target,
) -> Registry raise RegistrationError {
  if self.resolve(target.name()) is Some(_) {
    raise Conflict(target.name())
  }
  let targets = self.targets.to_owned()
  targets.push(target)
  targets.sort_by((a, b) => {
    match (a, b) {
      (Erlang, Erlang) | (JavaScript, JavaScript) => 0
      (Erlang, _) => -1
      (_, Erlang) => 1
      (JavaScript, _) => -1
      (_, JavaScript) => 1
      _ => a.name().compare(b.name())
    }
  })
  { targets: targets[:], }
}

///|
/// Resolve a registered canonical name. With `aliases=true`, also resolve
/// the compiler's deprecated `erl` and `js` shorthands. The parser uses these
/// shorthands only for `@target`, matching standard Gleam.
pub fn Registry::resolve(
  self : Registry,
  name : String,
  aliases~ : Bool = false,
) -> Target? {
  let name = if aliases {
    match name {
      "erl" => "erlang"
      "js" => "javascript"
      _ => name
    }
  } else {
    name
  }
  for target in self.targets {
    if target.name() == name {
      return Some(target)
    }
  }
  None
}

///|
/// Return a copy of the registered identities in deterministic order, with standard targets first.
pub fn Registry::all(self : Registry) -> Array[Target] {
  self.targets.to_owned()
}
