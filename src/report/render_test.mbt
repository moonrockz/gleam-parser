///|
fn first_error(text : String) -> @diagnostic.Diagnostic raise {
  let r = @parser.parse_text(text)
  guard r.diagnostics.filter(d => d.is_error()).get(0) is Some(d) else {
    fail("no error in \{text}")
  }
  d
}

///|
fn first_warning(text : String) -> @diagnostic.Diagnostic raise {
  let r = @parser.parse_text(text)
  guard r.diagnostics.filter(d => !d.is_error()).get(0) is Some(d) else {
    fail("no warning in \{text}")
  }
  d
}

///|
fn plain(d : @diagnostic.Diagnostic, text : String, path : String) -> String {
  @report.render_plain(d, @scanner.SourceText::new(text), path)
}

///|
test "a primary label with a hint (const_string_concat_naked_right)" {
  let text = "\nconst no_cute_bee = \"cute\" <>\n"
  inspect(
    plain(first_error(text), text, "/src/parse/error.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ /src/parse/error.gleam:2:28
      #|  │
      #|2 │ const no_cute_bee = "cute" <>
      #|  │                            ^^ This operator has no value on its right side
      #|
      #|Hint: Remove it or put a value after it.
      #|
    ),
  )
}

///|
test "a secondary label on the primary's line (list_spread_followed_by_other_spread)" {
  let text = "\npub fn main() -> Nil {\n  let xs = [1, 2, 3]\n  let ys = [5, 6, 7]\n  [1, ..xs, ..ys]\n}\n"
  inspect(
    plain(first_error(text), text, "/src/parse/error.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ /src/parse/error.gleam:5:13
      #|  │
      #|5 │   [1, ..xs, ..ys]
      #|  │       --    ^^ I wasn't expecting a second list here
      #|  │       │      
      #|  │       You're using a list here
      #|
      #|Lists are immutable and singly-linked, so to join two or more lists
      #|all the elements of the lists would need to be copied into a new list.
      #|This would be slow, so there is no built-in syntax for it.
      #|
    ),
  )
}

///|
test "text and hint (list_spread_followed_by_extra_items)" {
  let text = "\npub fn main() -> Nil {\n  let xs = [1, 2, 3]\n  [1, 2, ..xs, 3 + 3, 4]\n}\n"
  inspect(
    plain(first_error(text), text, "/src/parse/error.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ /src/parse/error.gleam:4:10
      #|  │
      #|4 │   [1, 2, ..xs, 3 + 3, 4]
      #|  │          ^^^^ I wasn't expecting elements after this
      #|
      #|Lists are immutable and singly-linked, so to append items to them
      #|all the elements of a list would need to be copied into a new list.
      #|This would be slow, so there is no built-in syntax for it.
      #|
      #|Hint: Prepend items to the list and then reverse it once you are done.
      #|
    ),
  )
}

///|
test "a multi-line label (missing_constructor_name_with_multiple_fields)" {
  let text = "\npub type Wibble(a) {\n  field: Int,\n  other: a\n}\n"
  inspect(
    plain(first_error(text), text, "/src/parse/error.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ /src/parse/error.gleam:3:3
      #|  │  
      #|3 │ ╭   field: Int,
      #|4 │ │   other: a
      #|  │ ╰──────────^ I was not expecting this
      #|
      #|Each custom type variant must have a constructor:
      #|
      #|pub type Wibble {
      #|  Wibble(
      #|    field: Int,
      #|    other: a,
      #|  )
      #|}
      #|
    ),
  )
}

///|
test "a lexical error on a non-ASCII line counts columns in code points (unicode_cyrillic_a)" {
  let text = "pub fn main() { а }"
  inspect(
    plain(first_error(text), text, "/src/parse/error.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ /src/parse/error.gleam:1:17
      #|  │
      #|1 │ pub fn main() { а }
      #|  │                 ^ Unexpected character
      #|
      #|This looks like ascii latin letter a, but it is actually the unicode
      #|Cyrillic letter а.
      #|
    ),
  )
}

///|
test "a snippet parser's error renders too (type_angle_generics_usage_with_module_error)" {
  let text = "let set: set.Set<Int> = set.new()"
  let d = try @parser.parse_statements_text(text) catch {
    e => e.to_diagnostic()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    plain(d, text, "/src/parse/error.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ /src/parse/error.gleam:1:17
      #|  │
      #|1 │ let set: set.Set<Int> = set.new()
      #|  │                 ^ I was expecting `(` here.
      #|
      #|Type parameters use lowercase names and are surrounded by parentheses.
      #|
      #|    set.Set(Int)
      #|
      #|See: https://tour.gleam.run/data-types/generic-custom-types/
      #|
    ),
  )
}

