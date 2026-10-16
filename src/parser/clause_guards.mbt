///|
/// `if <guard>` after a clause's patterns; `None` without `if`. An empty
/// guard (`if ->`) is the deprecated empty guard.
fn Parser::parse_case_clause_guard(
  self : Parser,
) -> @ast.ClauseGuard? raise ParseError {
  guard self.maybe_one(Keyword(If)) is Some((start, end)) else { return None }
  let result = self.parse_clause_guard_inner()
  if result is None {
    self.warn(DeprecatedEmptyClauseGuard(location=sp(start, end)))
  }
  result
}

///|
fn Parser::parse_clause_guard_inner(
  self : Parser,
) -> @ast.ClauseGuard? raise ParseError {
  let opstack : Array[OpEntry] = []
  let estack : Array[@ast.ClauseGuard] = []
  let mut last_op_start = @span.ByteOffset::zero()
  let mut last_op_end = @span.ByteOffset::zero()
  while true {
    match self.parse_case_clause_guard_unit() {
      Some(unit) => estack.push(unit)
      None =>
        if estack.length() == 0 {
          return None
        } else {
          parse_error(OpNakedRight, sp(last_op_start, last_op_end))
        }
    }
    guard self.token0 is Some(t) else { break }
    guard guard_precedence(t.kind) is Some(prec) else { break }
    self.advance()
    last_op_start = t.span.start
    last_op_end = t.span.end
    ignore(
      handle_operator(
        Some({ token: t, precedence: prec, }),
        opstack,
        estack,
        reduce_clause_guard,
      ),
    )
  }
  handle_operator(None, opstack, estack, reduce_clause_guard)
}

///|
/// After a name in a guard: a `(` means a function call, which guards do
/// not allow (`CallInClauseGuard` over the call when it parses, otherwise
/// `UnexpectedToken` at the `(` with the multi-line hint).
fn Parser::parse_function_call_in_clause_guard(
  self : Parser,
  start : @span.ByteOffset,
) -> Unit raise ParseError {
  if self.maybe_one(LeftParen) is Some((l_paren_start, l_paren_end)) {
    let closed = try {
      let _ = self.parse_fn_arguments()
      Some(self.expect_one(RightParen))
    } catch {
      _ => None
    } noraise {
      v => v
    }
    if closed is Some((_, end)) {
      parse_error(CallInClauseGuard, sp(start, end))
    }
    raise add_multi_line_clause_hint(
      ParseError(
        error=UnexpectedToken(
          token=LeftParen,
          expected=[token_text(RArrow)][:],
          hint=None,
        ),
        location=sp(l_paren_start, l_paren_end),
      ),
    )
  }
}

///|
/// One guard unit: `!unit`, a name with field accesses and tuple indexes,
/// a `{ }` block, or a constant.
fn Parser::parse_case_clause_guard_unit(
  self : Parser,
) -> @ast.ClauseGuard? raise ParseError {
  self.nested(op_clause_guard, () => self.parse_case_clause_guard_unit_inner())
}

///|
fn Parser::parse_case_clause_guard_unit_inner(
  self : Parser,
) -> @ast.ClauseGuard? raise ParseError {
  match self.token0 {
    Some({ kind: Bang, span, .. }) => {
      self.advance()
      match self.parse_case_clause_guard_unit() {
        Some(unit) =>
          Some(
            Not(location=sp(span.start, unit.location().end), expression=unit),
          )
        None => parse_error(ExpectedValue, sp(span.start, span.start))
      }
    }
    Some({ kind: Name(name), span, .. }) => {
      self.advance()
      self.parse_function_call_in_clause_guard(span.start)
      let mut unit : @ast.ClauseGuard = match
        self.parse_record_in_clause_guard(name, span) {
        Some(record) => record
        None => Var(location=span, name~)
      }
      while true {
        guard self.maybe_one(Dot) is Some((dot_s, _)) else { return Some(unit) }
        match self.next_token() {
          Some({ kind: Int(value~, ..), span: int_span, .. }) =>
            match
              parse_u64(value.replace(old="_", new="")).map(
                @ast.TupleIndex::from_uint64,
              ) {
              Some(index) =>
                unit = TupleIndex(
                  location=sp(dot_s, int_span.end),
                  index~,
                  tuple=unit,
                )
              None => parse_error(InvalidTupleAccess, span)
            }
          Some({ kind: Name(label), span: name_span, .. }) => {
            self.parse_function_call_in_clause_guard(span.start)
            unit = FieldAccess(
              label_location=name_span,
              index=None,
              label~,
              container=unit,
            )
          }
          Some({ span: other, .. }) =>
            parse_error(IncorrectName(Variable), other)
          None => self.next_token_unexpected(["A positive integer"])
        }
      }
      Some(unit)
    }
    Some({ kind: LeftBrace, span, .. }) => {
      self.advance()
      Some(self.parse_case_clause_guard_block(span.start))
    }
    _ =>
      match self.parse_const_value_unit() {
        Some(constant) => Some(Constant(constant))
        None => None
      }
  }
}

///|
/// `{ guard }` with `{` consumed; an empty block is `EmptyGuardBlock`.
fn Parser::parse_case_clause_guard_block(
  self : Parser,
  start : @span.ByteOffset,
) -> @ast.ClauseGuard raise ParseError {
  match self.parse_clause_guard_inner() {
    Some(body) => {
      let (_, end) = self.expect_one(RightBrace)
      Block(location=sp(start, end), value=body)
    }
    None => {
      let location = match self.next_token() {
        Some({ kind: RightBrace, span, .. }) => sp(start, span.end)
        _ => sp(start, start.shift(1).unwrap())
      }
      parse_error(EmptyGuardBlock, location)
    }
  }
}

///|
/// `module.Constructor(...)` in a guard: a constant record.
fn Parser::parse_record_in_clause_guard(
  self : Parser,
  module_ : String,
  module_location : @span.SrcSpan,
) -> @ast.ClauseGuard? raise ParseError {
  guard self.token0 is Some({ kind: Dot, .. }) &&
    self.token1 is Some({ kind: UpName(_), .. }) else {
    return None
  }
  self.advance()
  guard self.next_token() is Some({ kind: UpName(name), span, .. }) else {
    return None
  }
  match
    self.parse_const_record_finish(
      module_location.start,
      Some({ location: module_location, name: module_, }),
      name,
      span.end,
    ) {
    Some(record) => Some(Constant(record))
    None => None
  }
}
