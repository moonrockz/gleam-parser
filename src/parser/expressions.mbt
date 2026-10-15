///|
/// Whether an expression unit follows a `|>` (an `echo` there takes no
/// expression).
priv enum UnitContext {
  FollowingPipe
  Other
} derive(Eq)

///|
/// `unit (op unit)*`, reduced by precedence; `None` when `token0` does not
/// start an expression.
fn Parser::parse_expression(self : Parser) -> @ast.Expr? raise ParseError {
  self.parse_expression_inner(false)
}

///|
fn Parser::parse_expression_inner(
  self : Parser,
  is_let_binding : Bool,
) -> @ast.Expr? raise ParseError {
  let opstack : Array[OpEntry] = []
  let estack : Array[@ast.Expr] = []
  let mut last_op_start = 0
  let mut last_op_end = 0
  let mut context = Other
  while true {
    match self.parse_expression_unit(context) {
      Some(unit) => {
        self.post_process_expression_unit(unit, is_let_binding)
        estack.push(unit)
      }
      None =>
        if estack.length() == 0 {
          return None
        } else {
          parse_error(OpNakedRight, sp(last_op_start, last_op_end))
        }
    }
    guard self.token0 is Some(t) else { break }
    guard precedence(t.kind) is Some(prec) else { break }
    context = if t.kind is Pipe { FollowingPipe } else { Other }
    self.advance()
    last_op_start = t.span.start
    last_op_end = t.span.end
    ignore(
      handle_operator(
        Some({ token: t, precedence: prec, }),
        opstack,
        estack,
        reduce_expression,
      ),
    )
  }
  handle_operator(None, opstack, estack, reduce_expression)
}

///|
/// A better error for `[x] = [1]` outside a `let`.
fn Parser::post_process_expression_unit(
  self : Parser,
  unit : @ast.Expr,
  is_let_binding : Bool,
) -> Unit raise ParseError {
  if !is_let_binding && unit is List(..) {
    if self.token0 is Some({ kind: Equal, span, .. }) {
      parse_error(NoLetBinding, span)
    }
  }
}

///|
/// One expression unit: a literal, a name, `todo`, `panic`, `echo`, a tuple,
/// list, bit array, `fn`, block, `case`, `!x` or `-x`, with any field
/// accesses, tuple indexes, calls and record updates that follow it.
fn Parser::parse_expression_unit(
  self : Parser,
  context : UnitContext,
) -> @ast.Expr? raise ParseError {
  self.nested(op_expression, () => self.parse_expression_unit_inner(context))
}

