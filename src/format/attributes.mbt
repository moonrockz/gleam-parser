///|
/// The compiler's `AttributesPrinter::to_doc`: the `@deprecated`,
/// `@external` and `@internal` lines before a definition.
fn attributes(
  deprecation : @ast.Deprecation,
  publicity : @ast.Publicity,
  external_erlang : @ast.External?,
  external_javascript : @ast.External?,
) -> @pretty.Doc {
  let parts : Array[@pretty.Doc] = []
  if deprecation is Deprecated(message~) {
    parts.push(t("@deprecated(\"") + @pretty.raw_text(message) + t("\")"))
  }
  if external_erlang is Some(e) {
    parts.push(
      t("@external(erlang, \"") +
      @pretty.raw_text(e.module_) +
      t("\", \"") +
      @pretty.raw_text(e.function) +
      t("\")"),
    )
  }
  if external_javascript is Some(e) {
    parts.push(
      t("@external(javascript, \"") +
      @pretty.raw_text(e.module_) +
      t("\", \"") +
      @pretty.raw_text(e.function) +
      t("\")"),
    )
  }
  if publicity is Internal(..) {
    parts.push(t("@internal"))
  }
  if parts.is_empty() {
    @pretty.empty()
  } else {
    @pretty.join(parts, line_doc) + line_doc
  }
}
