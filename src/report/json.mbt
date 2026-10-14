///|
fn span_json(s : @span.SrcSpan) -> Json {
  {
    "start": Json::number(s.start.to_double()),
    "end": Json::number(s.end.to_double()),
  }
}

///|
/// A diagnostic as JSON (gleam-parser's own shape, key order as written):
/// `code`, `kind`, `severity` (`error`/`warning`), `title`, `message`,
/// `span`, `labels`, `text`, `hint` (string or null).
pub fn encode_diagnostic(d : @diagnostic.Diagnostic) -> Json {
  {
    "code": Json::string(d.code),
    "kind": Json::string(d.kind),
    "severity": Json::string(if d.is_error() { "error" } else { "warning" }),
    "title": Json::string(d.title),
    "message": Json::string(d.message),
    "span": span_json(d.span),
    "labels": Json::array(
      d.labels.map(l => {
        ({ "span": span_json(l.span), "text": Json::string(l.text) } : Json)
      }),
    ),
    "text": Json::string(d.text),
    "hint": match d.hint {
      Some(h) => Json::string(h)
      None => Json::null()
    },
  }
}

///|
/// Every diagnostic as a JSON array (see `encode_diagnostic`).
pub fn encode_diagnostics(ds : ArrayView[@diagnostic.Diagnostic]) -> Json {
  Json::array(ds.map(encode_diagnostic))
}
