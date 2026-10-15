///|
fn sp(start : Int32, end : Int32) -> @span.SrcSpan {
  @span.SrcSpan::new(start, end)
}

///|
fn[A] parse_error(
  error : ParseErrorType,
  location : @span.SrcSpan,
) -> A raise ParseError {
  raise ParseError(error~, location~)
}

///|
/// The attributes seen before a definition (the compiler's `Attributes`).
/// `internal` holds the span of `@internal` when present.
priv struct Attributes {
  mut target : @ast.Target?
  mut deprecated : @ast.Deprecation
  mut external_erlang : @ast.External?
  mut external_javascript : @ast.External?
  mut internal : @span.SrcSpan?
}

///|
fn Attributes::new() -> Attributes {
  {
    target: None,
    deprecated: NotDeprecated,
    external_erlang: None,
    external_javascript: None,
    internal: None,
  }
}

///|
fn Attributes::has_function_only(self : Attributes) -> Bool {
  self.external_erlang is Some(_) || self.external_javascript is Some(_)
}

///|
fn Attributes::has_external_for(
  self : Attributes,
  target : @ast.Target,
) -> Bool {
  match target {
    Erlang => self.external_erlang is Some(_)
    JavaScript => self.external_javascript is Some(_)
  }
}

///|
fn Attributes::set_external_for(
  self : Attributes,
  target : @ast.Target,
  external : @ast.External,
) -> Unit {
  match target {
    Erlang => self.external_erlang = Some(external)
    JavaScript => self.external_javascript = Some(external)
  }
}

///|
/// The parser state: the compiler's two-token lookahead over the scanned
/// tokens. A scanner `Error` token loads as `None`, the hole the compiler's
/// parser sees at a lexical error; the stream goes on after it.
priv struct Parser {
  tokens : ArrayView[@scanner.Token]
  config : @config.Config
  /// The array index of the next token to load.
  mut index : Int32
  /// The array indexes of the slots `token0` and `token1` came from
  /// (`tokens.length()` at the end).
  mut index0 : Int32
  mut index1 : Int32
  mut token0 : @scanner.Token?
  mut token1 : @scanner.Token?
  /// The byte end of the farthest token loaded, `Error` tokens included:
  /// how far the compiler's lexer would have read.
  mut farthest : Int32
  /// The fuel of the current scope; `nested` swaps a spent value in for
  /// the body and `Ref::protect` puts the outer one back, on return and on
  /// error alike.
  fuel : Ref[@fuel.Fuel]
  warnings : Array[@ast.Warning]
  trailing_commas : Array[Int32]
  /// Every doc comment (`///`) in order: its content span and content.
  doc_comments : Array[(@span.SrcSpan, String)]
  /// The first doc comment not yet taken.
  mut doc_head : Int32
  detached_doc_comments : Array[@span.SrcSpan]
  /// Every regular comment's content span, in order.
  comments : Array[@span.SrcSpan]
}

///|
fn Parser::new(
  stream : @scanner.TokenStream,
  config : @config.Config,
) -> Parser {
  let doc_comments : Array[(@span.SrcSpan, String)] = []
  let comments : Array[@span.SrcSpan] = []
  fn gather(trivia : ArrayView[@scanner.Trivia]) {
    for t in trivia {
      if t is Comment(c) {
        match c.kind {
          Regular => comments.push(c.content_span())
          Doc => doc_comments.push((c.content_span(), c.content))
          Module => ()
        }
      }
    }
  }

  gather(stream.trivia)
  for token in stream.tokens {
    gather(token.trivia_before)
    gather(token.trivia_after)
  }
  let p = {
    tokens: stream.tokens,
    config,
    index: 0,
    index0: 0,
    index1: 0,
    token0: None,
    token1: None,
    farthest: 0,
    fuel: { val: @fuel.Fuel::new(budget=config.fuel), },
    warnings: [],
    trailing_commas: [],
    doc_comments,
    doc_head: 0,
    detached_doc_comments: [],
    comments,
  }
  p.seek(0)
  p
}

///|
/// Load the token at `index` into the lookahead: `None` at the end and for
/// an `Error` token (a lexical error is a hole in the compiler's stream).
fn Parser::load(self : Parser) -> @scanner.Token? {
  if self.index >= self.tokens.length() {
    return None
  }
  let t = self.tokens[self.index]
  self.index += 1
  if t.span.end > self.farthest {
    self.farthest = t.span.end
  }
  if t.kind is Error {
    None
  } else {
    Some(t)
  }
}

///|
/// Point the lookahead at the token with array index `i`.
fn Parser::seek(self : Parser, i : Int32) -> Unit {
  self.index = i
  self.index0 = i
  self.token0 = self.load()
  self.index1 = self.index
  self.token1 = self.load()
}

