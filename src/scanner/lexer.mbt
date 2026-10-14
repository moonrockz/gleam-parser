///|
/// A port of the compiler's `Lexer` (`compiler-core/src/parse/lexer.rs`).
/// Each method names the compiler function it ports. Differences: trivia
/// (whitespace, line breaks, comments) are collected, not dropped or
/// emitted as tokens; a lexical error becomes a diagnostic and an `Error`
/// token, and lexing continues.
priv struct Lexer {
  cursor : Cursor
  text : String
  pieces : Array[Piece]
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
/// What the lexer emits, in source order.
priv enum Piece {
  Tok(TokenKind, String, @span.SrcSpan)
  Triv(Trivia)
}

///|
fn Lexer::new(text : String) -> Lexer {
  { cursor: Cursor::new(text), text, pieces: [], diagnostics: [], }
}

///|
/// The compiler's `emit`, for a token that starts at `start_unit`/`start`
/// and ends at the cursor.
fn Lexer::emit(
  self : Lexer,
  kind : TokenKind,
  start_unit : Int32,
  start : Int32,
) -> Unit {
  self.emit_range(
    kind,
    start_unit,
    start,
    self.cursor.unit(),
    self.cursor.position(),
  )
}

///|
/// A token over an explicit range (for runs of `=`, `<` and `>` that the
/// compiler splits into pairs after reading them all).
fn Lexer::emit_range(
  self : Lexer,
  kind : TokenKind,
  start_unit : Int32,
  start : Int32,
  end_unit : Int32,
  end : Int32,
) -> Unit {
  let lexeme = self.text.unsafe_substring(start=start_unit, end=end_unit)
  self.pieces.push(Tok(kind, lexeme, @span.SrcSpan::new(start, end)))
}

///|
fn Lexer::trivia(self : Lexer, t : Trivia) -> Unit {
  self.pieces.push(Triv(t))
}

///|
/// A lexical error: the compiler stops; this lexer records the diagnostic
/// at the compiler's `location`, moves the cursor to the end of the error
/// (at least one character past its start), and emits one `Error` token
/// from `start` to there.
fn Lexer::fail(
  self : Lexer,
  error : LexicalErrorType,
  location : @span.SrcSpan,
  start_unit : Int32,
  start : Int32,
) -> Unit {
  self.diagnostics.push(lexical_diagnostic(error, location))
  let target = if location.end > location.start {
    location.end
  } else {
    location.start + 1
  }
  while self.cursor.position() < target && !self.cursor.at_end() {
    self.cursor.advance()
  }
  if self.cursor.position() <= start {
    // The error is at the cursor and nothing was consumed: take one character.
    self.cursor.advance()
  }
  self.emit(Error, start_unit, start)
}

///|
/// The compiler's `eat_single_char`.
fn Lexer::eat_single_char(self : Lexer, kind : TokenKind) -> Unit {
  let (u, p) = (self.cursor.unit(), self.cursor.position())
  self.cursor.advance()
  self.emit(kind, u, p)
}

///|
/// Whether `-` before a digit comes next (`is_number_start` for `-`).
fn Lexer::minus_starts_number(self : Lexer) -> Bool {
  self.cursor.peek() == Some('-') && is_digit_of_radix(self.cursor.peek1(), 10)
}

///|
/// The compiler's `consume_normal`: one token, or one piece of trivia, or
/// one error.
fn Lexer::consume_normal(self : Lexer) -> Unit {
  guard self.cursor.peek() is Some(c) else { return }
  let mut check_for_minus = false
  if is_upname_start(c) {
    self.lex_upname()
  } else if is_name_start(c) {
    check_for_minus = true
    self.lex_name()
  } else if is_number_start(c, self.cursor.peek1()) {
    check_for_minus = true
    self.lex_number()
  } else {
    self.consume_character(c)
  }
  if check_for_minus && self.minus_starts_number() {
    // `1-1` and `x-1` are `1 - 1` and `x - 1`.
    self.eat_single_char(Minus)
  }
}

///|
/// The compiler's `consume_character`: punctuation, operators, strings,
/// comments, whitespace, and the characters it rejects.
fn Lexer::consume_character(self : Lexer, c : Char) -> Unit {
  let (u, p) = (self.cursor.unit(), self.cursor.position())
  let span = (a : Int32, b : Int32) => @span.SrcSpan::new(a, b)
  match c {
    '@' => self.eat_single_char(At)
    '"' => self.lex_string()
    '=' => {
      self.cursor.advance()
      if self.cursor.peek() != Some('=') {
        return self.emit(Equal, u, p)
      }
      self.cursor.advance()
      if self.cursor.peek() != Some('=') {
        return self.emit(EqualEqual, u, p)
      }
      self.cursor.advance()
      let mut seen = 3
      if self.cursor.peek() != Some('=') {
        return self.fail(
          InvalidTripleEqual,
          span(p, self.cursor.position()),
          u,
          p,
        )
      }
      while true {
        if seen >= 7 {
          return self.fail(
            MergeConflictIndicator,
            span(p, self.cursor.position()),
            u,
            p,
          )
        }
        if self.cursor.peek() == Some('=') {
          self.cursor.advance()
          seen += 1
        } else {
          let mut start = p
          let mut start_unit = u
          while seen > 1 {
            self.emit_range(
              EqualEqual,
              start_unit,
              start,
              start_unit + 2,
              start + 2,
            )
            start += 2
            start_unit += 2
            seen -= 2
          }
          if seen > 0 {
            self.emit(Equal, start_unit, start)
          }
          break
        }
      }
    }
    '+' => {
      self.cursor.advance()
      match self.cursor.peek() {
        Some('.') => {
          self.cursor.advance()
          self.emit(PlusDot, u, p)
        }
        Some('=') | Some('+') => {
          self.cursor.advance()
          self.fail(
            UnsupportedProceduralOperator,
            span(p, self.cursor.position()),
            u,
            p,
          )
        }
        _ => self.emit(Plus, u, p)
      }
    }
    '*' => {
      self.cursor.advance()
      match self.cursor.peek() {
        Some('.') => {
          self.cursor.advance()
          self.emit(StarDot, u, p)
        }
        Some('=') => {
          self.cursor.advance()
          self.fail(
            UnsupportedProceduralOperator,
            span(p, self.cursor.position()),
            u,
            p,
          )
        }
        _ => self.emit(Star, u, p)
      }
    }
    '/' => {
      self.cursor.advance()
      match self.cursor.peek() {
        Some('.') => {
          self.cursor.advance()
          self.emit(SlashDot, u, p)
        }
        Some('/') => {
          self.cursor.advance()
          self.lex_comment(u, p)
        }
        Some('=') => {
          self.cursor.advance()
          self.fail(
            UnsupportedProceduralOperator,
            span(p, self.cursor.position()),
            u,
            p,
          )
        }
        _ => self.emit(Slash, u, p)
      }
    }
    '%' => {
      self.cursor.advance()
      match self.cursor.peek() {
        Some('=') => {
          self.cursor.advance()
          self.fail(
            UnsupportedProceduralOperator,
            span(p, self.cursor.position()),
            u,
            p,
          )
        }
        _ => self.emit(Percent, u, p)
      }
    }
    '|' => {
      self.cursor.advance()
      match self.cursor.peek() {
        Some('|') => {
          self.cursor.advance()
          self.emit(VbarVbar, u, p)
        }
        Some('>') => {
          self.cursor.advance()
          self.emit(Pipe, u, p)
        }
        _ => self.emit(Vbar, u, p)
      }
    }
    '&' => {
      self.cursor.advance()
      match self.cursor.peek() {
        Some('&') => {
          self.cursor.advance()
          self.emit(AmperAmper, u, p)
        }
        _ => self.fail(UnrecognizedToken('&'), span(p, p), u, p)
      }
    }
    '-' => {
      self.cursor.advance()
      match self.cursor.peek() {
        Some('.') => {
          self.cursor.advance()
          self.emit(MinusDot, u, p)
        }
        Some('>') => {
          self.cursor.advance()
          self.emit(RArrow, u, p)
        }
        // Not `-`: repeated negation is valid Gleam.
        Some('=') => {
          self.cursor.advance()
          self.fail(
            UnsupportedProceduralOperator,
            span(p, self.cursor.position()),
            u,
            p,
          )
        }
        _ => self.emit(Minus, u, p)
      }
    }
    '!' => {
      self.cursor.advance()
      if self.cursor.peek() == Some('=') {
        self.cursor.advance()
        self.emit(NotEqual, u, p)
      } else {
        self.emit(Bang, u, p)
      }
    }
    '(' => self.eat_single_char(LeftParen)
    ')' => self.eat_single_char(RightParen)
    '[' => self.eat_single_char(LeftSquare)
    ']' => self.eat_single_char(RightSquare)
    '{' => self.eat_single_char(LeftBrace)
    '}' => self.eat_single_char(RightBrace)
    ':' => self.eat_single_char(Colon)
    '<' => {
      self.cursor.advance()
      self.lex_lt(u, p)
    }
    '>' => {
      self.cursor.advance()
      self.lex_gt(u, p)
    }
    ',' => self.eat_single_char(Comma)
    '.' => {
      self.cursor.advance()
      if self.cursor.peek() == Some('.') {
        self.cursor.advance()
        self.emit(DotDot, u, p)
      } else {
        self.emit(Dot, u, p)
        self.maybe_lex_dot_access()
      }
    }
    '#' => self.eat_single_char(Hash)
    '\n' => {
      self.cursor.advance()
      self.trivia(
        Newline(self.cursor.slice(u), span(p, self.cursor.position())),
      )
    }
    ' ' | '\t' | '\u{0C}' | '\u{FEFF}' => {
      // A run of blanks is one trivia. The byte order mark is only read
      // here at offset 0 (the compiler consumes it before lexing).
      while self.cursor.peek() is Some(' ' | '\t' | '\u{0C}') {
        self.cursor.advance()
      }
      if self.cursor.unit() == u {
        self.cursor.advance()
      }
      self.trivia(
        Whitespace(self.cursor.slice(u), span(p, self.cursor.position())),
      )
    }
    _ =>
      match visually_similar(c) {
        Some((name, correct)) =>
          self.fail(
            VisuallySimilarInvalidCharacter(name~, correct~),
            span(p, p),
            u,
            p,
          )
        None => self.fail(UnrecognizedToken(c), span(p, p), u, p)
      }
  }
}

///|
/// The compiler's table of characters that look like ASCII punctuation
/// (`consume_character`), as (name, correct).
fn visually_similar(c : Char) -> (String, String)? {
  match c {
    '\u{201A}' => Some(("low single comma quotation mark", "comma"))
    '\u{FF3B}' => Some(("fullwidth left square bracket", "left square bracket"))
    '\u{FF3D}' =>
      Some(("fullwidth right square bracket", "right square bracket"))
    '\u{FF08}' => Some(("fullwidth left parenthesis", "left parenthesis"))
    '\u{FF09}' => Some(("fullwidth right parenthesis", "right parenthesis"))
    '\u{FF0E}' => Some(("fullwidth full stop", "dot"))
    '\u{3002}' => Some(("ideographic full stop", "dot"))
    '\u{FF1C}' => Some(("fullwidth less-than sign", "less-than sign"))
    '\u{FF1E}' => Some(("fullwidth greater-than sign", "greater-than sign"))
    '\u{FF5C}' => Some(("fullwidth vertical line", "pipe"))
    '\u{FF20}' => Some(("fullwidth commercial at", "at sign"))
    '\u{FF3E}' => Some(("fullwidth circumflex accent", "caret"))
    '\u{FF1A}' => Some(("fullwidth colon", "colon"))
    '\u{201C}' | '\u{201D}' => Some(("double quotation mark", "double quote"))
    '\u{2018}' | '\u{2019}' => Some(("single quotation mark", "single quote"))
    '\u{2013}' => Some(("en dash", "minus sign"))
    '\u{2014}' => Some(("em dash", "minus sign"))
    '\u{2217}' => Some(("asterisk operator", "asterisk"))
    '\u{2215}' => Some(("division slash", "forward slash"))
    '\u{00A0}' => Some(("non-breaking space", "space"))
    '\u{200B}' => Some(("zero-width space", "space"))
    '\u{0430}' => Some(("Cyrillic letter а", "latin letter a"))
    '\u{0435}' => Some(("Cyrillic letter е", "latin letter e"))
    '\u{043E}' => Some(("Cyrillic letter о", "latin letter o"))
    '\u{0440}' => Some(("Cyrillic letter р", "latin letter p"))
    '\u{1D35}' => Some(("modifier letter capital I", "latin letter I"))
    '\u{FF0C}' => Some(("fullwidth comma", "comma"))
    '\u{3001}' => Some(("ideographic comma", "comma"))
    _ => None
  }
}

///|
/// The compiler's `lex_lt`, entered after one `<`. `start` is the token
/// start; after a run of `<` the leftover single `<` starts at `start + 2k`.
fn Lexer::lex_lt(self : Lexer, start_unit : Int32, start : Int32) -> Unit {
  let span = (a : Int32, b : Int32) => @span.SrcSpan::new(a, b)
  match self.cursor.peek() {
    Some('>') => {
      self.cursor.advance()
      self.emit(Concatenate, start_unit, start)
    }
    Some('<') => {
      self.cursor.advance()
      if self.cursor.peek() != Some('<') {
        return self.emit(LtLt, start_unit, start)
      }
      self.cursor.advance()
      let mut seen = 3
      while true {
        if seen >= 7 {
          return self.fail(
            MergeConflictIndicator,
            span(start, self.cursor.position()),
            start_unit,
            start,
          )
        }
        if self.cursor.peek() == Some('<') {
          self.cursor.advance()
          seen += 1
        } else {
          let mut s = start
          let mut su = start_unit
          while seen > 1 {
            self.emit_range(LtLt, su, s, su + 2, s + 2)
            s += 2
            su += 2
            seen -= 2
          }
          if seen > 0 {
            return self.lex_lt(su, s)
          }
          return
        }
      }
    }
    Some('.') => {
      self.cursor.advance()
      self.emit(LessDot, start_unit, start)
    }
    Some('-') => {
      self.cursor.advance()
      self.emit(LArrow, start_unit, start)
    }
    Some('=') => {
      self.cursor.advance()
      if self.cursor.peek() == Some('.') {
        self.cursor.advance()
        self.emit(LessEqualDot, start_unit, start)
      } else {
        self.emit(LessEqual, start_unit, start)
      }
    }
    _ => self.emit(Less, start_unit, start)
  }
}

///|
/// The compiler's `lex_gt`, entered after one `>`.
fn Lexer::lex_gt(self : Lexer, start_unit : Int32, start : Int32) -> Unit {
  let span = (a : Int32, b : Int32) => @span.SrcSpan::new(a, b)
  match self.cursor.peek() {
    Some('>') => {
      self.cursor.advance()
      if self.cursor.peek() != Some('>') {
        return self.emit(GtGt, start_unit, start)
      }
      self.cursor.advance()
      let mut seen = 3
      while true {
        if seen >= 7 {
          return self.fail(
            MergeConflictIndicator,
            span(start, self.cursor.position()),
            start_unit,
            start,
          )
        }
        if self.cursor.peek() == Some('>') {
          self.cursor.advance()
          seen += 1
        } else {
          let mut s = start
          let mut su = start_unit
          while seen > 1 {
            self.emit_range(GtGt, su, s, su + 2, s + 2)
            s += 2
            su += 2
            seen -= 2
          }
          if seen > 0 {
            return self.lex_gt(su, s)
          }
          return
        }
      }
    }
    Some('.') => {
      self.cursor.advance()
      self.emit(GreaterDot, start_unit, start)
    }
    Some('=') => {
      self.cursor.advance()
      if self.cursor.peek() == Some('.') {
        self.cursor.advance()
        self.emit(GreaterEqualDot, start_unit, start)
      } else {
        self.emit(GreaterEqual, start_unit, start)
      }
    }
    _ => self.emit(Greater, start_unit, start)
  }
}

///|
/// The compiler's `is_name_start`, `is_upname_start`, `is_number_start`.
fn is_name_start(c : Char) -> Bool {
  c == '_' || (c >= 'a' && c <= 'z')
}

///|
fn is_upname_start(c : Char) -> Bool {
  c >= 'A' && c <= 'Z'
}

///|
fn is_number_start(c : Char, c1 : Char?) -> Bool {
  if c >= '0' && c <= '9' {
    true
  } else if c == '-' {
    is_digit_of_radix(c1, 10)
  } else {
    false
  }
}

///|
/// Placeholders until Tasks 6 to 8 write them. Each consumes one character
/// as an `Error`, so the stream stays lossless meanwhile.
fn Lexer::lex_name(self : Lexer) -> Unit {
  self.not_yet()
}

///|
fn Lexer::lex_upname(self : Lexer) -> Unit {
  self.not_yet()
}

///|
fn Lexer::lex_number(self : Lexer) -> Unit {
  self.not_yet()
}

///|
fn Lexer::maybe_lex_dot_access(self : Lexer) -> Unit {
  ()
}

///|
fn Lexer::lex_string(self : Lexer) -> Unit {
  self.not_yet()
}

///|
fn Lexer::lex_comment(self : Lexer, start_unit : Int32, start : Int32) -> Unit {
  ignore(start_unit)
  ignore(start)
  self.not_yet()
}

///|
fn Lexer::not_yet(self : Lexer) -> Unit {
  let (u, p) = (self.cursor.unit(), self.cursor.position())
  self.cursor.advance()
  self.emit(Error, u, p)
}

///|
/// Lex the whole text (the compiler's iterator), then attach the trivia:
/// all trivia before a token goes to that token; the trivia after the last
/// token goes to it; with no token, to the stream.
fn Lexer::run(self : Lexer) -> TokenStream {
  while !self.cursor.at_end() {
    let before = self.cursor.unit()
    self.consume_normal()
    if self.cursor.unit() == before {
      // Never loop in place: the compiler's lexer always consumes here.
      self.not_yet()
    }
  }
  let tokens : Array[Token] = []
  let pending : Array[Trivia] = []
  for piece in self.pieces {
    match piece {
      Triv(t) => pending.push(t)
      Tok(kind, lexeme, span) => {
        tokens.push({
          kind,
          lexeme,
          span,
          trivia_before: pending.copy()[:],
          trivia_after: [][:],
        })
        pending.clear()
      }
    }
  }
  if tokens.length() > 0 && pending.length() > 0 {
    let last = tokens[tokens.length() - 1]
    tokens[tokens.length() - 1] = { ..last, trivia_after: pending.copy()[:], }
    pending.clear()
  }
  { tokens: tokens[:], trivia: pending[:], diagnostics: self.diagnostics[:], }
}
