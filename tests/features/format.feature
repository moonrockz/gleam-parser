Feature: Formatting Gleam source
  `format` writes a module as `gleam format` (1.19.2) does: 80 columns, two
  spaces of indentation, comments and empty lines kept.

  Scenario: Format a module
    Given the Gleam source "import  b\nimport a\n\npub const  x : Int  = 1\n"
    When I format it
    Then the formatted text is "import a\nimport b\n\npub const x: Int = 1\n"

  Scenario: A syntax error raises ParseFailed with every error diagnostic
    Given the Gleam source "const = 1\nconst y =\n"
    When I format it
    Then formatting fails with 2 error diagnostics

  Scenario: A module with a warning only formats
    Given the Gleam source "/// a\n// b\npub const x = 1\n"
    Then parsing gives 1 warning diagnostic and no error
    When I format it
    Then the formatted text is "/// a\n// b\n\npub const x = 1\n"

  Scenario: A constant list with a tail keeps one line
    Given the Gleam source "const x = [1, ..[]]\n"
    When I format it
    Then the formatted text is "const x = [1, ..[]]\n"

  Scenario: format_parsed gives the same text as format
    Given the Gleam source "// c\nconst x = 1\n"
    When I format it and its parse result
    Then both texts are equal

  Scenario: Every comment of the input is in the output once
    Given the Gleam source "// a\nconst x = 1\n// b\n\n/// d\nconst y = 2\n// e\n"
    When I format it
    Then the formatted text is "// a\nconst x = 1\n\n// b\n\n/// d\nconst y = 2\n// e\n"

  Scenario: A module deeper than the fuel budget fails to parse before it formats
    Given the Gleam source of 150 nested lists
    When I format it
    Then formatting fails with 1 error diagnostics
