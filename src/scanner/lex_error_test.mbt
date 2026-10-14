///|
fn diag(e : @scanner.LexicalErrorType) -> @diagnostic.Diagnostic {
  @scanner.lexical_diagnostic(e, @span.SrcSpan::new(3, 4))
}

///|
test "a lexical diagnostic has the compiler's label, kind and hint" {
  let d = diag(BadStringEscape)
  @expect.expect_all(e => {
    e.expect(d.code).to_equal("GL-SCAN-001")
    e.expect(d.kind).to_equal("BadStringEscape")
    e.expect(d.title).to_equal("Syntax error")
    e.expect(d.message).to_equal("I don't understand this escape code")
    e
    .expect(d.hint)
    .to_equal(
      Some(
        "Hint: Add another backslash before it.\nSee: https://tour.gleam.run/basics/strings",
      ),
    )
    e.expect(d.span).to_equal(@span.SrcSpan::new(3, 4))
    e.expect(d.severity).to_equal(@diagnostic.Severity::Error)
    e.expect(d.labels.length()).to_equal(1)
    e.expect(d.labels[0].text).to_equal("I don't understand this escape code")
  })
}

///|
test "errors without hints have hint None" {
  @expect.expect_all(e => {
    e.expect(diag(DigitOutOfRadix).hint).to_equal(None)
    e
    .expect(diag(DigitOutOfRadix).message)
    .to_equal("This digit is too big for the specified radix")
    e
    .expect(diag(RadixIntNoValue).message)
    .to_equal("This integer has no value")
    e
    .expect(diag(UnexpectedStringEnd).message)
    .to_equal("The string starting here was left open")
    e
    .expect(diag(InvalidUnicodeEscape(InvalidNumberOfHexDigits)).message)
    .to_equal("Expected between 1 and 6 hex digits in Unicode escape sequence")
    e
    .expect(diag(InvalidUnicodeEscape(InvalidCodepoint)).message)
    .to_equal("Invalid Unicode codepoint")
  })
}

///|
test "unrecognized token messages depend on the character" {
  @expect.expect_all(e => {
    e
    .expect(diag(UnrecognizedToken(';')).message)
    .to_equal("Remove this semicolon")
    e
    .expect(diag(UnrecognizedToken(';')).hint)
    .to_equal(
      Some(
        "Hint: Semicolons used to be whitespace and did nothing.\nYou can safely remove them without your program changing.",
      ),
    )
    e
    .expect(diag(UnrecognizedToken('\'')).message)
    .to_equal("Unexpected single quote")
    e
    .expect(diag(UnrecognizedToken('\'')).hint)
    .to_equal(Some("Hint: Strings are written with double quotes."))
    e
    .expect(diag(UnrecognizedToken('&')).message)
    .to_equal("I can't figure out what to do with this character")
    e
    .expect(diag(UnrecognizedToken('&')).hint)
    .to_equal(Some("Hint: Is it a typo?"))
    e.expect(diag(UnrecognizedToken('&')).kind).to_equal("UnrecognizedToken")
  })
}

///|
test "the remaining messages match the compiler" {
  @expect.expect_all(e => {
    e
    .expect(diag(NumTrailingUnderscore).message)
    .to_equal("Numbers cannot have a trailing underscore")
    e
    .expect(diag(NumTrailingUnderscore).hint)
    .to_equal(Some("Hint: remove it."))
    e
    .expect(diag(MissingExponent).message)
    .to_equal("This float is missing an exponent")
    e
    .expect(diag(MissingExponent).hint)
    .to_equal(Some("Hint: Add an exponent or remove the trailing `e`"))
    e
    .expect(diag(InvalidUnicodeEscape(MissingOpeningBrace)).message)
    .to_equal("Expected '{' in Unicode escape sequence")
    e
    .expect(diag(InvalidUnicodeEscape(MissingOpeningBrace)).hint)
    .to_equal(Some("Hint: Add it."))
    e
    .expect(diag(InvalidUnicodeEscape(MissingOpeningBrace)).kind)
    .to_equal("InvalidUnicodeEscape.MissingOpeningBrace")
    e
    .expect(diag(InvalidUnicodeEscape(ExpectedHexDigitOrCloseBrace)).message)
    .to_equal("Expected hex digit or '}' in Unicode escape sequence")
    e
    .expect(diag(InvalidUnicodeEscape(ExpectedHexDigitOrCloseBrace)).hint)
    .to_equal(
      Some(
        "Hint: Hex digits are digits from 0 to 9 and letters from a to f or A to F.",
      ),
    )
    e.expect(diag(InvalidTripleEqual).message).to_equal("Did you mean `==`?")
    e
    .expect(diag(InvalidTripleEqual).hint)
    .to_equal(
      Some(
        "Gleam uses `==` to check for equality between two values.\nSee: https://tour.gleam.run/basics/equality",
      ),
    )
    e
    .expect(diag(MergeConflictIndicator).message)
    .to_equal("Merge conflict marker found")
    e
    .expect(diag(MergeConflictIndicator).hint)
    .to_equal(
      Some(
        (
          #|Your code appears to have a merge conflict. Resolve it by removing
          #|the code you do not want to keep.
          #|
          #|If you are in a merge, the top chunk is the checked-out code, and the
          #|bottom chunk is the new code being merged.
          #|
          #|If you are in a rebase, the top chunk is the code being rebased onto,
          #|and the chunk section is the checked-out code which is being rebased.
          #|
          #|More information can be found in the official git documentation:
          #|https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging#_checking_out_conflicts
        ),
      ),
    )
    e
    .expect(diag(UnsupportedProceduralOperator).message)
    .to_equal("Unknown operator")
    e
    .expect(diag(UnsupportedProceduralOperator).hint)
    .to_equal(
      Some(
        (
          #|Gleam is an immutable language and does not have any operators that
          #|change the value of an existing variable. You might want to create a
          #|new variable with the same name as the previous one:
          #|
          #|    let wibble = 10
          #|    let blobby = wibble
          #|    let wibble = wibble + 20
          #|    assert wibble == 30
          #|    assert blobby == 10
          #|
        ),
      ),
    )
    e
    .expect(
      diag(
        VisuallySimilarInvalidCharacter(name="en dash", correct="minus sign"),
      ).hint,
    )
    .to_equal(
      Some(
        "This looks like ascii minus sign, but it is actually the unicode en dash.",
      ),
    )
    e
    .expect(
      diag(
        VisuallySimilarInvalidCharacter(
          name="non-breaking space",
          correct="space",
        ),
      ).message,
    )
    .to_equal("Unexpected character")
    e
    .expect(
      diag(
        VisuallySimilarInvalidCharacter(
          name="non-breaking space",
          correct="space",
        ),
      ).hint,
    )
    .to_equal(
      Some(
        "This looks like ascii space, but it is actually the unicode non-breaking\nspace.",
      ),
    )
  })
}
