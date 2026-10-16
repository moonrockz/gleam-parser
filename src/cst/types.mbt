///|
/// What a definition's tokens parsed as. `Skipped` is a run of tokens the
/// parser reported and skipped (recovery per definition).
pub(all) enum DefinitionKind {
  Import
  Constant
  Function
  CustomType
  TypeAlias
  Skipped
} derive(Eq, Debug, Hash)

///|
/// The tokens of one definition, with their trivia. `name` is the module
/// path of an import, the name of a constant, function or type, or `None`
/// for a skipped run or an anonymous head. `span` runs from the first
/// token's start to the last token's end (trivia not included); `0..0`
/// when there is no token.
pub(all) struct DefinitionCst {
  kind : DefinitionKind
  name : String?
  tokens : ArrayView[@scanner.Token]
  span : @span.SrcSpan
} derive(Eq, Debug)

///|
/// Group a definition's tokens and derive its span, or `0..0` when empty.
#alias(new, deprecated="Use `DefinitionCst(...)` instead")
pub fn DefinitionCst::DefinitionCst(
  kind~ : DefinitionKind,
  name~ : String?,
  tokens~ : ArrayView[@scanner.Token],
) -> DefinitionCst {
  let span = if tokens.length() == 0 {
    @span.SrcSpan::from_ints(0, 0).unwrap()
  } else {
    @span.SrcSpan::from_compiler(
      tokens[0].span.start,
      tokens[tokens.length() - 1].span.end,
    ).unwrap()
  }
  { kind, name, tokens, span, }
}

///|
/// The text of the definition's tokens with their trivia.
pub fn DefinitionCst::to_source(self : DefinitionCst) -> String {
  let sb = StringBuilder()
  for t in self.tokens {
    sb.write_string(t.to_source())
  }
  sb.to_string()
}

///|
/// Every token of a module, grouped per definition. `definitions` tile
/// `tokens` in order; `trivia` is the stream's trivia for a text with no
/// token.
///
/// ```mbt check
/// test {
///   let stream = @scanner.tokenize_text("const x = 1\n")
///   let d = @cst.DefinitionCst(
///     kind=Constant,
///     name=Some("x"),
///     tokens=stream.tokens,
///   )
///   let cst = @cst.ModuleCst(stream, [d])
///   inspect(cst.to_source(), content="const x = 1\n")
/// }
/// ```
pub(all) struct ModuleCst {
  tokens : ArrayView[@scanner.Token]
  trivia : ArrayView[@scanner.Trivia]
  definitions : ArrayView[DefinitionCst]
} derive(Eq, Debug)

///|
/// Group a token stream with its parsed definitions and trivia.
#alias(new, deprecated="Use `ModuleCst(...)` instead")
pub fn ModuleCst::ModuleCst(
  stream : @scanner.TokenStream,
  definitions : Array[DefinitionCst],
) -> ModuleCst {
  { tokens: stream.tokens, trivia: stream.trivia, definitions: definitions[:], }
}

///|
/// The scanned text, byte for byte.
pub fn ModuleCst::to_source(self : ModuleCst) -> String {
  let sb = StringBuilder()
  for t in self.trivia {
    sb.write_string(t.text())
  }
  for token in self.tokens {
    sb.write_string(token.to_source())
  }
  sb.to_string()
}
