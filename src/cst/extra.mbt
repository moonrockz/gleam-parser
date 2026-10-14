///|
/// The `ModuleExtra` positions that come from trivia, as the compiler's
/// `Parser::next_token` gathers them: the content span of every comment by
/// kind; the start of every line end (`\r` for `\r\n`); and an empty line,
/// recorded as the previous line end's start plus one, for every line end
/// that follows another line end in the same gap between two tokens with
/// no comment between them (whitespace does not break the pair). The
/// trailing commas come from the parser; here the list is empty.
pub fn trivia_extra(stream : @scanner.TokenStream) -> @ast.ModuleExtra {
  let module_comments : Array[@span.SrcSpan] = []
  let doc_comments : Array[@span.SrcSpan] = []
  let comments : Array[@span.SrcSpan] = []
  let new_lines : Array[Int32] = []
  let empty_lines : Array[Int32] = []
  fn gap(trivia : ArrayView[@scanner.Trivia]) -> Unit {
    let mut previous_newline : Int32? = None
    for t in trivia {
      match t {
        Comment(c) => {
          match c.kind {
            Regular => comments.push(c.content_span())
            Doc => doc_comments.push(c.content_span())
            Module => module_comments.push(c.content_span())
          }
          previous_newline = None
        }
        Newline(_, span) => {
          new_lines.push(span.start)
          if previous_newline is Some(start) {
            empty_lines.push(start + 1)
          }
          previous_newline = Some(span.start)
        }
        Whitespace(_, _) => ()
      }
    }
  }

  gap(stream.trivia)
  for token in stream.tokens {
    gap(token.trivia_before)
    gap(token.trivia_after)
  }
  {
    module_comments: module_comments[:],
    doc_comments: doc_comments[:],
    comments: comments[:],
    empty_lines: empty_lines[:],
    new_lines: new_lines[:],
    trailing_commas: [][:],
  }
}
