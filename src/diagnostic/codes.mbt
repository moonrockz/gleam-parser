///|
/// The diagnostic codes and their descriptions, in the order of the table in
/// AGENTS.md > Diagnostics. Keep the two in step.
let table : Array[(String, String)] = [
  ("GL-SCAN-001", "Lexical error (the message names the LexicalErrorType)"),
  ("GL-PARSE-001", "Syntax error (the message names the ParseErrorType)"),
  ("GL-PARSE-002", "Deprecated syntax (warning)"),
  ("GL-PARSE-003", "Detached doc comment (warning)"),
  ("GL-PARSE-004", "Too much nesting"),
]

///|
/// Every diagnostic code, in table order.
pub fn codes() -> ArrayView[String] {
  table.map(entry => entry.0)[:]
}

///|
/// The one-line description of a code, or `None` for an unknown code.
pub fn description(code : String) -> String? {
  for entry in table {
    if entry.0 == code {
      return Some(entry.1)
    }
  }
  None
}
