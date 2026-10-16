///|
/// A valid module with a `//` comment line before every code line of a
/// `GleamModule`: before each definition, each statement, each clause,
/// each variant and each closing brace (the generator writes one line per
/// statement, so a comment never sits before a closing bracket inside an
/// expression, before an arrow, a pipe or an alternative pattern; a
/// generator for those positions is a follow-up). The comment texts are
/// `// c<n>`, each once, so a law can count them in the output. A comment
/// never separates a `///` doc comment or an attribute from its
/// definition, so the module parses with no diagnostic. Shrinks by
/// dropping one definition block of the module.
pub(all) struct Commented(String) derive(Debug)

///|
pub fn Commented::text(self : Commented) -> String {
  self.0
}

///|
/// The comment texts in the order of insertion.
pub fn Commented::comments(self : Commented) -> Array[String] {
  let out = []
  for line in self.0.split("\n") {
    let t = line.trim().to_owned()
    if t.has_prefix("// c") {
      out.push(t)
    }
  }
  out
}

///|
/// Insert `// c<n>` before every line that holds code (not before an empty
/// line, not between a `///` doc comment or an `@` attribute and the
/// definition after it).
fn comment_every_line(module_text : String) -> String {
  let out = []
  let mut n = 0
  let mut after_doc = false
  for line in module_text.split("\n") {
    let l = line.to_owned()
    let trimmed = l.trim().to_owned()
    if trimmed.is_empty() || after_doc {
      out.push(l)
    } else {
      // The comment gets the line's indentation, as a programmer writes it.
      let indent = l.length() - l.trim_start(chars=" ").length()
      out.push(" ".repeat(indent) + "// c\{n}")
      n += 1
      out.push(l)
    }
    after_doc = trimmed.has_prefix("///") || trimmed.has_prefix("@")
  }
  out.join("\n")
}

///|
pub impl @quickcheck.Arbitrary for Commented with fn arbitrary(size, rs) {
  Commented(comment_every_line(gen_module(size, rs)))
}

///|
/// Shrinks by dropping one definition block (a block separated by a blank
/// line) and commenting the rest again.
pub impl @quickcheck.Shrink for Commented with fn shrink(self) {
  let blocks = self.0.split("\n\n").map(b => b.to_owned()).collect()
  if blocks.length() <= 1 {
    return [].iter()
  }
  Array::makei(blocks.length(), i => {
    let fewer = blocks.copy()
    ignore(fewer.remove(i))
    let bare = fewer
      .join("\n\n")
      .split("\n")
      .filter(l => !l.trim().has_prefix("// c"))
      .map(l => l.to_owned())
      .collect()
      .join("\n")
    Commented(comment_every_line(bare))
  }).iter()
}

///|
/// A valid module with a `//` comment line before every hard token of a
/// `GleamModule`: a closing `)` or `]`, `|>`, `->`, `|`, `as` and `..`
/// (the positions `Commented` does not reach). No comment goes inside an
/// empty `()`, `#()` or `[]`, inside an attribute, inside a bit array
/// `<<>>`, inside a `let` pattern, before the `as` of a pattern or before
/// a `->` followed by a list or a tuple: for a comment inside an
/// empty tuple or list that a comment precedes, the compiler writes
/// `#(// c)`, which does not parse; a comment inside an attribute detaches
/// the doc comment; the compiler is not idempotent on a bit array with a
/// comment between its segments, nor on a comment it moved (from a `let`
/// pattern or from before `as` or `->`) before a list or tuple that holds
/// a comment. The port copies the compiler in all four cases. The comment
/// texts
/// are `// c<n>`, each once, so a law can count them in the output. Shrinks
/// with its module.
pub struct HardCommented {
  module_ : GleamModule
  text : String
} derive(Debug)

///|
/// The module with a comment before each of its hard tokens.
pub fn HardCommented::of(module_ : GleamModule) -> HardCommented {
  { module_, text: comment_hard_positions(module_.text()), }
}

