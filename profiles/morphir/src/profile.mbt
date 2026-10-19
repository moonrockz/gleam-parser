///|
/// Return the Morphir profile's release version. It is independent of the
/// core parser version. This module requires core parser 0.5.0 or later.
pub fn version() -> String {
  "0.1.0"
}

///|
/// Construct the optional Morphir profile through the public core API.
/// It registers only `morphir`. Standard targets stay available; other
/// extension targets stay unregistered. Importing this module does not enable
/// the profile. Pass it to `Dialect::with_profile` explicitly.
/// The registration supplies syntax and AST metadata, not a Morphir backend.
/// Module and symbol strings are opaque references interpreted by consumers.
///
/// ```mbt check
/// test {
///   let dialect = @gleam.Dialect::gleam_1_19().with_profile(@morphir.profile())
///   let config = { ..@gleam.Config::default(), dialect, }
///   let result = @gleam.parse_text(
///     "@target(morphir) pub const answer = 42",
///     config~,
///   )
///   assert_eq(result.has_errors(), false)
///   assert_eq(dialect.knows_target("scala"), false)
/// }
/// ```
pub fn profile() -> @gleam.Profile raise {
  @gleam.Profile(
    "moonrockz/gleam-parser-morphir@0.1.0",
    [@gleam.Target::extension("morphir")][:],
  )
}