///|
fn Parser::parse_expression_unit_inner(
  self : Parser,
  context : UnitContext,
) -> @ast.Expr? raise ParseError {
  let mut expr : @ast.Expr = match self.token0 {
    Some({ kind: String(value), span, .. }) => {
      self.advance()
      String(location=span, value~)
    }
    Some({ kind: Int(value~, int_value~), span, .. }) => {
      self.advance()
      Int(location=span, value~, int_value~)
    }
    Some({ kind: Float(value~, float_value~), span, .. }) => {
      self.advance()
      Float(location=span, value~, float_value~)
    }
    Some({ kind: Name(name) | UpName(name), span, .. }) => {
      self.advance()
      Var(location=span, name~)
    }
    Some({ kind: Keyword(Todo), span, .. }) => {
      self.advance()
      let message = self.maybe_parse_as_message()
      let end = match message {
        Some(m) => m.location().end
        None => span.end
      }
      Todo(kind=Keyword, location=sp(span.start, end), message~)
    }
    Some({ kind: Keyword(Panic), span, .. }) => {
      self.advance()
      let message = self.maybe_parse_as_message()
      let end = match message {
        Some(m) => m.location().end
        None => span.end
      }
      Panic(location=sp(span.start, end), message~)
    }
    Some({ kind: Keyword(Echo), span, .. }) => {
      self.advance()
      if context == FollowingPipe {
        // `|> echo` takes no expression.
        let message = self.maybe_parse_as_message()
        let end = match message {
          Some(m) => m.location().end
          None => span.end
        }
        Echo(
          location=sp(span.start, end),
          keyword_end=span.end,
          expression=None,
          message~,
        )
      } else {
        // A missing expression is an analysis error in the compiler, not a
        // parse error.
        let expression = self.parse_expression()
        let end = match expression {
          Some(e) => e.location().end
          None => span.end
        }
        let message = self.maybe_parse_as_message()
        let end = match message {
          Some(m) => m.location().end
          None => end
        }
        Echo(
          location=sp(span.start, end),
          keyword_end=span.end,
          expression~,
          message~,
        )
      }
    }
    Some({ kind: Hash, span, .. }) => {
      self.advance()
      let _ = try self.expect_one(LeftParen) catch {
        e => raise add_comment_style_hint(e)
      } noraise {
        v => v
      }
      let elements = self.series_of(p => p.parse_expression(), Some(Comma))
      let (_, end) = self.expect_one_following_series(
        RightParen,
        "an expression",
      )
      Tuple(location=sp(span.start, end), elements=elements[:])
    }
    Some({ kind: LeftSquare, span, .. }) => {
      self.advance()
      self.parse_list(span.start)
    }
    Some({ kind: LtLt, span, .. }) => {
      self.advance()
      let segments = self.series_of(
        p => {
          p.parse_bit_array_segment(
            q => q.parse_expression_unit(Other),
            q => q.expect_expression(),
            bit_array_expression_int,
            x => x.location(),
          )
        },
        Some(Comma),
      )
      let (_, end) = self.expect_one_following_series(
        GtGt,
        "a bit array segment",
      )
      BitArray(location=sp(span.start, end), segments=segments[:])
    }
    Some({ kind: Keyword(Fn), span, .. }) => {
      self.advance()
      match self.parse_function(span.start, false, true, Attributes::new()) {
        Some(Function(f)) => {
          if f.body.length() == 0 {
            parse_error(ExpectedFunctionBody, f.location)
          }
          Fn(
            location=sp(f.location.start, f.end_position),
            end_of_head_byte_index=f.location.end,
            kind=Anonymous(head=f.location),
            arguments=f.arguments,
            body=f.body,
            return_annotation=f.return_annotation,
          )
        }
        _ => self.next_token_unexpected(["An opening parenthesis."])
      }
    }
    Some({ kind: LeftBrace, span, .. }) => {
      self.advance()
      self.parse_block(span.start)
    }
    Some({ kind: Keyword(Case), span, .. }) => {
      self.advance()
      let subjects = self.series_of(p => p.parse_expression(), Some(Comma))
      if self.maybe_one(LeftBrace) is Some(_) {
        let clauses = self.series_of(p => p.parse_case_clause(), None)
        let (_, end) = self.expect_one_following_series(
          RightBrace,
          "a case clause",
        )
        if subjects.length() == 0 {
          parse_error(ExpectedExpr, sp(span.start, span.end))
        }
        Case(
          location=sp(span.start, end),
          subjects=subjects[:],
          clauses=Some(clauses[:]),
        )
      } else {
        let end = match subjects.last() {
          Some(subject) => subject.location().end
          None => span.end
        }
        Case(location=sp(span.start, end), subjects=subjects[:], clauses=None)
      }
    }
    // Helpful errors
    Some({ kind: Keyword(If), span, .. }) => parse_error(IfExpression, span)
    Some({ kind: LeftParen, span, .. }) =>
      parse_error(ExprLparStart, sp(span.start, span.start))
    Some({ kind: Bang, span, .. }) => {
      self.advance()
      match self.parse_expression_unit(Other) {
        Some(value) =>
          NegateBool(location=sp(span.start, value.location().end), value~)
        None => parse_error(ExpectedExpr, sp(span.start, span.start))
      }
    }
    Some({ kind: Minus, span, .. }) => {
      self.advance()
      match self.parse_expression_unit(Other) {
        Some(value) =>
          NegateInt(location=sp(span.start, value.location().end), value~)
        None => parse_error(ExpectedExpr, sp(span.start, span.start))
      }
    }
    _ => return None
  }
  // Field accesses and calls stack up.
  while true {
    match self.maybe_one(Dot) {
      Some((dot_start, _)) => {
        let start = expr.location().start
        match self.token0 {
          // Tuple access
          Some({ kind: Int(value~, ..), span, .. }) => {
            self.advance()
            match parse_u64(value.replace(old="_", new="")) {
              Some(index) =>
                expr = TupleIndex(
                  location=sp(start, span.end),
                  index~,
                  tuple=expr,
                )
              None => parse_error(InvalidTupleAccess, sp(start, span.end))
            }
          }
          Some({ kind: Name(label) | UpName(label), span, .. }) => {
            self.advance()
            expr = FieldAccess(
              location=sp(start, span.end),
              label_location=span,
              label~,
              container=expr,
            )
          }
          // A field access with no label.
          _ => {
            let end = dot_start + 1
            return Some(
              FieldAccess(
                location=sp(start, end),
                label_location=sp(dot_start, end),
                label="",
                container=expr,
              ),
            )
          }
        }
      }
      None =>
        match self.maybe_one(LeftParen) {
          Some((left_paren, _)) => {
            let start = expr.location().start
            match self.maybe_one(DotDot) {
              Some((dot_s, _)) => {
                // Record update
                let base = self.expect_expression()
                let record : @ast.RecordBeingUpdated[@ast.Expr] = {
                  location: sp(dot_s, base.location().end),
                  base,
                }
                let arguments = if self.maybe_one(Comma) is Some(_) {
                  self.series_of(
                    p => p.parse_record_update_argument(),
                    Some(Comma),
                  )
                } else {
                  []
                }
                let (_, end) = self.expect_one(RightParen)
                expr = RecordUpdate(
                  location=sp(start, end),
                  spread_start=dot_s,
                  constructor_=expr,
                  record~,
                  arguments=arguments[:],
                )
              }
              None => {
                // Call
                let arguments = self.parse_fn_arguments()
                if self.maybe_one(DotDot) is Some((dot_dot_start, dot_dot_end)) {
                  let value = try self.parse_const_value() catch {
                    _ => None
                  } noraise {
                    v => v
                  }
                  match value {
                    None =>
                      parse_error(
                        UnexpectedToken(
                          token=DotDot,
                          expected=[token_text(RightParen)][:],
                          hint=None,
                        ),
                        sp(dot_dot_start, dot_dot_end),
                      )
                    Some(value) => {
                      let update_location = sp(
                        dot_dot_start,
                        value.location().end,
                      )
                      let _ = self.expect_one(RightParen)
                      parse_error(RecordUpdateAfterFields, update_location)
                    }
                  }
                }
                let (_, end) = self.expect_one(RightParen)
                expr = make_call(expr, arguments, start, end, left_paren)
              }
            }
          }
          None => break
        }
    }
  }
  Some(expr)
}

