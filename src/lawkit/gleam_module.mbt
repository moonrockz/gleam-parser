///|
/// The text of a valid Gleam module, for the laws that need input the
/// parser accepts with no diagnostic: every definition kind, attribute,
/// expression, statement, pattern, guard and type form, bit arrays, `use`,
/// pipelines, captures, labelled arguments and shorthands, record updates,
/// string prefixes, doc comments, and no deprecated syntax. Depth is
/// bounded by `size`. It shrinks by dropping one definition.
pub(all) struct GleamModule(String) derive(Debug)

///|
pub fn GleamModule::text(self : GleamModule) -> String {
  self.0
}

///|
fn m_pick(rs : @splitmix.RandomState, n : Int32) -> Int32 {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn m_one(rs : @splitmix.RandomState, xs : Array[String]) -> String {
  xs[m_pick(rs, xs.length())]
}

///|
fn m_name(rs : @splitmix.RandomState) -> String {
  m_one(rs, ["a", "b", "c", "x", "wibble", "foo_bar", "x1"])
}

///|
fn m_upname(rs : @splitmix.RandomState) -> String {
  m_one(rs, ["Point", "Some", "Ok", "Wibble", "T"])
}

///|
fn m_string(rs : @splitmix.RandomState) -> String {
  m_one(rs, [
    "\"\"", "\"s\"", "\"é 𝄞\"", "\"a\\nb\"", "\"\\u{1F600}\"", "\"q\\\"q\"",
  ])
}

///|
fn m_int(rs : @splitmix.RandomState) -> String {
  m_one(rs, ["0", "1", "42", "1_000", "0x1F", "0o7", "0b101"])
}

///|
fn m_float(rs : @splitmix.RandomState) -> String {
  m_one(rs, ["1.5", "0.0", "1.0e3", "2.5e-2", "1."])
}

///|
fn m_binop(rs : @splitmix.RandomState) -> String {
  m_one(rs, [
    "+", "-", "*", "/", "%", "+.", "-.", "*.", "/.", "<", ">", "<=", ">=", "<.",
    ">.", "<=.", ">=.", "==", "!=", "&&", "||", "<>",
  ])
}

///|
fn m_list(
  rs : @splitmix.RandomState,
  size : Int32,
  f : () -> String,
) -> Array[String] {
  let n = if size <= 0 { 0 } else { m_pick(rs, 3) }
  Array::makei(n, _ => f())
}

///|
pub fn text_type(size : Int32, rs : @splitmix.RandomState) -> String {
  let s = size / 2
  match m_pick(rs, if size <= 0 { 4 } else { 8 }) {
    0 => "Int"
    1 => m_name(rs)
    2 => "_"
    3 => "option.Option(a)"
    4 => "List(\{text_type(s, rs)})"
    5 => "#(\{text_type(s, rs)}, \{text_type(s, rs)})"
    6 =>
      "fn(\{m_list(rs, s, () => text_type(s, rs)).join(", ")}) -> \{text_type(s, rs)}"
    _ => "Result(\{text_type(s, rs)}, \{text_type(s, rs)})"
  }
}

///|
pub fn text_pattern(size : Int32, rs : @splitmix.RandomState) -> String {
  let s = size / 2
  match m_pick(rs, if size <= 0 { 6 } else { 17 }) {
    0 => "_"
    1 => m_name(rs)
    2 => m_int(rs)
    3 => m_string(rs)
    4 => "\"pre\" <> \{m_name(rs)}"
    5 => "\"pre\" as p <> rest"
    6 => "\"s\" as w"
    7 => "[]"
    8 => "[\{text_pattern(s, rs)}, \{text_pattern(s, rs)}]"
    9 => "[\{text_pattern(s, rs)}, ..rest]"
    10 => "[\{text_pattern(s, rs)}, ..]"
    11 => "#(\{text_pattern(s, rs)}, \{text_pattern(s, rs)})"
    12 => "\{m_upname(rs)}(\{text_pattern(s, rs)})"
    13 => "\{m_upname(rs)}(x: \{text_pattern(s, rs)}, y:, ..)"
    14 => "option.\{m_upname(rs)}(\{text_pattern(s, rs)}) as whole"
    15 => "<<a:8, b:size(n + 1)-unit(2), c:utf8, d:bits>>"
    _ => "\{m_upname(rs)}(..)"
  }
}

///|
fn text_guard(rs : @splitmix.RandomState) -> String {
  m_one(rs, [
    " if a == b", " if a > 1 && !b", " if a.0 == 1 || b.field != 2", " if { a || b }",
    " if a == Some(1)", " if a <> \"s\" == b", " if a +. 1.0 >. 2.0", " if a == option.None",
  ])
}

///|
pub fn text_expr(size : Int32, rs : @splitmix.RandomState) -> String {
  let s = size / 2
  match m_pick(rs, if size <= 0 { 10 } else { 28 }) {
    0 => m_int(rs)
    1 => m_float(rs)
    2 => m_string(rs)
    3 => m_name(rs)
    4 => m_upname(rs)
    5 => "todo"
    6 => "panic"
    7 => "todo as \"later\""
    8 => "panic as \"boom\""
    9 => "Nil"
    10 => "[\{m_list(rs, s, () => text_expr(s, rs)).join(", ")}]"
    11 => "[\{text_expr(s, rs)}, ..\{m_name(rs)}]"
    12 => "#(\{text_expr(s, rs)}, \{text_expr(s, rs)})"
    13 => "{\n\{text_statements(s, rs)}\n}"
    14 => "fn(\{m_name(rs)}, b: Int) -> Int {\n\{text_statements(s, rs)}\n}"
    15 => "\{m_name(rs)}(\{m_list(rs, s, () => text_expr(s, rs)).join(", ")})"
    16 => "\{m_name(rs)}(\{text_expr(s, rs)}, label: \{text_expr(s, rs)})"
    17 => "\{m_name(rs)}(\{text_expr(s, rs)}, _)"
    18 => "\{m_name(rs)}(x:, y: \{text_expr(s, rs)})"
    19 => "\{text_expr(s, rs)} |> \{m_name(rs)}(\{text_expr(s, rs)}) |> echo"
    20 => "\{text_expr(s, rs)} \{m_binop(rs)} \{text_expr(s, rs)}"
    21 => "!\{m_name(rs)}"
    22 => "-\{m_name(rs)}"
    23 => {
      let clauses = Array::makei(1 + m_pick(rs, 3), _ => {
        let guard_ = if m_pick(rs, 3) == 0 { text_guard(rs) } else { "" }
        "    \{text_clause_patterns(s, rs)}\{guard_} -> \{text_expr(s, rs)}"
      })
      "case \{text_expr(s, rs)}, \{m_name(rs)} {\n\{clauses.join("\n")}\n  }"
    }
    24 => "\{m_name(rs)}.\{m_name(rs)}.0"
    25 => "Point(..\{m_name(rs)}, x: \{text_expr(s, rs)}, y:)"
    // A segment value is an expression unit, so a name here, not any expression.
    26 =>
      "<<\{m_name(rs)}:8, 1:size(n)-unit(2), \"s\":utf8, x:bits, y:float-little>>"
    _ => "echo \{text_expr(s, rs)} as \"m\""
  }
}

///|
/// A clause's patterns must match the two subjects, so every clause has
/// two; one clause in three has an alternative (`a, b | c, d`).
fn text_clause_patterns(size : Int32, rs : @splitmix.RandomState) -> String {
  let first = "\{text_pattern(size, rs)}, \{text_pattern(size, rs)}"
  if m_pick(rs, 3) == 0 {
    "\{first} | \{text_pattern(size, rs)}, \{text_pattern(size, rs)}"
  } else {
    first
  }
}

///|
pub fn text_statement(size : Int32, rs : @splitmix.RandomState) -> String {
  let s = size / 2
  match m_pick(rs, 9) {
    0 => "let \{text_pattern(s, rs)} = \{text_expr(s, rs)}"
    1 => "let \{m_name(rs)}: \{text_type(s, rs)} = \{text_expr(s, rs)}"
    2 => "let assert \{text_pattern(s, rs)} = \{text_expr(s, rs)}"
    3 => "let assert \{text_pattern(s, rs)} = \{text_expr(s, rs)} as \"m\""
    4 =>
      "use \{m_name(rs)}, \{text_pattern(s, rs)}: Int <- \{m_name(rs)}(\{text_expr(s, rs)})"
    5 => "use <- \{m_name(rs)}"
    6 => "assert \{text_expr(s, rs)}"
    7 => "assert \{text_expr(s, rs)} as \"m\""
    _ => text_expr(s, rs)
  }
}

///|
pub fn text_statements(size : Int32, rs : @splitmix.RandomState) -> String {
  let n = 1 + m_pick(rs, 3)
  Array::makei(n, _ => "  " + text_statement(size, rs)).join("\n")
}

///|
fn text_doc(rs : @splitmix.RandomState) -> String {
  match m_pick(rs, 3) {
    0 => ""
    1 => "/// Docs.\n"
    _ => "/// Line one\n///   line two with \"quotes\" and é\n"
  }
}

///|
fn text_attributes(
  rs : @splitmix.RandomState,
  public : Bool,
  function : Bool,
) -> String {
  let out = StringBuilder()
  if m_pick(rs, 4) == 0 {
    out.write_string("@deprecated(\"old\")\n")
  }
  if public && m_pick(rs, 5) == 0 {
    out.write_string("@internal\n")
  }
  if function && m_pick(rs, 5) == 0 {
    out.write_string("@target(\{m_one(rs, ["erlang", "javascript"])})\n")
  }
  if function && m_pick(rs, 5) == 0 {
    out.write_string("@external(erlang, \"mod\", \"fun\")\n")
  }
  out.to_string()
}

///|
pub fn text_definition(size : Int32, rs : @splitmix.RandomState) -> String {
  let s = size / 2
  let public = m_pick(rs, 2) == 0
  let pub_ = if public { "pub " } else { "" }
  match m_pick(rs, 7) {
    0 =>
      m_one(rs, [
        "import gleam/io", "import gleam/list.{map, filter as keep}", "import gleam/option.{type Option, type Result as Res, Some, None as Nothing}",
        "import gleam/string as str", "import a/b/c.{d} as e",
      ])
    1 =>
      "\{text_doc(rs)}\{text_attributes(rs, public, false)}\{pub_}const \{m_name(rs)} = \{text_constant(s, rs)}"
    2 =>
      "\{text_doc(rs)}\{text_attributes(rs, public, false)}\{pub_}const \{m_name(rs)}: \{text_type(s, rs)} = \{text_constant(s, rs)}"
    3 => {
      let variants = Array::makei(1 + m_pick(rs, 3), _ => {
        let doc = if m_pick(rs, 3) == 0 { "  /// Variant docs.\n" } else { "" }
        let deprecated = if m_pick(rs, 4) == 0 {
          "  @deprecated(\"x\")\n"
        } else {
          ""
        }
        match m_pick(rs, 3) {
          0 => "\{doc}\{deprecated}  \{m_upname(rs)}"
          1 =>
            "\{doc}\{deprecated}  \{m_upname(rs)}(\{text_type(s, rs)}, \{text_type(s, rs)})"
          _ =>
            "\{doc}\{deprecated}  \{m_upname(rs)}(label: \{text_type(s, rs)}, other: \{text_type(s, rs)},)"
        }
      })
      let opaque_ = if public && m_pick(rs, 3) == 0 { "opaque " } else { "" }
      let params = if m_pick(rs, 2) == 0 { "" } else { "(a, b)" }
      "\{text_doc(rs)}\{text_attributes(rs, public, false)}\{pub_}\{opaque_}type \{m_upname(rs)}\{params} {\n\{variants.join("\n")}\n}"
    }
    4 =>
      "\{text_doc(rs)}\{text_attributes(rs, public, false)}\{pub_}type \{m_upname(rs)}(a) = \n  \{text_type(s, rs)}"
    5 => {
      let params = m_one(rs, [
        "",
        "a",
        "a, b: Int",
        "label a: Int, _b, label_two _: Int",
        "a: \{text_type(s, rs)}",
      ])
      let ret = if m_pick(rs, 2) == 0 { "" } else { " -> \{text_type(s, rs)}" }
      "\{text_doc(rs)}\{text_attributes(rs, public, true)}\{pub_}fn \{m_name(rs)}(\{params})\{ret} {\n\{text_statements(s, rs)}\n}"
    }
    _ =>
      "@external(erlang, \"m\", \"f\")\n\{pub_}fn \{m_name(rs)}(a: Int) -> Int"
  }
}

///|
pub fn text_constant(size : Int32, rs : @splitmix.RandomState) -> String {
  let s = size / 2
  match m_pick(rs, if size <= 0 { 5 } else { 12 }) {
    0 => m_int(rs)
    1 => m_float(rs)
    2 => m_string(rs)
    3 => "Nil"
    4 => m_name(rs)
    5 => "[\{m_list(rs, s, () => text_constant(s, rs)).join(", ")}]"
    6 => "[\{text_constant(s, rs)}, ..\{m_name(rs)}]"
    7 => "#(\{text_constant(s, rs)}, \{text_constant(s, rs)})"
    8 =>
      "\{m_upname(rs)}(\{text_constant(s, rs)}, label: \{text_constant(s, rs)})"
    9 =>
      "option.\{m_upname(rs)}(..\{m_name(rs)}, x: \{text_constant(s, rs)}, y:)"
    10 => "<<1, \{text_constant(s, rs)}:size(8), \"s\":utf8>>"
    _ =>
      "\{text_constant(s, rs)} \{m_one(rs, ["+", "<>", "*"])} \{text_constant(s, rs)}"
  }
}

///|
/// A module: optional module docs, then definitions separated by blank
/// lines.
pub fn gen_module(size : Int32, rs : @splitmix.RandomState) -> String {
  let out = StringBuilder()
  if m_pick(rs, 3) == 0 {
    out.write_string("//// Module docs.\n//// Second line.\n\n")
  }
  let n = m_pick(rs, 4)
  for i in 0..<n {
    if i > 0 {
      out.write_string("\n\n")
    }
    out.write_string(text_definition(size, rs))
  }
  out.write_string("\n")
  out.to_string()
}

///|
pub impl @quickcheck.Arbitrary for GleamModule with fn arbitrary(size, rs) {
  GleamModule(gen_module(size, rs))
}

///|
/// Shrinks by dropping one definition (a block separated by a blank line).
pub impl @quickcheck.Shrink for GleamModule with fn shrink(self) {
  let blocks = self.0.split("\n\n").map(b => b.to_owned()).collect()
  if blocks.length() <= 1 {
    return [].iter()
  }
  Array::makei(blocks.length(), i => {
    let fewer = blocks.copy()
    ignore(fewer.remove(i))
    GleamModule(fewer.join("\n\n"))
  }).iter()
}
