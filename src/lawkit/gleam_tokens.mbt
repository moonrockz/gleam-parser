///|
/// A sequence of valid Gleam tokens with their expected kind names, for the
/// round-trip law: `text()` joins the lexemes with one space, so no two
/// tokens merge. The kind name is the `TokenKind` variant written as its
/// `Debug` form without payload (`Name`, `Int`, `Keyword(Fn)`, `LtLt`).
pub(all) struct GleamTokens(Array[(String, String)]) derive(Debug)

///|
pub fn GleamTokens::text(self : GleamTokens) -> String {
  self.0.map(p => p.0).join(" ")
}

///|
pub fn GleamTokens::expected(self : GleamTokens) -> Array[String] {
  self.0.map(p => p.1)
}

///|
/// Every token form with its kind name. Edge values: each operator, each
/// radix, negative numbers, floats of every form, every keyword, names with
/// digits and capitals, an escaped quote, a Unicode escape.
pub fn token_table() -> Array[(String, String)] {
  [
    ("x", "Name"),
    ("foo_bar", "Name"),
    ("x1", "Name"),
    ("fooBar", "Name"),
    ("_", "DiscardName"),
    ("_x", "DiscardName"),
    ("Ok", "UpName"),
    ("List", "UpName"),
    ("0", "Int"),
    ("42", "Int"),
    ("1_000", "Int"),
    ("0x1F", "Int"),
    ("0o7", "Int"),
    ("0b10", "Int"),
    ("-1", "Int"),
    ("-0x10", "Int"),
    ("1.5", "Float"),
    ("1.", "Float"),
    ("1.0e3", "Float"),
    ("1.0e-3", "Float"),
    ("-2.5", "Float"),
    ("1_0.5", "Float"),
    ("\"\"", "String"),
    ("\"hi\"", "String"),
    ("\"a\\\"b\"", "String"),
    ("\"\\u{1F600}\"", "String"),
    ("\"é\"", "String"),
    ("(", "LeftParen"),
    (")", "RightParen"),
    ("[", "LeftSquare"),
    ("]", "RightSquare"),
    ("{", "LeftBrace"),
    ("}", "RightBrace"),
    ("+", "Plus"),
    ("-", "Minus"),
    ("*", "Star"),
    ("/", "Slash"),
    ("<", "Less"),
    (">", "Greater"),
    ("<=", "LessEqual"),
    (">=", "GreaterEqual"),
    ("%", "Percent"),
    ("+.", "PlusDot"),
    ("-.", "MinusDot"),
    ("*.", "StarDot"),
    ("/.", "SlashDot"),
    ("<.", "LessDot"),
    (">.", "GreaterDot"),
    ("<=.", "LessEqualDot"),
    (">=.", "GreaterEqualDot"),
    ("<>", "Concatenate"),
    (":", "Colon"),
    (",", "Comma"),
    ("#", "Hash"),
    ("!", "Bang"),
    ("=", "Equal"),
    ("==", "EqualEqual"),
    ("!=", "NotEqual"),
    ("|", "Vbar"),
    ("||", "VbarVbar"),
    ("&&", "AmperAmper"),
    ("<<", "LtLt"),
    (">>", "GtGt"),
    ("|>", "Pipe"),
    (".", "Dot"),
    ("->", "RArrow"),
    ("<-", "LArrow"),
    ("..", "DotDot"),
    ("@", "At"),
    ("as", "Keyword(As)"),
    ("assert", "Keyword(Assert)"),
    ("auto", "Keyword(Auto)"),
    ("case", "Keyword(Case)"),
    ("const", "Keyword(Const)"),
    ("delegate", "Keyword(Delegate)"),
    ("derive", "Keyword(Derive)"),
    ("echo", "Keyword(Echo)"),
    ("else", "Keyword(Else)"),
    ("fn", "Keyword(Fn)"),
    ("if", "Keyword(If)"),
    ("implement", "Keyword(Implement)"),
    ("import", "Keyword(Import)"),
    ("let", "Keyword(Let)"),
    ("macro", "Keyword(Macro)"),
    ("opaque", "Keyword(Opaque)"),
    ("panic", "Keyword(Panic)"),
    ("pub", "Keyword(Pub)"),
    ("test", "Keyword(Test)"),
    ("todo", "Keyword(Todo)"),
    ("type", "Keyword(Type)"),
    ("use", "Keyword(Use)"),
  ]
}

///|
pub impl @quickcheck.Arbitrary for GleamTokens with fn arbitrary(size, rs) {
  let table = token_table()
  GleamTokens(
    Array::makei(gleam_pick(rs, size + 1), _ => {
      table[gleam_pick(rs, table.length())]
    }),
  )
}

///|
pub impl @quickcheck.Shrink for GleamTokens with fn shrink(self) {
  let GleamTokens(parts) = self
  Array::makei(parts.length(), i => {
    let fewer = parts.copy()
    ignore(fewer.remove(i))
    GleamTokens(fewer)
  }).iter()
}
