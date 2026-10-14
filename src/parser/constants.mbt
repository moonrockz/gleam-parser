///|
/// A constant value: units joined by binary operators (no pipes).
fn Parser::parse_const_value(self : Parser) -> @ast.Constant? raise ParseError {
  let opstack : Array[OpEntry] = []
  let estack : Array[@ast.Constant] = []
  let mut last_op_start = 0
  let mut last_op_end = 0
  while true {
    match self.parse_const_value_unit() {
      Some(unit) => estack.push(unit)
      None =>
        if estack.length() == 0 {
          return None
        } else {
          parse_error(OpNakedRight, sp(last_op_start, last_op_end))
        }
    }
    guard self.token0 is Some(t) else { break }
    guard precedence(t.kind) is Some(prec) else { break }
    if t.kind is Pipe {
      parse_error(
        UnexpectedToken(
          token=t.kind,
          expected=["<>", "A new definition"][:],
          hint=Some("Pipelines are not allowed in constants"),
        ),
        t.span,
      )
    }
    self.advance()
    last_op_start = t.span.start
    last_op_end = t.span.end
    ignore(
      handle_operator(
        Some({ token: t, precedence: prec, }),
        opstack,
        estack,
        reduce_constant,
      ),
    )
  }
  handle_operator(None, opstack, estack, reduce_constant)
}

///|
fn Parser::parse_const_value_unit(
  self : Parser,
) -> @ast.Constant? raise ParseError {
  self.enter()
  let result = self.parse_const_value_unit_inner()
  self.leave()
  result
}