///|
test "warnings render with their titles, texts and hints" {
  let prepend = "\n    pub fn main() {\n      let letters = [\"b\", \"c\"]\n      [\"a\"..letters]\n    }\n        "
  inspect(
    plain(first_warning(prepend), prepend, "test/path"),
    content=(
      #|warning: Deprecated prepend syntax
      #|  ┌─ test/path:4:11
      #|  │
      #|4 │       ["a"..letters]
      #|  │           ^^ This spread should be preceded by a comma
      #|
      #|This syntax for prepending to a list is deprecated.
      #|When prepending an item to a list it should be preceded by a comma, like
      #|this: `[item, ..list]`.
      #|
    ),
  )
  let detached = "\n/// This comment is detached\n//\n\n/// This is actual documentation\npub const pi = 3.14\n"
  inspect(
    plain(first_warning(detached), detached, "test/path"),
    content=(
      #|warning: Detached doc comment
      #|  ┌─ test/path:2:4
      #|  │
      #|2 │ /// This comment is detached
      #|  │    ^^^^^^^^^^^^^^^^^^^^^^^^^ This is not attached to a definition
      #|
      #|This doc comment is followed by a regular comment so it is not attached to
      #|any definition.
      #|
      #|Hint: Move the comment above the doc comment
      #|
    ),
  )
  let guard_ = "\npub fn main() {\n    let wibble = 10\n    case wibble {\n        10 if -> True\n        _ -> False\n    }\n\n}"
  inspect(
    plain(first_warning(guard_), guard_, "test/path"),
    content=(
      #|warning: Deprecated empty guard syntax
      #|  ┌─ test/path:5:12
      #|  │
      #|5 │         10 if -> True
      #|  │            ^^ This can be removed.
      #|
      #|This syntax for an empty guard is deprecated. To have a clause without a
      #|guard, remove this.
      #|
    ),
  )
  let shorthand = "\n@target(erl)\npub fn wibble() { panic }\n"
  inspect(
    plain(first_warning(shorthand), shorthand, "test/path"),
    content=(
      #|warning: Deprecated target shorthand syntax
      #|  ┌─ test/path:2:9
      #|  │
      #|2 │ @target(erl)
      #|  │         ^^^ This should be replaced with `erlang`
      #|
      #|This shorthand target name is deprecated. Use the full name: `erlang`
      #|instead.
      #|
    ),
  )
}

///|
test "an unexpected end of file points at the last byte" {
  let text = "fn f() {\n"
  inspect(
    plain(first_error(text), text, "a.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ a.gleam:1:9
      #|  │
      #|1 │ fn f() {
      #|  │         ^ The module ended unexpectedly
      #|
      #|
    ),
  )
}

///|
test "a tab reaches the next tab stop and a long multi-line label shows a break" {
  // Tab width 4: `\tx` puts x in column 5 (codespan counts tabs as one
  // character for the column number).
  let text = "fn f() {\n\tlet y = 'a'\n}\n"
  inspect(
    plain(first_error(text), text, "t.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ t.gleam:2:10
      #|  │
      #|2 │     let y = 'a'
      #|  │             ^ Unexpected single quote
      #|
      #|Hint: Strings are written with double quotes.
      #|
    ),
  )
  // Six field lines: lines 3 to 5 after the start, one before the end, and
  // a `·` break for the skipped lines.
  let long = "pub type T(a) {\n  f1: Int,\n  f2: Int,\n  f3: Int,\n  f4: Int,\n  f5: Int,\n  f6: Int,\n  f7: Int,\n  f8: a\n}\n"
  inspect(
    plain(first_error(long), long, "t.gleam"),
    content=(
      #|error: Syntax error
      #|  ┌─ t.gleam:2:3
      #|  │  
      #|2 │ ╭   f1: Int,
      #|3 │ │   f2: Int,
      #|4 │ │   f3: Int,
      #|5 │ │   f4: Int,
      #|  · │
      #|8 │ │   f7: Int,
      #|9 │ │   f8: a
      #|  │ ╰───────^ I was not expecting this
      #|
      #|Each custom type variant must have a constructor:
      #|
      #|pub type T {
      #|  T(
      #|    f1: Int,
      #|    f2: Int,
      #|    f3: Int,
      #|    f4: Int,
      #|    f5: Int,
      #|    f6: Int,
      #|    f7: Int,
      #|    f8: a,
      #|  )
      #|}
      #|
    ),
  )
}

///|
test "render_terminal adds colours around the same text" {
  let text = "const x 1\n"
  let d = first_error(text)
  let coloured = @report.render_terminal(
    d,
    @scanner.SourceText::new(text),
    "x.gleam",
  )
  @expect.expect_all(e => {
    e
    .expect(
      coloured.has_prefix("\u{1b}[1;91merror\u{1b}[1m: Syntax error\u{1b}[0m\n"),
    )
    .to_be_true()
    e.expect(coloured.contains("\u{1b}[31m^\u{1b}[0m")).to_be_true()
    e.expect(strip_ansi(coloured)).to_equal(plain(d, text, "x.gleam"))
  })
}

///|
fn strip_ansi(s : String) -> String {
  let sb = StringBuilder()
  let mut i = 0
  let n = s.length()
  while i < n {
    if s.code_unit_at(i) == '\u{1b}'.to_int().to_uint16() &&
      i + 1 < n &&
      s.code_unit_at(i + 1) == '['.to_int().to_uint16() {
      i += 2
      while i < n && s.code_unit_at(i) != 'm'.to_int().to_uint16() {
        i += 1
      }
      i += 1
    } else {
      sb.write_char(s.code_unit_at(i).to_char().unwrap())
      i += 1
    }
  }
  sb.to_string()
}