///|
/// `[` elements `]` with an optional `..tail` and the compiler's errors for
/// malformed lists. `start` is the `[` position.
fn Parser::parse_list(
  self : Parser,
  start : Int32,
) -> @ast.Expr raise ParseError {
  let (elements, elements_end_with_comma) = self.series_of_has_trailing_separator(
    p => p.parse_expression(),
    Some(Comma),
  )
  let mut tail : @ast.Expr? = None
  let mut elements_after_tail : Array[@ast.Expr]? = None
  let mut dot_dot_location : (Int32, Int32)? = None
  if self.maybe_one(DotDot) is Some((dots_start, dots_end)) {
    dot_dot_location = Some((dots_start, dots_end))
    tail = self.parse_expression()
    if self.maybe_one(Comma) is Some(_) {
      // `[..wibble, wobble, wabble]`
      try self.series_of(p => p.parse_expression(), Some(Comma)) catch {
        _ => ()
      } noraise {
        after => elements_after_tail = Some(after)
      }
    }
    if tail is Some(_) {
      if !elements_end_with_comma {
        self.warn(DeprecatedListPrepend(location=sp(dots_start, dots_end)))
      }
      // `[..wibble, ..wabble, woo]`
      if self.maybe_one(DotDot) is Some((second_start, second_end)) {
        let _ = try self.parse_expression() catch {
          _ => None
        } noraise {
          v => v
        }
        if elements_after_tail is None || elements_after_tail is Some([]) {
          parse_error(
            ListSpreadWithAnotherSpread(
              first_spread_location=sp(dots_start, dots_end),
            ),
            sp(second_start, second_end),
          )
        }
      }
    }
  }
  let (_, end) = self.expect_one(RightSquare)
  if dot_dot_location is Some((s, e)) && tail is None {
    parse_error(ListSpreadWithoutTail, sp(s, e))
  }
  if tail is Some(_) &&
    elements.length() == 0 &&
    (elements_after_tail is None || elements_after_tail is Some([])) {
    parse_error(ListSpreadWithoutElements, sp(start, end))
  }
  if elements_after_tail is Some(after) && after.length() > 0 {
    let (s, e) = match (dot_dot_location, tail) {
      (Some((s, _)), Some(t)) => (s, t.location().end)
      _ => (start, end)
    }
    parse_error(ListSpreadFollowedByElements, sp(s, e))
  }
  List(location=sp(start, end), elements=elements[:], tail~)
}