///|
fn Parser::parse_const_value_unit_inner(
  self : Parser,
) -> @ast.Constant? raise ParseError {
  match self.token0 {
    Some({ kind: Keyword(Todo), span, .. }) => {
      self.advance()
      let message = self.maybe_parse_constant_as_message()
      let end = match message {
        Some(m) => m.location().end
        None => span.end
      }
      Some(Todo(location=sp(span.start, end), message~))
    }
    Some({ kind: String(value), span, .. }) => {
      self.advance()
      Some(String(location=span, value~))
    }
    Some({ kind: Float(value~, float_value~), span, .. }) => {
      self.advance()
      Some(Float(location=span, value~, float_value~))
    }
    Some({ kind: Int(value~, int_value~), span, .. }) => {
      self.advance()
      Some(Int(location=span, value~, int_value~))
    }
    Some({ kind: Hash, span, .. }) => {
      self.advance()
      let _ = self.expect_one(LeftParen)
      let elements = self.series_of(p => p.parse_const_value(), Some(Comma))
      let (_, end) = self.expect_one_following_series(
        RightParen,
        "a constant value",
      )
      Some(Tuple(location=sp(span.start, end), elements=elements[:]))
    }
    Some({ kind: LeftSquare, span, .. }) => {
      self.advance()
      let start = span.start
      let (elements, elements_end_with_comma) = self.series_of_has_trailing_separator(
        p => p.parse_const_value(),
        Some(Comma),
      )
      let mut tail : @ast.Constant? = None
      let mut elements_after_tail : Array[@ast.Constant]? = None
      let mut dot_dot_location : (Int32, Int32)? = None
      // With no elements a tail is still parsed, for a better error.
      if elements_end_with_comma || elements.length() == 0 {
        if self.maybe_one(DotDot) is Some((dots_start, dots_end)) {
          dot_dot_location = Some((dots_start, dots_end))
          tail = self.parse_const_value()
          if self.maybe_one(Comma) is Some(_) {
            try self.series_of(p => p.parse_const_value(), Some(Comma)) catch {
              _ => ()
            } noraise {
              after => elements_after_tail = Some(after)
            }
          }
          if tail is Some(_) {
            // `[..wibble, ..wabble, woo]`
            if self.maybe_one(DotDot) is Some((second_start, second_end)) {
              let _ = try self.parse_const_value() catch {
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
      }
      let (_, end) = self.expect_one_following_series(
        RightSquare,
        "a constant value",
      )
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
      Some(List(location=sp(start, end), elements=elements[:], tail~))
    }
    Some({ kind: LtLt, span, .. }) => {
      self.advance()
      let segments = self.series_of(
        p => {
          p.parse_bit_array_segment(
            q => q.parse_const_value(),
            q => q.expect_const_int(),
            bit_array_const_int,
            x => x.location(),
          )
        },
        Some(Comma),
      )
      let (_, end) = self.expect_one_following_series(
        GtGt,
        "a bit array segment",
      )
      Some(BitArray(location=sp(span.start, end), segments=segments[:]))
    }
    Some({ kind: UpName(name), span, .. }) => {
      self.advance()
      self.parse_const_record_finish(span.start, None, name, span.end)
    }
    Some({ kind: Name(name), span, .. }) if self.peek_token1() is Some(Dot) => {
      self.advance()
      self.advance()
      match self.token0 {
        Some({ kind: UpName(upname), span: up, .. }) => {
          self.advance()
          self.parse_const_record_finish(
            span.start,
            Some({ location: span, name, }),
            upname,
            up.end,
          )
        }
        Some({ kind: Name(end_name), span: name_span, .. }) => {
          self.advance()
          match self.token0 {
            Some({ kind: LeftParen, span: paren, .. }) => {
              self.advance()
              self.function_call_in_constant(span.start, paren.end)
            }
            _ =>
              Some(
                Var(
                  location=sp(span.start, name_span.end),
                  module_=Some({ location: span, name, }),
                  name=end_name,
                ),
              )
          }
        }
        Some(t) =>
          parse_error(
            UnexpectedToken(
              token=t.kind,
              expected=["A lowercase name", "An uppercase name"][:],
              hint=None,
            ),
            t.span,
          )
        None => parse_error(UnexpectedEof, sp(0, 0))
      }
    }
    Some({ kind: Name(name), span, .. }) => {
      self.advance()
      match self.token0 {
        Some({ kind: LeftParen, span: paren, .. }) => {
          self.advance()
          self.function_call_in_constant(span.start, paren.end)
        }
        _ => Some(Var(location=span, module_=None, name~))
      }
    }
    // Helpful error for fn
    Some({ kind: Keyword(Fn), span, .. }) => parse_error(NotConstType, span)
    _ => None
  }
}

///|
/// `as <constant unit>` after `todo`; `MissingConstantAsMessage` at `as`
/// when nothing follows.
fn Parser::maybe_parse_constant_as_message(
  self : Parser,
) -> @ast.Constant? raise ParseError {
  match self.maybe_one(Keyword(As)) {
    Some((as_start, as_end)) =>
      match self.parse_const_value_unit() {
        Some(constant) => Some(constant)
        None => parse_error(MissingConstantAsMessage, sp(as_start, as_end))
      }
    None => None
  }
}

///|
/// The `( .. )` of a constant record: a record update, record arguments,
/// or a bare constructor.
fn Parser::parse_const_record_finish(
  self : Parser,
  start : Int32,
  module_ : @ast.SpannedString?,
  name : String,
  end : Int32,
) -> @ast.Constant? raise ParseError {
  match self.maybe_one(LeftParen) {
    Some((par_s, _)) =>
      if self.maybe_one(DotDot) is Some((dot_dot_start, _)) {
        let record : @ast.RecordBeingUpdated[@ast.Constant] = match
          self.parse_const_value() {
          Some(value) =>
            { location: sp(dot_dot_start, value.location().end), base: value, }
          None => parse_error(UnexpectedEof, sp(par_s, par_s + 2))
        }
        let update_arguments = if self.maybe_one(Comma) is Some(_) {
          self.series_of(
            p => p.parse_const_record_update_argument(),
            Some(Comma),
          )
        } else {
          []
        }
        let (_, par_e) = self.expect_one_following_series(
          RightParen,
          "a constant record update argument",
        )
        Some(
          RecordUpdate(
            location=sp(start, par_e),
            constructor_location=sp(start, end),
            module_~,
            name~,
            record~,
            arguments=update_arguments[:],
          ),
        )
      } else {
        let arguments = self.series_of(
          p => p.parse_const_record_argument(),
          Some(Comma),
        )
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
              let update_location = sp(dot_dot_start, value.location().end)
              let _ = self.expect_one_following_series(
                RightParen,
                "a constant record argument",
              )
              parse_error(RecordUpdateAfterFields, update_location)
            }
          }
        }
        let (_, par_e) = self.expect_one_following_series(
          RightParen,
          "a constant record argument",
        )
        Some(
          Record(
            location=sp(start, par_e),
            arguments_start_position=end,
            module_~,
            name~,
            arguments=Some(arguments[:]),
          ),
        )
      }
    None =>
      Some(
        Record(
          location=sp(start, end),
          arguments_start_position=end,
          module_~,
          name~,
          arguments=None,
        ),
      )
  }
}

///|
/// `name: const`, `const` or `name:` (label shorthand).
fn Parser::parse_const_record_argument(
  self : Parser,
) -> @ast.CallArg[@ast.Constant]? raise ParseError {
  let label : (Int32, String, Int32)? = match (self.token0, self.token1) {
    (
      Some({ kind: Name(name), span, .. }),
      Some({ kind: Colon, span: colon, .. }),
    ) => {
      self.advance()
      self.advance()
      Some((span.start, name, colon.end))
    }
    _ => None
  }
  match self.parse_const_value() {
    Some(value) =>
      match label {
        Some((start, label, _)) =>
          Some({
            implicit: None,
            location: sp(start, value.location().end),
            value,
            label: Some(label),
          })
        None =>
          Some({
            implicit: None,
            location: value.location(),
            value,
            label: None,
          })
      }
    None =>
      match label {
        Some((start, label, end)) =>
          Some({
            implicit: None,
            location: sp(start, end),
            label: Some(label),
            value: Var(location=sp(start, end), module_=None, name=label),
          })
        None => None
      }
  }
}

///|
/// `name: const` or `name` (shorthand) in a constant record update; a
/// label is required.
fn Parser::parse_const_record_update_argument(
  self : Parser,
) -> @ast.RecordUpdateArg[@ast.Constant]? raise ParseError {
  let (start, label, label_end) = match (self.token0, self.token1) {
    (
      Some({ kind: Name(name), span, .. }),
      Some({ kind: Colon, span: colon, .. }),
    ) => {
      self.advance()
      self.advance()
      (span.start, name, colon.end)
    }
    (Some({ kind: Name(name), span, .. }), _) => {
      // Label shorthand without a colon: the name is both label and value.
      let value = self.parse_const_value()
      match value {
        Some(v) if v.location() == span =>
          return Some({ label: name, location: span, value: v, })
        _ => parse_error(ExpectedName, span)
      }
    }
    _ => return None
  }
  match self.parse_const_value() {
    Some(value) =>
      Some({ label, location: sp(start, value.location().end), value, })
    None =>
      Some({
        label,
        location: sp(start, label_end),
        value: Var(location=sp(start, label_end), module_=None, name=label),
      })
  }
}

///|
fn Parser::expect_const_int(self : Parser) -> @ast.Constant raise ParseError {
  match self.token0 {
    Some({ kind: Int(value~, int_value~), span, .. }) => {
      self.advance()
      Int(location=span, value~, int_value~)
    }
    _ => self.next_token_unexpected(["An int"])
  }
}

///|
/// After `name(` in a constant or a guard: scan to the matching `)` and
/// report `UnexpectedFunction` over the call.
fn Parser::function_call_in_constant(
  self : Parser,
  start : Int32,
  start_paren : Int32,
) -> @ast.Constant? raise ParseError {
  let mut depth = 1
  let mut end = start_paren
  while true {
    match self.next_token() {
      Some({ kind: LeftParen, .. }) => depth += 1
      Some({ kind: RightParen, span, .. }) =>
        if depth == 1 {
          end = span.end
          break
        } else {
          depth -= 1
        }
      Some(_) => ()
      None => break
    }
  }
  parse_error(UnexpectedFunction, sp(start, end))
}
