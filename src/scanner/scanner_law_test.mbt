///|
/// The kind name a `TokenKind` has in `@lawkit.token_table()`.
fn kind_name(k : @scanner.TokenKind) -> String {
  match k {
    Name(_) => "Name"
    UpName(_) => "UpName"
    DiscardName(_) => "DiscardName"
    Int(..) => "Int"
    Float(..) => "Float"
    String(_) => "String"
    Error => "Error"
    // Payload-free kinds and keywords: the Debug form is the name.
    other => @debug.to_string(other)
  }
}

///|
test "law: scanned comments reconstruct through the checked constructor and slice to their content" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      ["//", "///", "////"]
      .iter()
      .all(prefix => {
        let source = @scanner.SourceText::new(prefix + t.text())
        let stream = @scanner.tokenize(source)
        let trivia = match stream.tokens.get(0) {
          Some(token) => token.trivia_before
          None => stream.trivia
        }
        guard trivia.get(0) is Some(Comment(comment)) else { return false }
        match
          @scanner.Comment::new(
            kind=comment.kind,
            content=comment.content,
            span=comment.span,
          ) {
          None => false
          Some(copy) =>
            copy == comment &&
            source.slice(copy.content_span()) == Some(copy.content)
        }
      })
    },
    count=200,
    max_size=16,
    seed=2231,
  )
}

///|
/// Edge values: empty text; a lone `\r` at the end; text that is only
/// trivia; an open string at the end; lone surrogates inside literals.
test "law: the scan is lossless for any text" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      @scanner.tokenize_text(text).to_source() == text
    },
    count=400,
    max_size=16,
    seed=2031,
  )
}

///|
test "law: token and trivia spans tile the text on code point boundaries" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      let source = @scanner.SourceText::new(text)
      let s = @scanner.tokenize(source)
      let mut at = @span.ByteOffset::zero()
      let mut ok = true
      let step = (span : @span.SrcSpan) => {
        ok = ok &&
          span.start == at &&
          span.end >= span.start &&
          source.utf16_offset_of(span.start) is Some(_) &&
          source.utf16_offset_of(span.end) is Some(_)
        at = span.end
      }
      for tr in s.trivia {
        step(tr.span())
      }
      for tok in s.tokens {
        for tr in tok.trivia_before {
          step(tr.span())
        }
        step(tok.span)
        for tr in tok.trivia_after {
          step(tr.span())
        }
      }
      ok && at == source.end_offset()
    },
    count=400,
    max_size=16,
    seed=2032,
  )
}

///|
test "law: every Error token has one diagnostic inside or at its start, and no other" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let s = @scanner.tokenize_text(t.text())
      let errors = s.tokens.iter().filter(tok => tok.kind == Error).collect()
      if errors.length() != s.diagnostics.length() {
        return false
      }
      let mut ok = true
      for i, tok in errors {
        let d = s.diagnostics[i]
        ok = ok &&
          d.code == "GL-SCAN-001" &&
          d.span.start >= tok.span.start &&
          d.span.start <= tok.span.end &&
          d.span.end <= tok.span.end
      }
      ok
    },
    count=400,
    max_size=16,
    seed=2033,
  )
}

///|
test "law: a lexeme is the source text of its span" {
  @quickcheck.check(
    (t : @lawkit.GleamText) => {
      let text = t.text()
      let source = @scanner.SourceText::new(text)
      let s = @scanner.tokenize(source)
      let mut ok = true
      for tok in s.tokens {
        match
          (
            source.utf16_offset_of(tok.span.start),
            source.utf16_offset_of(tok.span.end),
          ) {
          (Some(a), Some(b)) =>
            ok = ok &&
              text.unsafe_substring(start=a.to_int(), end=b.to_int()) ==
              tok.lexeme
          _ => ok = false
        }
      }
      ok
    },
    count=300,
    max_size=16,
    seed=2034,
  )
}

///|
test "law: valid tokens separated by spaces scan back to the same kinds and lexemes" {
  @quickcheck.check(
    (t : @lawkit.GleamTokens) => {
      let s = @scanner.tokenize_text(t.text())
      let expected = t.expected()
      s.diagnostics.length() == 0 &&
      s.tokens.length() == expected.length() &&
      ({
        let mut ok = true
        for i, tok in s.tokens {
          ok = ok &&
            kind_name(tok.kind) == expected[i] &&
            tok.lexeme == t.0[i].0
        }
        ok
      })
    },
    count=300,
    max_size=24,
    seed=2035,
  )
}

///|
test "law: scanning never panics on any UTF-16 text" {
  @quickcheck.check(
    (u : @lawkit.Units) => {
      let s = @scanner.tokenize_text(u.text())
      s.to_source() == u.text()
    },
    count=300,
    max_size=24,
    seed=2036,
  )
}