///|
fn add_comment_style_hint(e : ParseError) -> ParseError {
  match e {
    ParseError(error=UnexpectedToken(token~, expected~, ..), location~) =>
      ParseError(
        error=UnexpectedToken(
          token~,
          expected~,
          hint=Some(
            "Maybe you meant to create a comment?\nComments in Gleam start with `//`, not `#`",
          ),
        ),
        location~,
      )
    other => other
  }
}

///|
fn add_multi_line_clause_hint(e : ParseError) -> ParseError {
  match e {
    ParseError(error=UnexpectedToken(token~, expected~, ..), location~) =>
      ParseError(
        error=UnexpectedToken(
          token~,
          expected~,
          hint=Some("Did you mean to wrap a multi line clause in curly braces?"),
        ),
        location~,
      )
    other => other
  }
}

///|
fn add_anonymous_fn_hint(e : ParseError) -> ParseError {
  match e {
    ParseError(error=UnexpectedToken(token=Name(n), expected~, ..), location~) =>
      ParseError(
        error=UnexpectedToken(
          token=Name(n),
          expected~,
          hint=Some("Only module-level functions can be named."),
        ),
        location~,
      )
    other => other
  }
}

///|
/// `as <unit>` after `todo`, `panic`, `echo`, `assert`.
fn Parser::maybe_parse_as_message(self : Parser) -> @ast.Expr? raise ParseError {
  if self.maybe_one(Keyword(As)) is Some(_) {
    Some(self.expect_expression_unit(Other))
  } else {
    None
  }
}

///|
/// `a: expr` or `a:` (shorthand) in a record update.
fn Parser::parse_record_update_argument(
  self : Parser,
) -> @ast.RecordUpdateArg[@ast.Expr]? raise ParseError {
  match self.maybe_name() {
    Some((start, label, _)) => {
      let (_, end) = self.expect_one(Colon)
      match self.parse_expression() {
        Some(value) =>
          Some({ label, location: sp(start, value.location().end), value, })
        None =>
          Some({
            label,
            location: sp(start, end),
            value: Var(name=label, location=sp(start, end)),
          })
      }
    }
    None => None
  }
}

///|
/// `pattern (, pattern)* (| patterns)* (if guard)? -> expr`.
fn Parser::parse_case_clause(self : Parser) -> @ast.Clause? raise ParseError {
  let patterns = self.parse_patterns()
  guard patterns.length() > 0 else { return None }
  let lead = patterns[0]
  let alternative_patterns : Array[ArrayView[@ast.Pattern]] = []
  while self.maybe_one(Vbar) is Some((vbar_start, vbar_end)) {
    let alternatives = self.parse_patterns()
    if alternatives.length() == 0 {
      parse_error(ExpectedPattern, sp(vbar_start, vbar_end))
    }
    alternative_patterns.push(alternatives[:])
  }
  let guard_ = self.parse_case_clause_guard()
  let (arr_s, arr_e) = try self.expect_one(RArrow) catch {
    e => raise add_multi_line_clause_hint(e)
  } noraise {
    v => v
  }
  match self.parse_expression() {
    Some(then) =>
      Some({
        location: sp(lead.location().start, then.location().end),
        pattern: patterns[:],
        alternative_patterns: alternative_patterns[:],
        guard_,
        then,
      })
    None =>
      match self.token0 {
        Some({ kind: DiscardName(_), span, .. }) =>
          parse_error(IncorrectName(Variable), span)
        _ => parse_error(ExpectedExpr, sp(arr_s, arr_e))
      }
  }
}

///|
fn Parser::expect_expression(self : Parser) -> @ast.Expr raise ParseError {
  match self.parse_expression() {
    Some(e) => e
    None => self.next_token_unexpected(["An expression"])
  }
}

///|
fn Parser::expect_expression_unit(
  self : Parser,
  context : UnitContext,
) -> @ast.Expr raise ParseError {
  match self.parse_expression_unit(context) {
    Some(e) => e
    None => self.next_token_unexpected(["An expression"])
  }
}
