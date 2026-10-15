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
