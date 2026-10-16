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
