///|
/// What the oracle (`tools/gleam-ast-oracle`) writes for one file: the
/// parse result, or the compiler's first parse error. `kind` is the
/// `ParseErrorType` variant name; for `LexError`, `lexical_kind` is the
/// `LexicalErrorType` name as `@scanner.LexicalErrorType::kind()` gives it.
pub(all) enum OracleOutput {
  Parsed(Parsed)
  Error(kind~ : String, lexical_kind~ : String?, location~ : @span.SrcSpan)
} derive(Eq, Debug)

///|
/// Encode a parsed module or the compiler's first error.
/// Use `canonical` to write the JSON text, then add a line feed for oracle output.
///
/// ```mbt check
/// test {
///   let value : @ast.OracleOutput = Error(
///     kind="UnexpectedEof",
///     lexical_kind=None,
///     location=@span.SrcSpan::new(0, 0),
///   )
///   assert_eq(@ast.decode_oracle_output(@ast.encode_oracle_output(value)), value)
/// }
/// ```
pub fn encode_oracle_output(o : OracleOutput) -> Json {
  match o {
    Parsed(p) => encode_parsed(p)
    Error(kind~, lexical_kind~, location~) =>
      obj([
        (
          "error",
          obj([
            ("kind", str(kind)),
            ("lexical_kind", opt(lexical_kind, str)),
            ("location", encode_span(location)),
          ]),
        ),
      ])
  }
}

///|
/// Decode the oracle's parsed module or first-error object.
/// An `error` field selects the error form. Otherwise, decode a parsed module.
/// Raise `DecodeError` with the field path for malformed input.
pub fn decode_oracle_output(json : Json) -> OracleOutput raise DecodeError {
  let m = dec_object(json, Root)
  match m.get("error") {
    Some(e) => {
      let path = Key(Root, "error")
      Error(
        kind=dec_field(e, path, "kind", dec_string),
        lexical_kind=dec_field(e, path, "lexical_kind", (v, p) => {
          dec_nullable(v, p, dec_string)
        }),
        location=dec_field(e, path, "location", dec_span),
      )
    }
    None => Parsed(decode_parsed(json))
  }
}
