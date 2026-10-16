///|
/// The compiler's `case` (Task 3). Until then a placeholder.
fn Formatter::case_(
  self : Formatter,
  _subjects : ArrayView[@ast.Expr],
  _clauses : ArrayView[@ast.Clause],
  _location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  self.nested(op_format, () => t("todo"))
}
