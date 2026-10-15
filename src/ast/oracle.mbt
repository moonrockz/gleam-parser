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
