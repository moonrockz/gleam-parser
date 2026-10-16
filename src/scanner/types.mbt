///|
/// The reserved words of Gleam v1.19.2 (`string_to_keyword` in the
/// compiler's lexer), in alphabetical order.
pub(all) enum Keyword {
  As
  Assert
  Auto
  Case
  Const
  Delegate
  Derive
  Echo
  Else
  Fn
  If
  Implement
  Import
  Let
  Macro
  Opaque
  Panic
  Pub
  Test
  Todo
  Type
  Use
} derive(Eq, Debug, Hash)

///|
/// The keyword for `word`, or `None` when `word` is not reserved.
pub fn Keyword::of(word : String) -> Keyword? {
  match word {
    "as" => Some(As)
    "assert" => Some(Assert)
    "auto" => Some(Auto)
    "case" => Some(Case)
    "const" => Some(Const)
    "delegate" => Some(Delegate)
    "derive" => Some(Derive)
    "echo" => Some(Echo)
    "else" => Some(Else)
    "fn" => Some(Fn)
    "if" => Some(If)
    "implement" => Some(Implement)
    "import" => Some(Import)
    "let" => Some(Let)
    "macro" => Some(Macro)
    "opaque" => Some(Opaque)
    "panic" => Some(Panic)
    "pub" => Some(Pub)
    "test" => Some(Test)
    "todo" => Some(Todo)
    "type" => Some(Type)
    "use" => Some(Use)
    _ => None
  }
}

///|
/// The source text of the keyword.
pub fn Keyword::text(self : Keyword) -> String {
  match self {
    As => "as"
    Assert => "assert"
    Auto => "auto"
    Case => "case"
    Const => "const"
    Delegate => "delegate"
    Derive => "derive"
    Echo => "echo"
    Else => "else"
    Fn => "fn"
    If => "if"
    Implement => "implement"
    Import => "import"
    Let => "let"
    Macro => "macro"
    Opaque => "opaque"
    Panic => "panic"
    Pub => "pub"
    Test => "test"
    Todo => "todo"
    Type => "type"
    Use => "use"
  }
}

///|
/// The token kinds of the compiler's `Token`, without the four trivia kinds
/// (`CommentNormal`, `CommentDoc`, `CommentModule`, `NewLine`), which are
/// `Trivia` here, and without `EndOfFile`. `Error` is the text that a
/// lexical error covers; the compiler stops there, this scanner goes on.
pub(all) enum TokenKind {
  Name(String)
  UpName(String)
  DiscardName(String)
  /// `value` is the lexeme with its sign, radix prefix and `_` separators;
  /// `int_value` is the number.
  Int(value~ : String, int_value~ : BigInt)
  /// `value` is the lexeme (with `_` separators); `float_value` the number,
  /// infinity when the literal is too big.
  Float(value~ : String, float_value~ : Double)
  /// The text between the quotes, escapes kept as written, `\r\n` and lone
  /// `\r` replaced by `\n` (as the compiler does).
  String(String)
  LeftParen
  RightParen
  LeftSquare
  RightSquare
  LeftBrace
  RightBrace
  Plus
  Minus
  Star
  Slash
  Less
  Greater
  LessEqual
  GreaterEqual
  Percent
  PlusDot
  MinusDot
  StarDot
  SlashDot
  LessDot
  GreaterDot
  LessEqualDot
  GreaterEqualDot
  Concatenate
  Colon
  Comma
  Hash
  Bang
  Equal
  EqualEqual
  NotEqual
  Vbar
  VbarVbar
  AmperAmper
  LtLt
  GtGt
  Pipe
  Dot
  RArrow
  LArrow
  DotDot
  At
  Keyword(Keyword)
  Error
} derive(Eq, Debug)

///|
/// The three comment forms: `//`, `///` (documentation) and `////`
/// (module documentation).
pub(all) enum CommentKind {
  Regular
  Doc
  Module
} derive(Eq, Debug, Hash)

///|
/// The number of slashes that start the comment.
pub fn CommentKind::prefix_length(self : CommentKind) -> @span.ByteLength {
  let length = match self {
    Regular => 2
    Doc => 3
    Module => 4
  }
  @span.ByteLength::new(length).unwrap()
}

///|
/// A comment. `span` covers the slashes and the text up to the line break
/// (not included); `content` is the text after the slashes.
pub(all) struct Comment {
  kind : CommentKind
  content : String
  span : @span.SrcSpan
} derive(Eq, Debug)

///|
/// The compiler's span for the comment: its content, without the slashes.
pub fn Comment::content_span(self : Comment) -> @span.SrcSpan {
  @span.SrcSpan::from_compiler(
    self.span.start.shift(self.kind.prefix_length().to_int()).unwrap(),
    self.span.end,
  ).unwrap()
}

///|
/// Text between tokens. `Whitespace` is a run of spaces, tabs and form
/// feeds, with the byte order mark when the text starts with one (a byte
/// order mark anywhere else is an unknown character, as in the compiler);
/// `Newline` is one `\n`, `\r\n` or `\r`; a `Comment` runs to the end of its
/// line.
pub(all) enum Trivia {
  Whitespace(String, @span.SrcSpan)
  Newline(String, @span.SrcSpan)
  Comment(Comment)
} derive(Eq, Debug)

///|
/// The source text of the trivia.
pub fn Trivia::text(self : Trivia) -> String {
  match self {
    Whitespace(text, _) | Newline(text, _) => text
    Comment(c) => {
      let slashes = match c.kind {
        Regular => "//"
        Doc => "///"
        Module => "////"
      }
      slashes + c.content
    }
  }
}

///|
pub fn Trivia::span(self : Trivia) -> @span.SrcSpan {
  match self {
    Whitespace(_, span) | Newline(_, span) => span
    Comment(c) => c.span
  }
}

///|
/// A token with the trivia around it. All trivia before a token is its
/// `trivia_before`; `trivia_after` is empty except for the last token of a
/// stream, which holds the trivia to the end of the text.
pub(all) struct Token {
  kind : TokenKind
  lexeme : String
  span : @span.SrcSpan
  trivia_before : ArrayView[Trivia]
  trivia_after : ArrayView[Trivia]
} derive(Eq, Debug)

///|
/// `trivia_before`, the lexeme and `trivia_after`, as in the source.
pub fn Token::to_source(self : Token) -> String {
  let sb = StringBuilder()
  for t in self.trivia_before {
    sb.write_string(t.text())
  }
  sb.write_string(self.lexeme)
  for t in self.trivia_after {
    sb.write_string(t.text())
  }
  sb.to_string()
}

///|
/// The result of a scan. `trivia` is the trivia of a text with no tokens
/// and empty otherwise. `diagnostics` are the lexical errors in source
/// order; each has one `Error` token in `tokens`.
pub(all) struct TokenStream {
  tokens : ArrayView[Token]
  trivia : ArrayView[Trivia]
  diagnostics : ArrayView[@diagnostic.Diagnostic]
} derive(Eq, Debug)

///|
/// The scanned text, byte for byte.
pub fn TokenStream::to_source(self : TokenStream) -> String {
  let sb = StringBuilder()
  for t in self.trivia {
    sb.write_string(t.text())
  }
  for token in self.tokens {
    sb.write_string(token.to_source())
  }
  sb.to_string()
}

///|
/// Whether any diagnostic has severity `Error`.
pub fn TokenStream::has_errors(self : TokenStream) -> Bool {
  self.diagnostics.iter().any(d => d.is_error())
}
