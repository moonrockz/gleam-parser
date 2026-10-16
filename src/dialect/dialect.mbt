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
/// Every supported deprecation rule in declaration order.
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
  /// Reserved scanner keywords. Omitted keywords parse as ordinary names.
  keywords : ArrayView[@scanner.Keyword]
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
      @scanner.Keyword::As,
      @scanner.Keyword::Assert,
      @scanner.Keyword::Auto,
      @scanner.Keyword::Case,
      @scanner.Keyword::Const,
      @scanner.Keyword::Delegate,
      @scanner.Keyword::Derive,
      @scanner.Keyword::Echo,
      @scanner.Keyword::Else,
      @scanner.Keyword::Fn,
      @scanner.Keyword::If,
      @scanner.Keyword::Implement,
      @scanner.Keyword::Import,
      @scanner.Keyword::Let,
      @scanner.Keyword::Macro,
      @scanner.Keyword::Opaque,
      @scanner.Keyword::Panic,
      @scanner.Keyword::Pub,
      @scanner.Keyword::Test,
      @scanner.Keyword::Todo,
      @scanner.Keyword::Type,
      @scanner.Keyword::Use,
    ][:],
    attributes: ["external", "target", "deprecated", "internal"][:],
    targets: ["erlang", "javascript"][:],
    deprecations: Rule::all()[:],
  }
}

///|
/// Whether this dialect emits warnings for the specified deprecation rule.
pub fn Dialect::warns(self : Dialect, rule : Rule) -> Bool {
  self.deprecations.contains(rule)
}

///|
/// Whether this dialect accepts an attribute name without its `@` prefix.
pub fn Dialect::knows_attribute(self : Dialect, name : String) -> Bool {
  self.attributes.contains(name)
}

///|
/// Whether this dialect accepts the canonical name of a target.
/// Shorthand names are resolved by the parser before this check.
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

///|
/// Whether the parser treats a scanner keyword as reserved.
/// Omitted keywords parse as names; scanner output remains unchanged.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @dialect.Dialect::gleam_1_19().reserves(@scanner.Keyword::Echo),
///     true,
///   )
/// }
/// ```
pub fn Dialect::reserves(self : Dialect, keyword : @scanner.Keyword) -> Bool {
  self.keywords.contains(keyword)
}
