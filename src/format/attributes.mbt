///|
/// The compiler's `AttributesPrinter::to_doc`: the `@deprecated`,
/// `@external` and `@internal` lines before a definition.
fn attributes(
  deprecation : @ast.Deprecation,
  publicity : @ast.Publicity,
  externals : @ast.ExternalBindings,
) -> @pretty.Doc {
  let parts : Array[@pretty.Doc] = []
  if deprecation is Deprecated(message~) {
    parts.push(t("@deprecated(\"") + @pretty.raw_text(message) + t("\")"))
  }
  for binding in externals.all() {
    let e = binding.external
    parts.push(
      t("@external(" + binding.target.name() + ", \"") +
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
