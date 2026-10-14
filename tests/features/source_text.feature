Feature: Source text positions
  gleam-parser keeps spans as UTF-8 byte offsets, as the Gleam compiler does,
  and maps them to 1-based lines and columns that count code points.

  Scenario Outline: Position of a byte offset
    Given the source text '<text>'
    When I look up byte offset <byte>
    Then the position is line <line> column <column>

    Examples:
      | text      | byte | line | column |
      | ab\ncd    | 3    | 2    | 1      |
      | a\r\nb    | 3    | 2    | 1      |
      | a\rb      | 2    | 2    | 1      |
      | é!        | 2    | 1    | 2      |
      | 𝄞x        | 4    | 1    | 2      |

  Scenario: A byte inside a character has no position
    Given the source text 'é'
    When I look up byte offset 1
    Then there is no position
