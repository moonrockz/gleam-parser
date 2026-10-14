///|
/// How serious a diagnostic is. A file with an `Error` is rejected; a
/// `Warning` does not stop parsing.
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, Debug, Hash)

///|
/// A span with the text the compiler shows under it.
pub(all) struct Label {
  span : @span.SrcSpan
  text : String
} derive(Eq, Debug)

///|
/// A problem found while scanning or parsing, in the Gleam compiler's shape:
/// a `title` ("Syntax error"), a primary `span` with its `message` (the
/// compiler's label text), extra `labels`, and an optional `hint`.
/// `code` is one of `codes()`.
pub(all) struct Diagnostic {
  code : String
  severity : Severity
  title : String
  message : String
  span : @span.SrcSpan
  labels : ArrayView[Label]
  hint : String?
} derive(Eq, Debug)

///|
/// ```mbt check
/// test {
///   let d = @diagnostic.Diagnostic::new(
///     code="GL-SCAN-001",
///     severity=Error,
///     title="Syntax error",
///     message="I don't know what this character means",
///     span=@span.SrcSpan::new(2, 3),
///   )
///   debug_inspect(d.is_error(), content="true")
///   debug_inspect(d.labels.length(), content="0")
/// }
/// ```
pub fn Diagnostic::new(
  code~ : String,
  severity~ : Severity,
  title~ : String,
  message~ : String,
  span~ : @span.SrcSpan,
  labels~ : Array[Label] = [],
  hint~ : String? = None,
) -> Diagnostic {
  { code, severity, title, message, span, labels: labels[:], hint, }
}

///|
pub fn Diagnostic::is_error(self : Diagnostic) -> Bool {
  self.severity == Error
}
