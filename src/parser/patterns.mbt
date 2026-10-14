///|
/// The left side of `=` or `->`. `None` when `token0` does not start a
/// pattern.
fn Parser::parse_pattern(self : Parser) -> @ast.Pattern? raise ParseError {
  self.enter()
  let result = self.parse_pattern_inner()
  self.leave()
  result
}

///|
fn Parser::parse_pattern_inner(self : Parser) -> @ast.Pattern? raise ParseError {
  let pattern : @ast.Pattern = match self.token0 {
    // Variable, or a module-qualified constructor
    Some({ kind: Name(name), span, .. }) => {
      self.advance()
      // A variable is not permitted on the left hand side of a `<>`
      if self.token0 is Some({ kind: Concatenate, .. }) {
        parse_error(ConcatPatternVariableLeftHandSide, span)
      }
      if self.maybe_one(Dot) is Some(_) {
        // A better message than "expecting a type" for `name.thing`
        // (gleam-lang/gleam#2841).
        try
          self.expect_constructor_pattern(Some((span.start, name, span.end)))
        catch {
          ParseError(location~, ..) =>
            parse_error(InvalidModuleTypePattern, sp(span.start, location.end))
        } noraise {
          result => result
        }
      } else {
        Variable(location=span, name~)
      }
    }
    // Constructor
    Some({ kind: UpName(_), .. }) => self.expect_constructor_pattern(None)
    Some({ kind: DiscardName(name), span, .. }) => {
      self.advance()
      if self.token0 is Some({ kind: Concatenate, .. }) {
        parse_error(ConcatPatternVariableLeftHandSide, span)
      }
      Discard(location=span, name~)
    }
    Some({ kind: String(value), span, .. }) => {
      self.advance()
      match self.token0 {
        // `"Hello, " as greeting <> name` or `"Hello, World!" as greeting`
        Some({ kind: Keyword(As), .. }) => {
          self.advance()
          let (name_start, name, name_end) = self.expect_name(AsPattern)
          match self.token0 {
            Some({ kind: Concatenate, .. }) => {
              self.advance()
              let (r_start, right, r_end) = self.expect_assign_name()
              self.reject_suffix_literal(right)
              StringPrefix(
                location=sp(span.start, r_end),
                left_location=sp(span.start, name_end),
                right_location=sp(r_start, r_end),
                left_side_string=value,
                left_side_assignment=Some({
                  name,
                  name_start_position: name_start,
                  location: sp(span.end, name_end),
                }),
                right_side_assignment=right,
              )
            }
            _ =>
              return Some(
                Assign(
                  name~,
                  location=sp(name_start, name_end),
                  pattern=String(location=span, value~),
                ),
              )
          }
        }
        // `"Hello, " <> name`
        Some({ kind: Concatenate, .. }) => {
          self.advance()
          let (r_start, right, r_end) = self.expect_assign_name()
          self.reject_suffix_literal(right)
          StringPrefix(
            location=sp(span.start, r_end),
            left_location=span,
            right_location=sp(r_start, r_end),
            left_side_string=value,
            left_side_assignment=None,
            right_side_assignment=right,
          )
        }
        _ => String(location=span, value~)
      }
    }
    Some({ kind: Int(value~, int_value~), span, .. }) => {
      self.advance()
      Int(location=span, value~, int_value~)
    }
    Some({ kind: Float(value~, float_value~), span, .. }) => {
      self.advance()
      Float(location=span, value~, float_value~)
    }
    Some({ kind: Hash, span, .. }) => {
      self.advance()
      let _ = self.expect_one(LeftParen)
      let elements = self.series_of(p => p.parse_pattern(), Some(Comma))
      let (_, end) = self.expect_one_following_series(RightParen, "a pattern")
      Tuple(location=sp(span.start, end), elements=elements[:])
    }
    // Bit array
    Some({ kind: LtLt, span, .. }) => {
      self.advance()
      let segments = self.series_of(
        p => {
          p.parse_bit_array_segment(
            q => {
              match q.parse_pattern() {
                Some(BitArray(location~, ..)) =>
                  parse_error(NestedBitArrayPattern, location)
                x => x
              }
            },
            q => q.expect_bit_array_pattern_segment_argument(),
            bit_array_size_int,
            x => x.location(),
          )
        },
        Some(Comma),
      )
      let (_, end) = self.expect_one_following_series(
        GtGt,
        "a bit array segment pattern",
      )
      BitArray(location=sp(span.start, end), segments=segments[:])
    }
    // List
    Some({ kind: LeftSquare, span, .. }) => {
      self.advance()
      let start = span.start
      let (elements, elements_end_with_comma) = self.series_of_has_trailing_separator(
        p => p.parse_pattern(),
        Some(Comma),
      )
      let mut elements_after_tail : Array[@ast.Pattern]? = None
      let mut dot_dot_location : (Int32, Int32)? = None
      // `Some(Some(p))`: a tail with a pattern; `Some(None)`: `..` alone.
      let tail : @ast.Pattern?? = match self.token0 {
        Some({ kind: DotDot, span: dots, .. }) => {
          dot_dot_location = Some((dots.start, dots.end))
          if elements.length() > 0 && !elements_end_with_comma {
            self.warn(DeprecatedListPattern(location=dots))
          }
          self.advance()
          let tail = self.parse_pattern()
          if self.maybe_one(Comma) is Some(_) {
            // `[..wibble, wobble, wabble]`
            try self.series_of(p => p.parse_pattern(), Some(Comma)) catch {
              _ => ()
            } noraise {
              after => elements_after_tail = Some(after)
            }
          }
          Some(tail)
        }
        _ => None
      }
      let (end, closing_square_bracket_end) = self.expect_one_following_series(
        RightSquare,
        "a pattern",
      )
      if elements_after_tail is Some(after) && after.length() > 0 {
        let (s, e) = match (dot_dot_location, tail) {
          (Some((s, _)), Some(Some(t))) => (s, t.location().end)
          (Some((s, e)), Some(None)) => (s, e)
          _ => (start, end)
        }
        parse_error(ListPatternSpreadFollowedByElements, sp(s, e))
      }
      let tail : @ast.Pattern? = match tail {
        Some(Some(p)) if p is Variable(..) || p is Discard(..) => Some(p)
        Some(Some(p)) => parse_error(InvalidTailPattern, p.location())
        Some(None) =>
          Some(
            Discard(
              location=sp(
                closing_square_bracket_end - 1,
                closing_square_bracket_end,
              ),
              name="_",
            ),
          )
        None => None
      }
      if elements.length() == 0 {
        let location = sp(start, closing_square_bracket_end)
        match tail {
          Some(Discard(..)) =>
            self.warn(DeprecatedListCatchAllPattern(location~))
          Some(Variable(name~, ..)) =>
            self.warn(DeprecatedListSpreadAsVariablePattern(location~, name~))
          _ => ()
        }
      }
      List(
        location=sp(start, closing_square_bracket_end),
        elements=elements[:],
        tail=tail.map(pattern => {
          let dot_dot_start = match dot_dot_location {
            Some((s, _)) => s
            None => start
          }
          @ast.TailPattern::{
            location: sp(dot_dot_start, pattern.location().end),
            pattern,
          }
        }),
      )
    }
    _ => return None
  }
  match self.token0 {
    Some({ kind: Keyword(As), .. }) => {
      self.advance()
      let (start, name, end) = self.expect_name(AsPattern)
      Some(Assign(name~, location=sp(start, end), pattern~))
    }
    _ => Some(pattern)
  }
}

