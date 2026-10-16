///|
/// A bit array segment: `value` then `:` options separated by `-`. The same
/// shape serves patterns, constants and expressions, so the value parser,
/// the argument parser (for `size(...)`), the `Int` builder and the
/// location reader are parameters.
fn[A] Parser::parse_bit_array_segment(
  self : Parser,
  value_parser : (Parser) -> A? raise ParseError,
  arg_parser : (Parser) -> A raise ParseError,
  to_int_segment : (String, BigInt, @span.ByteOffset, @span.ByteOffset) -> A,
  location_of : (A) -> @span.SrcSpan,
) -> @ast.BitArraySegment[A]? raise ParseError {
  match value_parser(self) {
    Some(value) => {
      let options : Array[@ast.BitArrayOption[A]] = if self.maybe_one(Colon)
        is Some(_) {
        self.series_of(
          p => p.parse_bit_array_option(arg_parser, to_int_segment),
          Some(Minus),
        )
      } else {
        []
      }
      let end = match options.last() {
        Some(option) => bit_array_option_location(option).end
        None => location_of(value).end
      }
      Some({
        location: sp(location_of(value).start, end),
        value,
        options: options[:],
      })
    }
    None => None
  }
}

///|
fn[A] bit_array_option_location(
  option : @ast.BitArrayOption[A],
) -> @span.SrcSpan {
  match option {
    Bytes(location~)
    | Int(location~)
    | Float(location~)
    | Bits(location~)
    | Utf8(location~)
    | Utf16(location~)
    | Utf32(location~)
    | Utf8Codepoint(location~)
    | Utf16Codepoint(location~)
    | Utf32Codepoint(location~)
    | Signed(location~)
    | Unsigned(location~)
    | Big(location~)
    | Little(location~)
    | Native(location~)
    | Size(location~, ..)
    | Unit(location~, ..) => location
  }
}

///|
/// One option: `utf8`, `size(x)`, `unit(2)` or a bare int (`size` in short
/// form).
fn[A] Parser::parse_bit_array_option(
  self : Parser,
  arg_parser : (Parser) -> A raise ParseError,
  to_int_segment : (String, BigInt, @span.ByteOffset, @span.ByteOffset) -> A,
) -> @ast.BitArrayOption[A]? raise ParseError {
  match self.token0 {
    Some({ kind: Name(name), span, .. }) => {
      self.advance()
      if self.maybe_one(LeftParen) is Some(_) {
        match name {
          "unit" =>
            match self.token0 {
              Some({ kind: Int(value~, ..), span: int_span, .. }) => {
                self.advance()
                let (_, end) = self.expect_one(RightParen)
                match parse_unit(value) {
                  Some(units) =>
                    Some(Unit(location=sp(span.start, end), value=units))
                  None => parse_error(InvalidBitArrayUnit, int_span)
                }
              }
              _ => self.next_token_unexpected(["A positive int"])
            }
          "size" => {
            let value = arg_parser(self)
            let (_, end) = self.expect_one(RightParen)
            Some(Size(location=sp(span.start, end), value~, short_form=false))
          }
          _ => parse_error(InvalidBitArraySegment, span)
        }
      } else {
        match str_to_bit_array_option(name, span) {
          Some(option) => Some(option)
          None => parse_error(InvalidBitArraySegment, span)
        }
      }
    }
    Some({ kind: Int(value~, int_value~), span, .. }) => {
      self.advance()
      Some(
        Size(
          location=span,
          value=to_int_segment(value, int_value, span.start, span.end),
          short_form=true,
        ),
      )
    }
    _ =>
      self.next_token_unexpected([
        "A valid bit array segment type", "See: https://tour.gleam.run/data-types/bit-arrays/",
      ])
  }
}

///|
/// The compiler's `u8::from_str(value.replace("_", ""))` filtered to `> 0`:
/// decimal digits only, 1 to 255.
fn parse_unit(value : String) -> @ast.BitArrayUnit? {
  let digits = value.replace(old="_", new="")
  match parse_u64(digits) {
    Some(n) if n >= 1UL && n <= 255UL => @ast.BitArrayUnit::from_int(n.to_int())
    _ => None
  }
}

///|
fn[A] str_to_bit_array_option(
  name : String,
  location : @span.SrcSpan,
) -> @ast.BitArrayOption[A]? {
  match name {
    "bytes" => Some(Bytes(location~))
    "int" => Some(Int(location~))
    "float" => Some(Float(location~))
    "bits" => Some(Bits(location~))
    "utf8" => Some(Utf8(location~))
    "utf16" => Some(Utf16(location~))
    "utf32" => Some(Utf32(location~))
    "utf8_codepoint" => Some(Utf8Codepoint(location~))
    "utf16_codepoint" => Some(Utf16Codepoint(location~))
    "utf32_codepoint" => Some(Utf32Codepoint(location~))
    "signed" => Some(Signed(location~))
    "unsigned" => Some(Unsigned(location~))
    "big" => Some(Big(location~))
    "little" => Some(Little(location~))
    "native" => Some(Native(location~))
    _ => None
  }
}

///|
fn Parser::expect_bit_array_pattern_segment_argument(
  self : Parser,
) -> @ast.Pattern raise ParseError {
  BitArraySize(self.expect_bit_array_size())
}

///|
/// A size expression in a bit array pattern: ints, names, `{ }` blocks and
/// the integer operators, by precedence.
fn Parser::expect_bit_array_size(
  self : Parser,
) -> @ast.BitArraySize raise ParseError {
  let opstack : Array[OpEntry] = []
  let estack : Array[@ast.BitArraySize] = [self.parse_bit_array_size_unit()]
  while true {
    guard self.token0 is Some(t) else { break }
    guard token_to_int_operator(t.kind) is Some(op) else { break }
    self.advance()
    ignore(
      handle_operator(
        Some({ token: t, precedence: int_operator_precedence(op), }),
        opstack,
        estack,
        reduce_bit_array_size,
      ),
    )
    estack.push(self.parse_bit_array_size_unit())
  }
  match handle_operator(None, opstack, estack, reduce_bit_array_size) {
    Some(size) => size
    None => self.next_token_unexpected(["A variable name or an int"])
  }
}

///|
fn Parser::parse_bit_array_size_unit(
  self : Parser,
) -> @ast.BitArraySize raise ParseError {
  self.nested(op_bit_array_size, () => {
    match self.token0 {
      Some({ kind: Name(name), span, .. }) => {
        self.advance()
        Variable(location=span, name~)
      }
      Some({ kind: Int(value~, int_value~), span, .. }) => {
        self.advance()
        Int(location=span, value~, int_value~)
      }
      Some({ kind: LeftBrace, span, .. }) => {
        self.advance()
        let inner = self.expect_bit_array_size()
        let (_, end) = self.expect_one(RightBrace)
        Block(location=sp(span.start, end), inner~)
      }
      _ => self.next_token_unexpected(["A variable name or an int"])
    }
  })
}

///|
fn bit_array_size_int(
  value : String,
  int_value : BigInt,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
) -> @ast.Pattern {
  BitArraySize(Int(location=sp(start, end), value~, int_value~))
}

///|
fn bit_array_expression_int(
  value : String,
  int_value : BigInt,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
) -> @ast.Expr {
  Int(location=sp(start, end), value~, int_value~)
}

///|
fn bit_array_const_int(
  value : String,
  int_value : BigInt,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
) -> @ast.Constant {
  Int(location=sp(start, end), value~, int_value~)
}