///|
/// Move the stream forward; the old `token0`.
fn Parser::next_token(self : Parser) -> @scanner.Token? {
  let t = self.token0
  self.token0 = self.token1
  self.index0 = self.index1
  self.index1 = self.index
  self.token1 = self.load()
  t
}

///|
fn Parser::advance(self : Parser) -> Unit {
  ignore(self.next_token())
}

///|
fn Parser::peek_token1(self : Parser) -> @scanner.TokenKind? {
  self.token1.map(t => t.kind)
}

///|
/// Where an error with no better place goes: the current token, or the end
/// of what was read.
fn Parser::here(self : Parser) -> @span.SrcSpan {
  match self.token0 {
    Some(t) => t.span
    None => sp(self.farthest, self.farthest)
  }
}

///|
/// Run `body` one nesting level deeper: one unit of fuel for `op`. When
/// the budget is spent, `TooMuchNesting` at the current token. The outer
/// fuel is back when `body` returns or raises.
fn[A] Parser::nested(
  self : Parser,
  op : @fuel.Operation,
  body : () -> A raise ParseError,
) -> A raise ParseError {
  let inner = self.fuel.val.spend(op) catch {
    @fuel.FuelExhausted(budget~, spent~) =>
      parse_error(TooMuchNesting(budget~, spent~), self.here())
  }
  self.fuel.protect(inner, body)
}

///|
/// Record a deprecation warning when the dialect warns about its rule.
fn Parser::warn(self : Parser, w : @ast.Warning) -> Unit {
  let rule : @dialect.Rule = match w {
    DeprecatedListPrepend(..) => DeprecatedListPrepend
    DeprecatedListPattern(..) => DeprecatedListPattern
    DeprecatedListCatchAllPattern(..) => DeprecatedListCatchAllPattern
    DeprecatedListSpreadAsVariablePattern(..) =>
      DeprecatedListSpreadAsVariablePattern
    DeprecatedRecordSpreadPattern(..) => DeprecatedRecordSpreadPattern
    DeprecatedEmptyClauseGuard(..) => DeprecatedEmptyClauseGuard
    DeprecatedTargetShorthand(..) => DeprecatedTargetShorthand
    DetachedDocComment(..) => {
      self.warnings.push(w)
      return
    }
  }
  if self.config.dialect.warns(rule) {
    self.warnings.push(w)
  }
}

///|
/// Whether the token at array index `i` starts a definition for recovery:
/// `import`, `const`, `pub`, `fn`, `type`, `opaque` or `@` in column 1 (the
/// first token, or a token right after a line end).
fn Parser::at_definition_start(self : Parser, i : Int32) -> Bool {
  guard i >= 0 && i < self.tokens.length() else { return false }
  let t = self.tokens[i]
  let starts = match t.kind {
    Keyword(Import | Const | Pub | Fn | Type | Opaque) | At => true
    _ => false
  }
  guard starts else { return false }
  let before = t.trivia_before
  let after_line_end = before.length() > 0 &&
    before[before.length() - 1] is Newline(_, _)
  // The first token counts when only whitespace (a byte order mark, blank
  // lines) comes before it.
  after_line_end || (i == 0 && before.all(x => !(x is Comment(_))))
}

///|
/// If `token0` is `kind`, consume it: its start and end.
fn Parser::maybe_one(
  self : Parser,
  kind : @scanner.TokenKind,
) -> (Int32, Int32)? {
  match self.token0 {
    Some(t) if t.kind == kind => {
      self.advance()
      Some((t.span.start, t.span.end))
    }
    _ => None
  }
}

///|
/// `token0` must be `kind`: its start and end, or `UnexpectedToken`.
fn Parser::expect_one(
  self : Parser,
  kind : @scanner.TokenKind,
) -> (Int32, Int32) raise ParseError {
  match self.maybe_one(kind) {
    Some(r) => r
    None => self.next_token_unexpected([token_text(kind)])
  }
}

///|
/// `expect_one` after a series, naming the series item in the error.
fn Parser::expect_one_following_series(
  self : Parser,
  kind : @scanner.TokenKind,
  series : String,
) -> (Int32, Int32) raise ParseError {
  match self.maybe_one(kind) {
    Some(r) => r
    None => self.next_token_unexpected([token_text(kind), series])
  }
}

///|
/// Repeat `parser`, with `sep` between items when given.
fn[A] Parser::series_of(
  self : Parser,
  parser : (Parser) -> A? raise ParseError,
  sep : @scanner.TokenKind?,
) -> Array[A] raise ParseError {
  self.series_of_has_trailing_separator(parser, sep).0
}