///|
pub fn HardCommented::text(self : HardCommented) -> String {
  self.text
}

///|
/// The comment texts in the order of insertion.
pub fn HardCommented::comments(self : HardCommented) -> Array[String] {
  Commented(self.text).comments()
}

///|
/// Insert `// c<n>` on its own line before every `)` and `]` that does not
/// close an empty group, and before every `|>`, `->`, `|`, `as` and `..`.
fn comment_hard_positions(module_text : String) -> String {
  let stream = @scanner.tokenize_text(module_text)
  let out = StringBuilder()
  let mut n = 0
  let mut previous : @scanner.TokenKind? = None
  // The parenthesis depth inside an attribute, or -1 outside one: a comment
  // inside `@deprecated("old")` sits between a doc comment and its
  // definition and detaches it (warning GL-PARSE-003).
  let mut attribute_depth = -1
  // The `<<` depth: the compiler is not idempotent on a bit array with a
  // comment between its segments (a known difference the port copies).
  let mut bits_depth = 0
  // Inside an `import` line: `as` there is an alias, not a pattern.
  let mut in_import = false
  // Inside a `let` pattern (up to its `=`): the compiler moves a comment
  // from there before the value, the list or tuple case again.
  let mut in_let_pattern = false
  for i, token in stream.tokens {
    for t in token.trivia_before {
      out.write_string(t.text())
      if t is Newline(_, _) {
        in_import = false
      }
    }
    if token.kind is Keyword(Import) {
      in_import = true
    }
    if token.kind is Keyword(Let) {
      in_let_pattern = true
    }
    let next = stream.tokens.get(i + 1).map(t => t.kind)
    let hard = match token.kind {
      RightParen => !(previous is Some(LeftParen))
      RightSquare => !(previous is Some(LeftSquare))
      // `as` of a pattern is left out: the compiler moves the comment
      // before the value, and a list or tuple with a comment inside is
      // then not idempotent (a known difference). The `as` of an import
      // alias and of an assert message stay.
      Keyword(As) => in_import || next is Some(String(_))
      // The same for a comment before the `->` of a clause whose body is a
      // list or a tuple: the compiler moves it before the body.
      RArrow => !(next is Some(LeftSquare | Hash))
      Pipe | Vbar | DotDot => true
      _ => false
    }
    // A comment before the `as` that ends a pattern moves before the value
    // too.
    if hard &&
      attribute_depth < 0 &&
      bits_depth == 0 &&
      !in_let_pattern &&
      !(next is Some(Keyword(As))) {
      out.write_string("\n// c\{n}\n")
      n += 1
    }
    out.write_string(token.lexeme)
    match token.kind {
      Equal => in_let_pattern = false
      LtLt => bits_depth += 1
      GtGt => bits_depth -= 1
      At => attribute_depth = 0
      LeftParen => if attribute_depth >= 0 { attribute_depth += 1 }
      RightParen =>
        if attribute_depth > 0 {
          attribute_depth -= 1
          if attribute_depth == 0 {
            attribute_depth = -1
          }
        }
      Name(_) => ()
      _ => if attribute_depth == 0 { attribute_depth = -1 }
    }
    previous = Some(token.kind)
  }
  match stream.tokens.last() {
    Some(last) =>
      for t in last.trivia_after {
        out.write_string(t.text())
      }
    None =>
      for t in stream.trivia {
        out.write_string(t.text())
      }
  }
  out.to_string()
}

///|
pub impl @quickcheck.Arbitrary for HardCommented with fn arbitrary(size, rs) {
  HardCommented::of(GleamModule(gen_module(size, rs)))
}

///|
pub impl @quickcheck.Shrink for HardCommented with fn shrink(self) {
  @quickcheck.Shrink::shrink(self.module_).map(m => HardCommented::of(m))
}
