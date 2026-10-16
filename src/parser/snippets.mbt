///|
/// The first lexical error the compiler's lexer would have reached before
/// the parser stopped: a scanner error diagnostic that starts before the
/// farthest token loaded.
fn first_lexical_error(
  stream : @scanner.TokenStream,
  farthest : @span.ByteOffset,
) -> @diagnostic.Diagnostic? {
  for d in stream.diagnostics {
    if d.code == "GL-SCAN-001" && d.span.start < farthest {
      return Some(d)
    }
  }
  None
}

///|
/// Run a snippet parse and keep its error as a value, so a lexical error
/// the lexer reached can be reported first.
fn[A] attempt_parse(f : () -> A? raise ParseError) -> Result[A?, ParseError] {
  try f() catch {
    e => Err(e)
  } noraise {
    v => Ok(v)
  }
}

///|
/// The compiler's `ensure_no_errors_or_remaining_input` for a snippet: a
/// lexical error first, then a missing result (`missing`), then leftover
/// tokens.
fn[A] Parser::finish_snippet(
  self : Parser,
  stream : @scanner.TokenStream,
  result : Result[A?, ParseError],
  missing : ParseErrorType,
) -> A raise ParseError {
  if first_lexical_error(stream, self.farthest) is Some(d) {
    parse_error(LexError(d), d.span)
  }
  let parsed = match result {
    Ok(v) => v
    Err(e) => raise e
  }
  guard parsed is Some(value) else {
    parse_error(missing, sp(@span.ByteOffset::zero(), @span.ByteOffset::zero()))
  }
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
///   debug_inspect(
///     t.location(),
///     content=(
///       #|{ start: ByteOffset(0), end: ByteOffset(7) }
///     ),
///   )
/// }
/// ```
pub fn parse_type_text(
  text : String,
  config? : @config.Config,
) -> @ast.TypeAst raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, config.unwrap_or(@config.Config::default()))
  let result = attempt_parse(() => p.parse_type())
  p.finish_snippet(stream, result, ExpectedType)
}

///|
/// Parse `text` as one pattern.
pub fn parse_pattern_text(
  text : String,
  config? : @config.Config,
) -> @ast.Pattern raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, config.unwrap_or(@config.Config::default()))
  let result = attempt_parse(() => p.parse_pattern())
  p.finish_snippet(stream, result, ExpectedPattern)
}

///|
/// Parse `text` as one constant value (the compiler's `parse_const_value`
/// test interface; a missing value is `ExpectedExpr` at `0..0`).
pub fn parse_constant_text(
  text : String,
  config? : @config.Config,
) -> @ast.Constant raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, config.unwrap_or(@config.Config::default()))
  let result = attempt_parse(() => p.parse_const_value())
  p.finish_snippet(stream, result, ExpectedExpr)
}

///|
/// Parse `text` as one expression (a pipeline or an operator chain counts
/// as one); a missing expression is `ExpectedExpr` at `0..0`.
///
/// ```mbt check
/// test {
///   let e = @parser.parse_expression_text("1 + 2")
///   debug_inspect(
///     e.location(),
///     content=(
///       #|{ start: ByteOffset(0), end: ByteOffset(5) }
///     ),
///   )
/// }
/// ```
pub fn parse_expression_text(
  text : String,
  config? : @config.Config,
) -> @ast.Expr raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, config.unwrap_or(@config.Config::default()))
  let result = attempt_parse(() => p.parse_expression())
  p.finish_snippet(stream, result, ExpectedExpr)
}

///|
/// Parse `text` as a statement sequence (a function body without braces),
/// the compiler's `parse_statement_sequence` test interface.
pub fn parse_statements_text(
  text : String,
  config? : @config.Config,
) -> ArrayView[@ast.Statement] raise ParseError {
  let stream = @scanner.tokenize_text(text)
  let p = Parser::new(stream, config.unwrap_or(@config.Config::default()))
  let result = attempt_parse(() => p.parse_statement_sequence().map(r => r.0[:]))
  p.finish_snippet(stream, result, ExpectedExpr)
}
