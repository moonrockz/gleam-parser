///|
/// Why `format` gives no text.
pub(all) suberror FormatError {
  /// An explicit formatting dialect differs from the parse dialect.
  DialectMismatch(expected~ : @dialect.Dialect, supplied~ : @dialect.Dialect)
  /// The text has a diagnostic with severity `Error` (all of them, in the
  /// parser's order). Render them with `@report.render_plain`.
  ParseFailed(Array[@diagnostic.Diagnostic])
  /// The fuel budget of the configuration ran out while the formatter
  /// walked a definition; the error names the operations on the stack.
  OutOfFuel(@fuel.FuelExhausted)
} derive(Eq, Debug)

///|
/// Format Gleam source as `gleam format` (1.19.2) does: 80 columns, two
/// spaces of indentation, no options. Comments and empty lines are kept
/// where the compiler keeps them; the output is idempotent and parses
/// again where the compiler's is (see "Format Parity" in AGENTS.md for
/// the known differences). Raises `ParseFailed` when the text has a
/// syntax error,
/// `OutOfFuel` when `config.fuel` runs out.
///
/// ```mbt check
/// test {
///   inspect(
///     @format.format("pub fn main(){\n  io.println(  \"hi\" )\n}\n"),
///     content="pub fn main() {\n  io.println(\"hi\")\n}\n",
///   )
/// }
/// ```
pub fn format(
  text : String,
  config? : @config.Config,
) -> String raise FormatError {
  format_parsed(@parser.parse_text(text, config?), config?)
}

///|
/// Format a parse result, as `format` formats text. The source is rebuilt
/// from the CST (byte for byte), so the comments keep their text. Raises
/// `ParseFailed` when the result has an error diagnostic. By default, use the
/// configuration stored in the result. An explicit different dialect raises
/// `DialectMismatch`; an explicit fuel change is allowed. Every target and
/// external binding is preserved. Layout changes can move source locations.
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("//// m\n// c\n")
///   inspect(@format.format_parsed(r), content="//// m\n\n// c\n")
/// }
/// ```
pub fn format_parsed(
  result : @parser.ParseResult,
  config? : @config.Config,
) -> String raise FormatError {
  let errors = result.diagnostics
    .iter()
    .filter(d => d.severity is Error)
    .to_array()
  guard errors.is_empty() else { raise ParseFailed(errors) }
  let config = match config {
    Some(c) => {
      if c.dialect != result.config.dialect {
        raise DialectMismatch(
          expected=result.config.dialect,
          supplied=c.dialect,
        )
      }
      c
    }
    None => result.config
  }
  let source = @scanner.SourceText(result.cst.to_source())
  let formatter = Formatter(result.extra, source, config)
  pretty_print(
    formatter.runner.run(() => formatter.format_module(result.module_)),
  )
}

///|
/// Lay out a document as the compiler's `pretty_print(80)` does.
fn pretty_print(doc : @pretty.Doc) -> String {
  @pretty.render(doc, width=80, start=Unbroken)
}
