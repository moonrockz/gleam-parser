///|
/// Why a `\u{...}` escape is wrong (`InvalidUnicodeEscapeError` in the
/// compiler's `parse/error.rs`).
pub(all) enum UnicodeEscapeError {
  MissingOpeningBrace
  ExpectedHexDigitOrCloseBrace
  InvalidNumberOfHexDigits
  InvalidCodepoint
} derive(Eq, Debug)

///|
/// The lexical errors of the compiler's `LexicalErrorType`, one variant each.
pub(all) enum LexicalErrorType {
  BadStringEscape
  InvalidUnicodeEscape(UnicodeEscapeError)
  DigitOutOfRadix
  NumTrailingUnderscore
  RadixIntNoValue
  MissingExponent
  UnexpectedStringEnd
  UnrecognizedToken(Char)
  InvalidTripleEqual
  MergeConflictIndicator
  UnsupportedProceduralOperator
  VisuallySimilarInvalidCharacter(name~ : String, correct~ : String)
} derive(Eq, Debug)

///|
/// The variant name, as the rejection check compares it with the oracle.
pub fn LexicalErrorType::kind(self : LexicalErrorType) -> String {
  match self {
    BadStringEscape => "BadStringEscape"
    InvalidUnicodeEscape(MissingOpeningBrace) =>
      "InvalidUnicodeEscape.MissingOpeningBrace"
    InvalidUnicodeEscape(ExpectedHexDigitOrCloseBrace) =>
      "InvalidUnicodeEscape.ExpectedHexDigitOrCloseBrace"
    InvalidUnicodeEscape(InvalidNumberOfHexDigits) =>
      "InvalidUnicodeEscape.InvalidNumberOfHexDigits"
    InvalidUnicodeEscape(InvalidCodepoint) =>
      "InvalidUnicodeEscape.InvalidCodepoint"
    DigitOutOfRadix => "DigitOutOfRadix"
    NumTrailingUnderscore => "NumTrailingUnderscore"
    RadixIntNoValue => "RadixIntNoValue"
    MissingExponent => "MissingExponent"
    UnexpectedStringEnd => "UnexpectedStringEnd"
    UnrecognizedToken(_) => "UnrecognizedToken"
    InvalidTripleEqual => "InvalidTripleEqual"
    MergeConflictIndicator => "MergeConflictIndicator"
    UnsupportedProceduralOperator => "UnsupportedProceduralOperator"
    VisuallySimilarInvalidCharacter(..) => "VisuallySimilarInvalidCharacter"
  }
}

///|
/// The compiler's label text (`LexicalError::to_parse_error_info`).
pub fn LexicalErrorType::label(self : LexicalErrorType) -> String {
  match self {
    BadStringEscape => "I don't understand this escape code"
    DigitOutOfRadix => "This digit is too big for the specified radix"
    NumTrailingUnderscore => "Numbers cannot have a trailing underscore"
    RadixIntNoValue => "This integer has no value"
    MissingExponent => "This float is missing an exponent"
    UnexpectedStringEnd => "The string starting here was left open"
    UnrecognizedToken(';') => "Remove this semicolon"
    UnrecognizedToken('\'') => "Unexpected single quote"
    UnrecognizedToken(_) => "I can't figure out what to do with this character"
    InvalidUnicodeEscape(MissingOpeningBrace) =>
      "Expected '{' in Unicode escape sequence"
    InvalidUnicodeEscape(ExpectedHexDigitOrCloseBrace) =>
      "Expected hex digit or '}' in Unicode escape sequence"
    InvalidUnicodeEscape(InvalidNumberOfHexDigits) =>
      "Expected between 1 and 6 hex digits in Unicode escape sequence"
    InvalidUnicodeEscape(InvalidCodepoint) => "Invalid Unicode codepoint"
    InvalidTripleEqual => "Did you mean `==`?"
    MergeConflictIndicator => "Merge conflict marker found"
    UnsupportedProceduralOperator => "Unknown operator"
    VisuallySimilarInvalidCharacter(..) => "Unexpected character"
  }
}

///|
let merge_conflict_hint : String =
  #|Your code appears to have a merge conflict. Resolve it by removing
  #|the code you do not want to keep.
  #|If you are in a merge, the top chunk is the checked-out code, and the
  #|bottom chunk is the new code being merged.
  #|If you are in a rebase, the top chunk is the code being rebased onto,
  #|and the chunk section is the checked-out code which is being rebased.
  #|More information can be found in the official git documentation:
  #|https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging#_checking_out_conflicts

///|
let procedural_operator_hint : String =
  #|Gleam is an immutable language and does not have any operators that
  #|change the value of an existing variable. You might want to create a
  #|new variable with the same name as the previous one:
  #|    let wibble = 10
  #|    let blobby = wibble
  #|    let wibble = wibble + 20
  #|    assert wibble == 30
  #|    assert blobby == 10
  #|

///|
/// The compiler's extra lines (`to_parse_error_info`), in order.
pub fn LexicalErrorType::hints(self : LexicalErrorType) -> Array[String] {
  match self {
    BadStringEscape =>
      [
        "Hint: Add another backslash before it.", "See: https://tour.gleam.run/basics/strings",
      ]
    NumTrailingUnderscore => ["Hint: remove it."]
    MissingExponent => ["Hint: Add an exponent or remove the trailing `e`"]
    UnrecognizedToken(';') =>
      [
        "Hint: Semicolons used to be whitespace and did nothing.", "You can safely remove them without your program changing.",
      ]
    UnrecognizedToken('\'') => ["Hint: Strings are written with double quotes."]
    UnrecognizedToken(_) => ["Hint: Is it a typo?"]
    InvalidUnicodeEscape(MissingOpeningBrace) => ["Hint: Add it."]
    InvalidUnicodeEscape(ExpectedHexDigitOrCloseBrace) =>
      [
        "Hint: Hex digits are digits from 0 to 9 and letters from a to f or A to F.",
      ]
    InvalidTripleEqual =>
      [
        "Gleam uses `==` to check for equality between two values.", "See: https://tour.gleam.run/basics/equality",
      ]
    MergeConflictIndicator => [merge_conflict_hint]
    UnsupportedProceduralOperator => [procedural_operator_hint]
    VisuallySimilarInvalidCharacter(name~, correct~) =>
      [
        "This looks like ascii \{correct}, but it is actually the unicode \{name}.",
      ]
    DigitOutOfRadix
    | RadixIntNoValue
    | UnexpectedStringEnd
    | InvalidUnicodeEscape(InvalidNumberOfHexDigits)
    | InvalidUnicodeEscape(InvalidCodepoint) => []
  }
}

///|
/// The diagnostic for a lexical error at `location`, in the compiler's shape:
/// title "Syntax error", the label as the message and the primary label,
/// the hints joined with line feeds.
pub fn lexical_diagnostic(
  error : LexicalErrorType,
  location : @span.SrcSpan,
) -> @diagnostic.Diagnostic {
  let label = error.label()
  let hints = error.hints()
  @diagnostic.Diagnostic::new(
    code="GL-SCAN-001",
    kind=error.kind(),
    severity=Error,
    title="Syntax error",
    message=label,
    span=location,
    labels=[@diagnostic.Label::{ span: location, text: label, }],
    hint=if hints.is_empty() { None } else { Some(hints.join("\n")) },
  )
}
