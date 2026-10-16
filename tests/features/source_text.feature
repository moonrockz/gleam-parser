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

  Scenario Outline: Domain constructors reject values outside their range
    When I construct a "<kind>" from <value>
    Then construction "<result>"

    Examples:
      | kind          | value | result   |
      | byte offset   | -1    | fails    |
      | byte offset   | 0     | succeeds |
      | UTF-16 offset | -1    | fails    |
      | UTF-16 offset | 0     | succeeds |
      | byte length   | -1    | fails    |
      | byte length   | 0     | succeeds |
      | line number   | 0     | fails    |
      | line number   | 1     | succeeds |
      | column number | 0     | fails    |
      | column number | 1     | succeeds |
      | line count    | 0     | fails    |
      | line count    | 1     | succeeds |
      | tuple index   | -1    | fails    |
      | tuple index   | 0     | succeeds |
      | bit array unit | -1   | fails    |
      | bit array unit | 0    | succeeds |
      | bit array unit | 255  | succeeds |
      | bit array unit | 256  | fails    |
      | child index   | -1    | fails    |
      | child index   | 0     | succeeds |
      | node depth    | -1    | fails    |
      | node depth    | 0     | succeeds |
