Feature: Lossless scanning of Gleam source
  gleam-parser scans Gleam v1.19.2 source into tokens with trivia. The
  trivia and the lexemes rebuild the source byte for byte. A lexical error is
  a GL-SCAN-001 diagnostic with the compiler's message, and scanning goes on.

  Scenario: A module scans to tokens and trivia
    Given the Gleam source:
      """
      //// Module docs.

      import gleam/io

      /// Docs.
      pub fn main() {
        io.println("hi")
      }
      """
    When I scan the source
    Then the scan has no diagnostics
    And the token kinds are "Keyword(Import), Name(gleam), Slash, Name(io), Keyword(Pub), Keyword(Fn), Name(main), LeftParen, RightParen, LeftBrace, Name(io), Dot, Name(println), LeftParen, String(hi), RightParen, RightBrace"
    And the trivia and lexemes rebuild the source
    And the first token has a module comment and a line break before it

  Scenario: A lexical error is reported and scanning continues
    Given the Gleam source:
      """
      let x = 'a'
      let y = 1
      """
    When I scan the source
    Then diagnostic 1 has kind "UnrecognizedToken" and message "Unexpected single quote"
    And diagnostic 1 spans bytes 8 to 8
    And the token kinds are "Keyword(Let), Name(x), Equal, Error, Name(a), Error, Keyword(Let), Name(y), Equal, Int(1)"
    And the trivia and lexemes rebuild the source

  Scenario Outline: Number literals
    Given the Gleam source '<source>'
    When I scan the source
    Then the token kinds are "<kinds>"

    Examples:
      | source  | kinds                             |
      | 0x1F    | Int(0x1F)                         |
      | -1      | Int(-1)                           |
      | x-1     | Name(x), Minus, Int(1)            |
      | x -1    | Name(x), Int(-1)                  |
      | 1.5e3   | Float(1.5e3)                      |
      | t.1.2   | Name(t), Dot, Int(1), Dot, Int(2) |
