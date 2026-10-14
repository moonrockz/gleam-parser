///|
/// `start_tok` then a type (`: T`, `-> T`); `ExpectedType` at `start_tok`
/// when the type is missing; `None` without `start_tok`.
fn Parser::parse_type_annotation(
  self : Parser,
  start_tok : @scanner.TokenKind,
) -> @ast.TypeAst? raise ParseError {
  match self.maybe_one(start_tok) {
    Some((start, end)) =>
      match self.parse_type() {
        None => parse_error(ExpectedType, sp(start, end))
        some => some
      }
    None => None
  }
}

///|
/// A type annotation without its `:`; `None` when `token0` does not start
/// one.
fn Parser::parse_type(self : Parser) -> @ast.TypeAst? raise ParseError {
  self.enter()
  let result = self.parse_type_inner()
  self.leave()
  result
}

///|
fn Parser::parse_type_inner(self : Parser) -> @ast.TypeAst? raise ParseError {
  match self.token0 {
    // Type hole
    Some({ kind: DiscardName(name), span, .. }) => {
      self.advance()
      Some(Hole({ location: span, name, }))
    }
    // Tuple
    Some({ kind: Hash, span, .. }) => {
      self.advance()
      let _ = self.expect_one(LeftParen)
      let elements = self.parse_types()
      let (_, end) = self.expect_one(RightParen)
      Some(Tuple({ location: sp(span.start, end), elements: elements[:], }))
    }
    // Function
    Some({ kind: Keyword(Fn), span, .. }) => {
      self.advance()
      let _ = self.expect_one(LeftParen)
      let arguments = self.series_of(p => p.parse_type(), Some(Comma))
      let _ = self.expect_one_following_series(RightParen, "a type")
      let (arr_s, arr_e) = self.expect_one(RArrow)
      match self.parse_type() {
        Some(return_) =>
          Some(
            @ast.TypeAst::Fn({
              location: sp(span.start, return_.location().end),
              arguments: arguments[:],
              return_,
            }),
          )
        None => parse_error(ExpectedType, sp(arr_s, arr_e))
      }
    }
    // Constructor
    Some({ kind: UpName(name), span, .. }) => {
      self.advance()
      self.parse_type_name_finish(
        span.start,
        span.end,
        Unqualified(name~, location=span),
      )
    }
    // Constructor module, or type variable
    Some({ kind: Name(module_), span, .. }) => {
      self.advance()
      match self.maybe_one(Dot) {
        Some((_, dot_end)) =>
          match self.maybe_upname() {
            Some((name_start, name, name_end)) =>
              self.parse_type_name_finish(
                span.start,
                name_end,
                Qualified(
                  module_~,
                  module_location=span,
                  dot_location=dot_end,
                  name=Some({ location: sp(name_start, name_end), name, }),
                ),
              )
            None =>
              self.parse_type_name_finish(
                span.start,
                dot_end,
                Qualified(
                  module_~,
                  module_location=span,
                  dot_location=dot_end,
                  name=None,
                ),
              )
          }
        None => Some(Var({ location: span, name: module_, }))
      }
    }
    _ => None
  }
}

///|
/// The `( ... )` of a type name, or the angle-bracket error.
fn Parser::parse_type_name_finish(
  self : Parser,
  start : Int32,
  end : Int32,
  name : @ast.TypeAstConstructorName,
) -> @ast.TypeAst? raise ParseError {
  match self.maybe_one(LeftParen) {
    Some((left_paren_start, left_paren_end)) => {
      // `wibble.(a, b)`: the `(` is unexpected, a type name was expected.
      if name is Qualified(name=None, ..) {
        parse_error(ExpectedUpName, sp(left_paren_start, left_paren_end))
      }
      let arguments = self.parse_types()
      let (_, right_paren_end) = self.expect_one(RightParen)
      Some(
        Constructor({
          location: sp(start, right_paren_end),
          name,
          arguments: arguments[:],
          start_parentheses: Some(left_paren_start),
        }),
      )
    }
    None =>
      match self.maybe_one(Less) {
        Some((less_start, less_end)) => {
          let location = sp(less_start, less_end)
          let (module_, type_name) = match name {
            Qualified(module_~, name=Some(n), ..) => (Some(module_), n.name)
            Unqualified(name~, ..) => (None, name)
            // `wibble.<`: the hint about angle brackets makes no sense.
            Qualified(name=None, ..) => parse_error(ExpectedUpName, location)
          }
          let arguments = self.parse_types()
          parse_error(
            TypeUsageAngleGenerics(
              module_~,
              name=type_name,
              arguments=arguments[:],
            ),
            location,
          )
        }
        None =>
          Some(
            Constructor({
              location: sp(start, end),
              name,
              arguments: [][:],
              start_parentheses: None,
            }),
          )
      }
  }
}

///|
/// Comma-separated types, for tuples, constructors and functions.
fn Parser::parse_types(self : Parser) -> Array[@ast.TypeAst] raise ParseError {
  self.series_of(p => p.parse_type(), Some(Comma))
}
