Feature: Diagnostic codes
  Every diagnostic has a code from a fixed table; the table in AGENTS.md and
  the code agree.

  Scenario Outline: Known codes have descriptions
    When I look up the diagnostic code "<code>"
    Then the description is "<description>"

    Examples:
      | code         | description                                            |
      | GL-SCAN-001  | Lexical error (the message names the LexicalErrorType) |
      | GL-PARSE-001 | Syntax error (the message names the ParseErrorType)    |
      | GL-PARSE-002 | Deprecated syntax (warning)                            |
      | GL-PARSE-003 | Detached doc comment (warning)                         |
      | GL-PARSE-004 | Too much nesting                                       |

  Scenario: Unknown codes have no description
    When I look up the diagnostic code "GL-NOPE-999"
    Then there is no description
