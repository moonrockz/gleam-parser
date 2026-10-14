///|
/// `use a, b <- call`, with `use` consumed.
fn Parser::parse_use(
  self : Parser,
  start : Int32,
  end : Int32,
) -> @ast.Statement raise ParseError {
  let assignments : Array[@ast.UseAssignment] = if self.token0
    is Some({ kind: LArrow, .. }) {
    []
  } else {
    self.series_of(p => p.parse_use_assignment(), Some(Comma))
  }
  let _ = self.expect_one_following_series(LArrow, "a use variable assignment")
  let call = self.expect_expression()
  let assignments_location = if assignments.length() > 0 {
    sp(
      assignments[0].location.start,
      assignments[assignments.length() - 1].location.end,
    )
  } else {
    sp(start, end)
  }
  Use({
    location: sp(start, call.location().end),
    assignments_location,
    right_hand_side_location: call.location(),
    assignments: assignments[:],
    call,
  })
}

///|
fn Parser::parse_use_assignment(
  self : Parser,
) -> @ast.UseAssignment? raise ParseError {
  let start = match self.token0 {
    Some(t) => t.span.start
    None => 0
  }
  let pattern = match self.parse_pattern() {
    Some(p) => p
    None => parse_error(ExpectedPattern, sp(start, start))
  }
  let annotation = self.parse_type_annotation(Colon)
  let end = match annotation {
    Some(a) => a.location().end
    None => pattern.location().end
  }
  Some({ location: sp(start, end), pattern, annotation, })
}

///|
/// `let` (`assert`)? pattern (`: T`)? `=` expr (`as` unit)?, with `let`
/// consumed.
fn Parser::parse_assignment(
  self : Parser,
  start : Int32,
) -> @ast.Statement raise ParseError {
  let mut kind : @ast.AssignmentKind = match self.token0 {
    Some({ kind: Keyword(Assert), span, .. }) => {
      self.advance()
      Assert(
        location=sp(start, span.end),
        assert_keyword_start=span.start,
        message=None,
      )
    }
    _ => Let
  }
  let pattern = match self.parse_pattern() {
    Some(p) => p
    None => self.next_token_unexpected(["A pattern"])
  }
  let annotation = self.parse_type_annotation(Colon)
  let (eq_s, eq_e) = match self.maybe_one(Equal) {
    Some(r) => r
    None => parse_error(ExpectedEqual, pattern.location())
  }
  let value = match self.parse_expression_inner(true) {
    Some(v) => v
    None =>
      match self.token0 {
        Some({ kind: DiscardName(_), span, .. }) =>
          parse_error(IncorrectName(Variable), span)
        _ => parse_error(ExpectedValue, sp(eq_s, eq_e))
      }
  }
  let mut end = value.location().end
  if kind is Assert(location~, assert_keyword_start~, ..) {
    if self.maybe_one(Keyword(As)) is Some(_) {
      let message = self.expect_expression_unit(Other)
      end = message.location().end
      kind = Assert(location~, assert_keyword_start~, message=Some(message))
    }
  }
  Assignment({ location: sp(start, end), value, pattern, kind, annotation, })
}

///|
/// `assert expr (as unit)?`, with `assert` consumed.
fn Parser::parse_assert(
  self : Parser,
  start : Int32,
) -> @ast.Statement raise ParseError {
  let value = self.expect_expression()
  let mut end = value.location().end
  let message = if self.maybe_one(Keyword(As)) is Some(_) {
    let m = self.expect_expression_unit(Other)
    end = m.location().end
    Some(m)
  } else {
    None
  }
  Assert({ location: sp(start, end), value, message, })
}

///|
/// One or more statements; `None` when there is none. Also the end of the
/// last one.
fn Parser::parse_statement_sequence(
  self : Parser,
) -> (Array[@ast.Statement], Int32)? raise ParseError {
  let statements : Array[@ast.Statement] = []
  let mut end = 0
  while self.parse_statement() is Some(statement) {
    end = statement.location().end
    statements.push(statement)
  }
  if statements.length() == 0 {
    None
  } else {
    Some((statements, end))
  }
}

///|
fn Parser::parse_statement(self : Parser) -> @ast.Statement? raise ParseError {
  match self.token0 {
    Some({ kind: Keyword(Use), span, .. }) => {
      self.advance()
      Some(self.parse_use(span.start, span.end))
    }
    Some({ kind: Keyword(Let), span, .. }) => {
      self.advance()
      Some(self.parse_assignment(span.start))
    }
    Some({ kind: Keyword(Assert), span, .. }) => {
      self.advance()
      Some(self.parse_assert(span.start))
    }
    // A constant inside a function
    Some({ kind: Keyword(Const), span, .. }) =>
      parse_error(ConstantInsideFunction, span)
    _ => {
      self.parse_statement_errors()
      self.parse_expression().map(e => @ast.Statement::Expression(e))
    }
  }
}

///|
/// A name followed by `=` or `:` needs `let`.
fn Parser::parse_statement_errors(self : Parser) -> Unit raise ParseError {
  if self.token0 is Some({ kind: Name(_), .. }) {
    if self.token1 is Some({ kind: Equal | Colon, span, .. }) {
      parse_error(NoLetBinding, span)
    }
  }
}

///|
/// `{ statements }` with `{` consumed; an empty block is a `Todo`.
fn Parser::parse_block(
  self : Parser,
  start : Int32,
) -> @ast.Expr raise ParseError {
  let body = self.parse_statement_sequence()
  let (_, end) = self.expect_one(RightBrace)
  let location = sp(start, end)
  let statements : Array[@ast.Statement] = match body {
    Some((statements, _)) => statements
    None => [Expression(Todo(kind=EmptyBlock, location~, message=None))]
  }
  Block(location~, statements=statements[:])
}
