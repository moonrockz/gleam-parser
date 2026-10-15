///|
/// A deprecated-syntax rule the parser warns about: one per kind of the
/// compiler's `DeprecatedSyntaxWarning`.
pub(all) enum Rule {
  DeprecatedListPrepend
  DeprecatedListPattern
  DeprecatedListCatchAllPattern
  DeprecatedListSpreadAsVariablePattern
  DeprecatedRecordSpreadPattern
  DeprecatedEmptyClauseGuard
  DeprecatedTargetShorthand
} derive(Eq, Debug, Hash)

///|
/// The rule's name, as a diagnostic names it.
pub fn Rule::name(self : Rule) -> String {
  match self {
    DeprecatedListPrepend => "deprecated-list-prepend"
    DeprecatedListPattern => "deprecated-list-pattern"
    DeprecatedListCatchAllPattern => "deprecated-list-catch-all-pattern"
    DeprecatedListSpreadAsVariablePattern =>
      "deprecated-list-spread-as-variable-pattern"
    DeprecatedRecordSpreadPattern => "deprecated-record-spread-pattern"
    DeprecatedEmptyClauseGuard => "deprecated-empty-clause-guard"
    DeprecatedTargetShorthand => "deprecated-target-shorthand"
  }
}

///|
pub fn Rule::all() -> Array[Rule] {
  [
    DeprecatedListPrepend,
    DeprecatedListPattern,
    DeprecatedListCatchAllPattern,
    DeprecatedListSpreadAsVariablePattern,
    DeprecatedRecordSpreadPattern,
    DeprecatedEmptyClauseGuard,
    DeprecatedTargetShorthand,
  ]
}

///|
/// What the parser accepts: the reserved words, the attribute names
/// (`@external`, …), the target names, and the deprecated syntax it warns
/// about. `Dialect::gleam_1_19()` is the default and the only built-in.
///
/// ```mbt check
/// test {
///   let d = @dialect.Dialect::gleam_1_19()
///   inspect(d.knows_attribute("deprecated"), content="true")
///   inspect(d.warns(DeprecatedListPrepend), content="true")
/// }
/// ```
pub(all) struct Dialect {
  name : String
  keywords : ArrayView[String]
  attributes : ArrayView[String]
  targets : ArrayView[String]
  deprecations : ArrayView[Rule]
} derive(Eq, Debug)

///|
/// Gleam 1.19: the compiler's 22 reserved words, the four attributes, the
/// two targets, and every deprecation warning on.
pub fn Dialect::gleam_1_19() -> Dialect {
  {
    name: "gleam-1.19",
    keywords: [
      "as", "assert", "auto", "case", "const", "delegate", "derive", "echo", "else",
      "fn", "if", "implement", "import", "let", "macro", "opaque", "panic", "pub",
      "test", "todo", "type", "use",
    ][:],
    attributes: ["external", "target", "deprecated", "internal"][:],
    targets: ["erlang", "javascript"][:],
    deprecations: Rule::all()[:],
  }
}

///|
pub fn Dialect::warns(self : Dialect, rule : Rule) -> Bool {
  self.deprecations.contains(rule)
}

///|
pub fn Dialect::knows_attribute(self : Dialect, name : String) -> Bool {
  self.attributes.contains(name)
}

///|
pub fn Dialect::knows_target(self : Dialect, name : String) -> Bool {
  self.targets.contains(name)
}

///|
/// The Gleam versions with a built-in dialect, as `from_version` reads
/// them.
pub fn Dialect::known_versions() -> Array[String] {
  ["1.19"]
}

///|
/// The built-in dialect for a Gleam version (`"1.19"`), or `None`.
///
/// ```mbt check
/// test {
///   debug_inspect(
///     @dialect.Dialect::from_version("1.19").map(d => d.version()),
///     content="Some(\"1.19\")",
///   )
/// }
/// ```
pub fn Dialect::from_version(version : String) -> Dialect? {
  match version {
    "1.19" => Some(Dialect::gleam_1_19())
    _ => None
  }
}

///|
/// The Gleam version this dialect follows (`"1.19"` for `gleam-1.19`).
pub fn Dialect::version(self : Dialect) -> String {
  if self.name.has_prefix("gleam-") {
    self.name[6:].to_owned()
  } else {
    self.name
  }
}
