///|
/// The version of gleam-parser, the same as `version` in `moon.mod`.
/// `mise run release:prepare` rewrites the string below; `tests/bdd`
/// checks that it equals `moon.mod`.
///
/// ```mbt check
/// test {
///   inspect(@gleam.version().split(".").count(), content="3")
/// }
/// ```
pub fn version() -> String {
  "0.0.1"
}

///|
/// Spans (UTF-8 byte offsets) and positions (1-based line and column).
pub using @span {type SrcSpan, type Position}