///|
/// `series_of`, and whether the series ended with a separator. A trailing
/// comma's end goes to `trailing_commas`. Two separators in a row are an
/// `ExtraSeparator` error.
fn[A] Parser::series_of_has_trailing_separator(
  self : Parser,
  parser : (Parser) -> A? raise ParseError,
  sep : @scanner.TokenKind?,
) -> (Array[A], Bool) raise ParseError {
  let results : Array[A] = []
  let mut final_separator : (Int32, Int32)? = None
  while parser(self) is Some(result) {
    results.push(result)
    match sep {
      Some(s) => {
        match self.maybe_one(s) {
          Some(separator) => final_separator = Some(separator)
          None => {
            final_separator = None
            break
          }
        }
        if self.maybe_one(s) is Some((start, end)) {
          parse_error(ExtraSeparator, sp(start, end))
        }
      }
      None => ()
    }
  }
  if sep is Some(Comma) && final_separator is Some((_, end)) {
    self.trailing_commas.push(end)
  }
  (results, final_separator is Some(_))
}

///|
fn Parser::maybe_name(self : Parser) -> (Int32, String, Int32)? {
  match self.token0 {
    Some({ kind: Name(name), span, .. }) => {
      self.advance()
      Some((span.start, name, span.end))
    }
    _ => None
  }
}

///|
fn Parser::maybe_upname(self : Parser) -> (Int32, String, Int32)? {
  match self.token0 {
    Some({ kind: UpName(name), span, .. }) => {
      self.advance()
      Some((span.start, name, span.end))
    }
    _ => None
  }
}

///|
fn Parser::maybe_discard_name(self : Parser) -> (Int32, String, Int32)? {
  match self.token0 {
    Some({ kind: DiscardName(name), span, .. }) => {
      self.advance()
      Some((span.start, name, span.end))
    }
    _ => None
  }
}

///|
/// A lower-case name, or the compiler's error for what was found instead.
fn Parser::expect_name(
  self : Parser,
  kind : IncorrectNamePosition,
) -> (Int32, String, Int32) raise ParseError {
  let (start, name, end) = self.expect_assign_name()
  match name {
    Variable(n) => (start, n, end)
    Discard(_) => parse_error(IncorrectName(kind), sp(start, end))
  }
}

///|
/// A lower-case name or a discard name; an upper-case name is
/// `IncorrectName(Variable)`, a keyword `UnexpectedReservedWord`, anything
/// else `ExpectedName`, the end `UnexpectedEof`.
fn Parser::expect_assign_name(
  self : Parser,
) -> (Int32, @ast.AssignName, Int32) raise ParseError {
  match self.next_token() {
    Some({ kind: Name(name), span, .. }) =>
      (span.start, Variable(name), span.end)
    Some({ kind: DiscardName(name), span, .. }) =>
      (span.start, Discard(name), span.end)
    Some({ kind: UpName(_), span, .. }) =>
      parse_error(IncorrectName(Variable), span)
    Some({ kind: Keyword(_), span, .. }) =>
      parse_error(UnexpectedReservedWord, span)
    Some({ span, .. }) => parse_error(ExpectedName, span)
    None => parse_error(UnexpectedEof, sp(0, 0))
  }
}

///|
/// An upper-case name; a lower-case or discard name is `IncorrectUpName`,
/// anything else `ExpectedUpName`.
fn Parser::expect_upname(
  self : Parser,
) -> (Int32, String, Int32) raise ParseError {
  match self.next_token() {
    Some({ kind: UpName(name), span, .. }) => (span.start, name, span.end)
    Some({ kind: Name(_) | DiscardName(_), span, .. }) =>
      parse_error(IncorrectUpName, span)
    Some({ span, .. }) => parse_error(ExpectedUpName, span)
    None => parse_error(UnexpectedEof, sp(0, 0))
  }
}

///|
fn Parser::expect_string(
  self : Parser,
) -> (Int32, String, Int32) raise ParseError {
  match self.token0 {
    Some({ kind: String(value), span, .. }) => {
      self.advance()
      (span.start, value, span.end)
    }
    _ => self.next_token_unexpected(["a string"])
  }
}

///|
/// `UnexpectedToken` on the next token, or `UnexpectedEof` at `0..0`.
fn[A] Parser::next_token_unexpected(
  self : Parser,
  expected : Array[String],
) -> A raise ParseError {
  match self.next_token() {
    None => parse_error(UnexpectedEof, sp(0, 0))
    Some(t) =>
      parse_error(
        UnexpectedToken(token=t.kind, expected=expected[:], hint=None),
        t.span,
      )
  }
}

///|
/// The digits of a non-negative integer as a `UInt64`, or `None` for any
/// other text or an overflow (the compiler's `u64::from_str`).
fn parse_u64(digits : String) -> UInt64? {
  guard digits.length() > 0 else { return None }
  let mut n : UInt64 = 0
  for c in digits {
    guard c >= '0' && c <= '9' else { return None }
    let d = (c.to_int() - '0'.to_int()).to_uint64()
    if n > (18446744073709551615UL - d) / 10 {
      return None
    }
    n = n * 10 + d
  }
  Some(n)
}
