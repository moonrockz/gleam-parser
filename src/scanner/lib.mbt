///|
/// Scan Gleam source into tokens with trivia and lexical diagnostics. The
/// scan is lossless: `TokenStream::to_source()` is the text. A lexical
/// error is a `GL-SCAN-001` diagnostic with the compiler's message and one
/// `Error` token over the text it covers; scanning goes on after it.
///
/// ```mbt check
/// test {
///   let s = @scanner.tokenize(@scanner.SourceText("let x = 1"))
///   debug_inspect(
///     s.tokens.iter().map(t => t.kind).collect(),
///     content="[Keyword(Let), Name(\"x\"), Equal, Int(value=\"1\", int_value=1)]",
///   )
///   debug_inspect(s.to_source(), content="\"let x = 1\"")
/// }
/// ```
pub fn tokenize(source : SourceText) -> TokenStream {
  Lexer(source.text()).run()
}

///|
/// `tokenize` of a `SourceText` built from `text`.
pub fn tokenize_text(text : String) -> TokenStream {
  tokenize(SourceText(text))
}
