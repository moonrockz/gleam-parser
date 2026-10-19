///|
/// Return the Morphir profile's release version. It is independent of the
/// core parser version. This module requires core parser 0.5.0 or later.
pub fn version() -> String {
  "0.1.2"
}

///|
/// Construct the optional Morphir profile through the public core API.
/// It registers only `morphir`. Standard targets stay available; other
/// extension targets stay unregistered. Importing this module does not enable
/// the profile. Pass it to `Dialect::with_profile` explicitly.
/// The registration supplies syntax and AST metadata, not a Morphir backend.
/// Module and symbol strings are opaque references interpreted by consumers.
/// It accepts these Gleam annotations, which the standard preset rejects:
///
/// ```gleam
/// @target(morphir)
/// pub const answer = 42
///
/// @external(morphir, "example/domain", "CustomerId")
/// pub type CustomerId
/// ```
///
/// `@target` records a restriction. `@external` records a binding without
/// adding a restriction. Standard Erlang and JavaScript bindings can coexist
/// with a Morphir binding on the same function or external type.
///
/// ```mbt check
/// test {
///   let dialect = @morphir.Dialect::gleam_1_19().with_profile(@morphir.profile())
///   let config = { ..@morphir.Config::default(), dialect, }
///   let result = @morphir.parse_text(
///     "@target(morphir) pub const answer = 42",
///     config~,
///   )
///   assert_eq(result.has_errors(), false)
///   assert_eq(dialect.knows_target("scala"), false)
/// }
/// ```
pub fn profile() -> @gleam.Profile raise {
  @gleam.Profile(
    "moonrockz/gleam-parser-morphir@0.1.2",
    [@gleam.Target::extension("morphir")][:],
  )
}

///|
/// Common core APIs for consumers that install only the Morphir module.
/// Parsing still defaults to strict standard Gleam. Enable `profile()` in a
/// dialect and pass its configuration explicitly to accept Morphir annotations.
/// These are re-exports of the core functions, with identical errors and behavior.
/// For other core APIs, declare a direct `moonrockz/gleam-parser` dependency.
///
/// ```mbt check
/// test {
///   let text = "@target(morphir) pub const value = 1"
///   assert_eq(@morphir.parse_text(text).has_errors(), true)
///   let config = {
///     ..@morphir.Config::default(),
///     dialect: @morphir.Dialect::gleam_1_19().with_profile(@morphir.profile()),
///   }
///   let result = @morphir.parse_text(text, config~)
///   assert_eq(result.has_errors(), false)
///   assert_eq(
///     @morphir.decode_extended(@morphir.encode_extended(result)).parsed,
///     result.parsed(),
///   )
/// }
/// ```
pub using @gleam {
  type Config,
  type Dialect,
  type Profile,
  type Profiles,
  type Target,
  parse_text,
  format,
  format_parsed,
  encode_extended,
  decode_extended,
  encode_parsed,
  decode_parsed,
}