///|
/// A second `<>` after the right side of a string prefix would match on a
/// suffix literal: `ConcatPatternVariableWithSuffix` over it.
fn Parser::reject_suffix_literal(
  self : Parser,
  right : @ast.AssignName,
) -> Unit raise ParseError {
  if self.token0 is Some({ kind: Concatenate, span: second, .. }) {
    let suffix_end = match self.token1 {
      Some({ kind: String(_), span, .. }) => span.end
      _ => second.end
    }
    let name = match right {
      Variable(n) | Discard(n) => n
    }
    parse_error(
      ConcatPatternVariableWithSuffix(name~),
      sp(second.start, suffix_end),
    )
  }
}

///|
/// `UpName( args )`, with an optional module prefix already consumed.
fn Parser::expect_constructor_pattern(
  self : Parser,
  module_ : (Int32, String, Int32)?,
) -> @ast.Pattern raise ParseError {
  let (name_start, name, name_end) = self.expect_upname()
  let (arguments, spread, end) = self.parse_constructor_pattern_arguments(
    name_end,
  )
  let start = match module_ {
    Some((s, _, _)) => s
    None => name_start
  }
  Constructor(
    location=sp(start, end),
    name_location=sp(name_start, name_end),
    name~,
    arguments=arguments[:],
    module_=module_.map(m => @ast.SpannedString::{
      location: sp(m.0, m.2),
      name: m.1,
    }),
    spread~,
  )
}

///|
/// `( args )` of a constructor pattern: arguments, spread span and end.
fn Parser::parse_constructor_pattern_arguments(
  self : Parser,
  upname_end : Int32,
) -> (Array[@ast.CallArg[@ast.Pattern]], @span.SrcSpan?, Int32) raise ParseError {
  if self.maybe_one(LeftParen) is Some(_) {
    let (arguments, arguments_end_with_comma) = self.series_of_has_trailing_separator(
      p => p.parse_constructor_pattern_argument(),
      Some(Comma),
    )
    let spread = self.maybe_one(DotDot).map(s => sp(s.0, s.1))
    if spread is Some(spread_location) {
      let _ = self.maybe_one(Comma)
      if arguments.length() > 0 && !arguments_end_with_comma {
        self.warn(DeprecatedRecordSpreadPattern(location=spread_location))
      }
    }
    let (_, end) = self.expect_one(RightParen)
    (arguments, spread, end)
  } else {
    ([], None, upname_end)
  }
}

///|
/// `a: <pattern>`, `a:` (label shorthand) or `<pattern>`.
fn Parser::parse_constructor_pattern_argument(
  self : Parser,
) -> @ast.CallArg[@ast.Pattern]? raise ParseError {
  match (self.token0, self.token1) {
    (
      Some({ kind: Name(name), span, .. }),
      Some({ kind: Colon, span: colon, .. }),
    ) => {
      self.advance()
      self.advance()
      match self.parse_pattern() {
        Some(value) =>
          Some({
            implicit: None,
            location: sp(span.start, value.location().end),
            label: Some(name),
            value,
          })
        None =>
          Some({
            implicit: None,
            location: sp(span.start, colon.end),
            label: Some(name),
            value: Variable(name~, location=sp(span.start, colon.end)),
          })
      }
    }
    _ =>
      match self.parse_pattern() {
        Some(value) =>
          Some({
            implicit: None,
            location: value.location(),
            label: None,
            value,
          })
        None => None
      }
  }
}

///|
fn Parser::parse_patterns(
  self : Parser,
) -> Array[@ast.Pattern] raise ParseError {
  self.series_of(p => p.parse_pattern(), Some(Comma))
}
