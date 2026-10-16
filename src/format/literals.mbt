///|
/// The compiler's `string`: the literal as written, quoted; forced broken
/// when it holds a line feed.
fn string(value : String) -> @pretty.Doc {
  let doc = t("\"") + @pretty.raw_text(value) + t("\"")
  if value.contains("\n") {
    @pretty.force_break(doc)
  } else {
    doc
  }
}

///|
/// The compiler's `bin_op_string`: a string literal on the side of an
/// operator; each line after the first starts a line with no indentation.
fn bin_op_string(value : String) -> @pretty.Doc {
  let lines = value.split("\n").map(l => l.to_string()).to_array()
  if lines.length() <= 1 {
    return t("\"") + @pretty.raw_text(value) + t("\"")
  }
  let mut doc = t("\"") + @pretty.raw_text(lines[0])
  for i in 1..<lines.length() {
    doc = doc + @pretty.set_nesting(0, line_doc) + @pretty.raw_text(lines[i])
  }
  group(doc + t("\""))
}

///|
/// The compiler's `underscore_integer_string`: digits in groups of three
/// from five digits on (six with a minus sign). `value` is ASCII.
fn underscore_integer_string(value : String) -> String {
  let units = value.code_units()
  let len = units.length()
  let mut underscores = 0
  for u in units {
    if u.to_int() == '_'.to_int() {
      underscores += 1
    }
  }
  let watershed = if value.has_prefix("-") { 6 } else { 5 }
  let insert = len - underscores >= watershed
  // Walk from the last character; `digits` counts the characters kept.
  let reversed : Array[Char] = []
  let mut digits = 0
  for k in 0..<len {
    let c = units[len - 1 - k].to_int().unsafe_to_char()
    if c == '_' {
      continue
    }
    if insert && k != 0 && c != '-' && digits % 3 == 0 {
      reversed.push('_')
    }
    reversed.push(c)
    digits += 1
  }
  reversed.rev().iter().map(c => c.to_string()).join("")
}

///|
/// The compiler's `int`.
fn int(value : String) -> @pretty.Doc {
  let digits = value.trim_start(chars="-")
  if digits.has_prefix("0x") ||
    digits.has_prefix("0b") ||
    digits.has_prefix("0o") {
    return t(value)
  }
  t(underscore_integer_string(value))
}

///|
/// The compiler's `float`: underscores in the integer part, trailing
/// zeros of the fraction removed (at least one digit), exponent kept.
fn float(value : String) -> @pretty.Doc {
  let (integer_part, floating_part) = match value.split_once(".") {
    Some((a, b)) => (a.to_string(), b.to_string())
    None => (value, "")
  }
  let (fraction, scientific) = match floating_part.find("e") {
    Some(i) =>
      (
        floating_part.view(end_offset=i).to_string(),
        floating_part.view(start_offset=i).to_string(),
      )
    None => (floating_part, "")
  }
  let mut fraction = fraction.trim_end(chars="0").to_string()
  if fraction.is_empty() {
    fraction = "0"
  }
  t(underscore_integer_string(integer_part)) +
  t(".") +
  t(fraction) +
  t(scientific)
}
