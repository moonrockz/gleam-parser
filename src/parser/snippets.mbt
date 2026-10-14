///|
fn Parser::from_text(text : String, dialect : @dialect.Dialect) -> Parser {
  Parser::new(@scanner.tokenize_text(text), dialect)
}

///|
/// The first lexical error the compiler's lexer would have reached before
/// the parser stopped: a scanner error diagnostic that starts before the
/// farthest token loaded.
fn first_lexical_error(
  stream : @scanner.TokenStream,
  farthest : Int32,
) -> @diagnostic.Diagnostic? {
  for d in stream.diagnostics {
    if d.code == "GL-SCAN-001" && d.span.start < farthest {
      return Some(d)
    }
  }
  None
}

///|
/// The compiler's `ensure_no_errors_or_remaining_input` for a snippet: a
/// lexical error first, then a missing result (`missing`), then leftover
/// tokens.
fn[A] Parser::finish_snippet(
  self : Parser,
  stream : @scanner.TokenStream,
  result : A?,
  missing : ParseErrorType,
) -> A raise ParseError {
  if first_lexical_error(stream, self.farthest) is Some(d) {
    parse_error(LexError(d), d.span)
  }
  guard result is Some(value) else { parse_error(missing, sp(0, 0)) }
  match self.next_token() {
    Some(t) =>
      parse_error(
        UnexpectedToken(
          token=t.kind,
          expected=["An import, const, type, or function."][:],
          hint=None,
        ),
        t.span,
      )
    None => value
  }
}

///|
/// Parse `text` as one type annotation (without `:`), for tests and tools.
///
/// ```mbt check
/// test {
///   let t = @parser.parse_type_text("List(a)")
///   debug_inspect(t.location(), content="{ start: 0, end: 7 }")
/// }
/// ```
pub fn parse_type_text(text : String) -> @ast.TypeAst raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, @dialect.Dialect::gleam_1_19())
  let result = p.parse_type()
  p.finish_snippet(stream, result, ExpectedType)
}

///|
/// Parse `text` as one pattern.
pub fn parse_pattern_text(text : String) -> @ast.Pattern raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, @dialect.Dialect::gleam_1_19())
  let result = p.parse_pattern()
  p.finish_snippet(stream, result, ExpectedPattern)
}

///|
/// Parse `text` as one constant value (the compiler's `parse_const_value`
/// test interface; a missing value is `ExpectedExpr` at `0..0`).
pub fn parse_constant_text(text : String) -> @ast.Constant raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, @dialect.Dialect::gleam_1_19())
  let result = p.parse_const_value()
  p.finish_snippet(stream, result, ExpectedExpr)
}
