///|
/// The value of a digit in any radix up to 16, or 99 for a non-digit.
fn digit_value(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    99
  }
}

///|
/// The compiler's `is_digit_of_radix`.
fn is_digit_of_radix(c : Char?, radix : Int32) -> Bool {
  match c {
    Some(c) => digit_value(c) < radix
    None => false
  }
}

///|
/// The number an `Int` literal denotes (the compiler's `parse_int_value`):
/// an optional `-`, then `0x`, `0o` or `0b` for radix 16, 8 or 2, then
/// digits with `_` separators. `None` when a character does not fit.
///
/// ```mbt check
/// test {
///   debug_inspect(@scanner.parse_int_value("-0x1_F"), content="Some(-31)")
///   debug_inspect(@scanner.parse_int_value("0x"), content="None")
/// }
/// ```
pub fn parse_int_value(value : String) -> BigInt? {
  let negative = value.has_prefix("-")
  let body = if negative { value[1:].to_string() } else { value }
  let (radix, digits) = if body.has_prefix("0x") {
    (16, body[2:].to_string())
  } else if body.has_prefix("0o") {
    (8, body[2:].to_string())
  } else if body.has_prefix("0b") {
    (2, body[2:].to_string())
  } else {
    (10, body)
  }
  let clean = StringBuilder()
  for i = 0; i < digits.length(); i = i + 1 {
    let c = digits.code_unit_at(i).to_int().unsafe_to_char()
    if c == '_' {
      continue
    }
    if digit_value(c) >= radix {
      return None
    }
    clean.write_char(c)
  }
  let text = clean.to_string()
  if text == "" {
    return None
  }
  let n = BigInt::from_string(text, radix~)
  Some(if negative { -n } else { n })
}

///|
/// The number a `Float` literal denotes (the compiler's
/// `LiteralFloatValue::parse`, Rust `f64::from_str` after removing `_`):
/// `1.`, `1.e3`, `1.0e-3` are numbers; a literal too big is infinity.
/// `None` when the text is not a number.
pub fn parse_float_value(value : String) -> Double? {
  let sb = StringBuilder()
  for i = 0; i < value.length(); i = i + 1 {
    let c = value.code_unit_at(i).to_int().unsafe_to_char()
    if c != '_' {
      sb.write_char(c)
    }
  }
  // MoonBit's parser needs a digit after `.`; Rust's does not.
  let text = sb.to_string().replace(old=".e", new=".0e")
  let text = if text.has_suffix(".") { text + "0" } else { text }
  if text == "" || text.has_suffix("e") || text.has_suffix("e-") {
    return None
  }
  try @string.parse_double(text) catch {
    _ => out_of_range(text)
  } noraise {
    d => if d != d { None } else { Some(d) }
  }
}

///|
/// Rust reads a float whose exponent is too big as infinity and one whose
/// exponent is too small as zero; MoonBit's parser rejects both. Read the
/// mantissa and the exponent apart and pick the limit.
fn out_of_range(text : String) -> Double? {
  guard text.split_once("e") is Some((mantissa, exponent)) else { return None }
  let m = @string.parse_double(mantissa) catch { _ => return None }
  let x = @string.parse_int(exponent) catch { _ => return None }
  let sign = if m < 0.0 { -1.0 } else { 1.0 }
  if x < 0 {
    Some(sign * 0.0)
  } else {
    Some(sign * (1.0 / 0.0))
  }
}
