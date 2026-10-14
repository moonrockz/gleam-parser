Feature: Canonical AST JSON
  gleam-parser's AST mirrors the Gleam compiler's untyped AST at v1.19.2.
  Decoding the oracle's JSON of a module and encoding it again gives the same
  bytes.

  Scenario Outline: Round-trip the oracle's output
    Given the AST fixture "<fixture>"
    When I decode and encode the fixture
    Then the encoded JSON equals the fixture byte for byte

    Examples:
      | fixture               |
      | empty                 |
      | comments_only         |
      | imports               |
      | constants             |
      | types                 |
      | functions             |
      | expressions           |
      | strings               |
      | deprecated_syntax     |
      | target_shorthand      |
      | error_expected_equal  |
      | error_lexical         |

  Scenario: A string fixture keeps every character
    Given the AST fixture "strings"
    When I decode the fixture
    Then constant 3 has the string value "é 𝄞 \u{1F}"
