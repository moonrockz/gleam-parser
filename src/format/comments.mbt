///|
/// The compiler's `printed_comments`.
fn printed_comments(
  comments : ArrayView[CommentOrLine],
  trailing_newline : Bool,
) -> @pretty.Doc? {
  if comments.is_empty() {
    return None
  }
  let parts : Array[@pretty.Doc] = []
  let n = comments.length()
  let mut i = 0
  while i < n {
    match comments[i] {
      EmptyLine => i += 1
      Text(c) => {
        parts.push(t("//") + @pretty.zero_width(c))
        i += 1
        if i < n {
          match comments[i] {
            Text(_) => parts.push(line_doc)
            EmptyLine => {
              i += 1
              if i < n || trailing_newline {
                parts.push(two_lines_doc)
              }
            }
          }
        } else if trailing_newline {
          parts.push(line_doc)
        }
      }
    }
  }
  let doc = @pretty.concat(parts)
  Some(if trailing_newline { @pretty.force_break(doc) } else { doc })
}

///|
/// The compiler's `commented`.
fn commented(
  doc : @pretty.Doc,
  comments : ArrayView[CommentOrLine],
) -> @pretty.Doc {
  match printed_comments(comments, true) {
    Some(c) => c + group(doc)
    None => doc
  }
}

///|
/// The doc comments before `limit` as `///` lines, each ended by a line
/// feed, forced broken; `None` when there is none.
fn Formatter::doc_comments_opt(self : Formatter, limit : Int32) -> @pretty.Doc? {
  let comments = self.pop_doc_comments(limit)
  if comments.is_empty() {
    return None
  }
  let lines = comments.map(c => t("///") + @pretty.zero_width(c))
  Some(@pretty.force_break(@pretty.join(lines, line_doc) + line_doc))
}

///|
/// The compiler's `doc_comments`.
fn Formatter::doc_comments(self : Formatter, limit : Int32) -> @pretty.Doc {
  self.doc_comments_opt(limit).unwrap_or(@pretty.empty())
}

///|
/// The compiler's `printed_documented_comments`: regular comments with the
/// doc comments that come before each of them.
fn Formatter::printed_documented_comments(
  self : Formatter,
  comments : ArrayView[(Int32, CommentOrLine)],
) -> @pretty.Doc? {
  if comments.is_empty() {
    return None
  }
  let parts : Array[@pretty.Doc] = []
  let n = comments.length()
  let mut i = 0
  while i < n {
    match comments[i] {
      (_, EmptyLine) => i += 1
      (start, Text(c)) => {
        let doc_comment = self.doc_comments_opt(start)
        let is_doc_commented = doc_comment is Some(_)
        parts.push(doc_comment.unwrap_or(@pretty.empty()))
        parts.push(t("//") + @pretty.zero_width(c))
        i += 1
        if i < n {
          match comments[i] {
            (_, Text(_)) => parts.push(line_doc)
            (_, EmptyLine) => {
              i += 1
              parts.push(two_lines_doc)
            }
          }
        } else {
          parts.push(if is_doc_commented { two_lines_doc } else { line_doc })
        }
      }
    }
  }
  Some(@pretty.force_break(@pretty.concat(parts)))
}
