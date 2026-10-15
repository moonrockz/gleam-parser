Feature: Gleam parity scoreboard
  The parity check hashes gleam-parser's canonical AST JSON and compares it
  with the golden lock made from the oracle's output. Counts must never drop
  below the baseline.

  Scenario: Lock lines survive a write and read
    Given the lock text:
      """
      # comment
      pkg_b@1.0.0/src/b.gleam 22 PARSE_ERROR
      pkg_a@1.0.0/src/long/name.gleam 33 cc
      pkg_a@1.0.0/src/a.gleam 11 aa
      """
    When I read and write the lock
    Then the lock text is:
      """
      # <corpus key> <source sha256> <canonical oracle JSON sha256 | PARSE_ERROR>
      pkg_a@1.0.0/src/a.gleam 11 aa
      pkg_a@1.0.0/src/long/name.gleam 33 cc
      pkg_b@1.0.0/src/b.gleam 22 PARSE_ERROR
      """

  Scenario: Reject a malformed lock line
    Given the lock text:
      """
      pkg_a@1.0.0/src/a.gleam 11
      """
    When I read and write the lock
    Then reading the lock fails

  Scenario: The lock hashes the canonical JSON
    Given the oracle JSON '{"module": {"b": 1, "a": [2]}, "extra": {}}'
    Then the golden hash is the SHA-256 of '{"extra":{},"module":{"a":[2],"b":1}}'

  Scenario Outline: Counts below the baseline are regressions
    Given the counts <files> files, <tokenized> tokenized, <parsed> parsed, <matched> matched
    And the baseline 232 files, 10 tokenized, 5 parsed, 0 matched
    Then the regressions are "<regressions>"

    Examples:
      | files | tokenized | parsed | matched | regressions                                      |
      | 232   | 10        | 5      | 0       |                                                  |
      | 232   | 12        | 6      | 1       |                                                  |
      | 232   | 9         | 5      | 0       | tokenized: 9 < baseline 10                       |
      | 231   | 10        | 4      | 0       | files: 231 < baseline 232; parsed: 4 < baseline 5 |

  Scenario Outline: Ratchet never lowers the baseline
    Given the counts <files> files, <tokenized> tokenized, <parsed> parsed, <matched> matched
    And the baseline 232 files, 10 tokenized, 5 parsed, 0 matched
    Then ratcheting gives "<result>"

    Examples:
      | files | tokenized | parsed | matched | result                                          |
      | 232   | 12        | 5      | 1       | 232 files, 12 tokenized, 5 parsed, 1 matched    |
      | 232   | 9         | 5      | 0       | refused: tokenized: 9 < baseline 10             |

  Scenario: Lock and manifest must list the same files with the same sources
    Given the lock text:
      """
      pkg_a@1.0.0/src/a.gleam 11 aa
      pkg_b@1.0.0/src/b.gleam 99 bb
      pkg_c@1.0.0/src/c.gleam 33 cc
      """
    And the manifest sources "pkg_a@1.0.0/src/a.gleam 11, pkg_b@1.0.0/src/b.gleam 22, pkg_d@1.0.0/src/d.gleam 44"
    Then the source problems are "source hash differs from the manifest: pkg_b@1.0.0/src/b.gleam; not in the manifest: pkg_c@1.0.0/src/c.gleam; not in the lock: pkg_d@1.0.0/src/d.gleam"

  Scenario: First difference between the oracle and gleam-parser output
    Given the golden JSON '{"module": {"definitions": [{"location": {"end": 6, "start": 1}, "kind": "function"}]}}'
    And the gleam-parser JSON '{"module": {"definitions": [{"location": {"end": 7, "start": 1}, "kind": "function"}]}}'
    Then the first difference is at "$.module.definitions[0].location.end" with "6" against "7"

  Scenario: A missing key is the difference
    Given the golden JSON '{"a": 1, "b": 2}'
    And the gleam-parser JSON '{"a": 1}'
    Then the first difference is at "$.b" with '{"a":1,"b":2}' against '{"a":1}'

  Scenario: Long values are cut in the report
    Given the golden JSON '{"a": "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"}'
    And the gleam-parser JSON '{"a": "x"}'
    Then the brief form of the golden JSON has 120 characters and ends with "..."
