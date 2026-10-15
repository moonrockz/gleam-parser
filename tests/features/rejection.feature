Feature: Rejection parity
  gleam-parser accepts and rejects the fixtures as the Gleam compiler does,
  and its first error has the compiler's kind and location. Mismatches are
  listed in pending.json, which only shrinks.

  Scenario: Both accept
    Given the fixture "a.gleam" is "pub fn f() {\n  1\n}\n"
    And the oracle verdict for "a.gleam" is '{"accepted": true}'
    Then the mismatches are ""

  Scenario: Verdicts differ
    Given the fixture "a.gleam" is "pub fn f() {\n  1\n}\n"
    And the oracle verdict for "a.gleam" is '{"accepted": false, "kind": "UnexpectedEof", "lexical_kind": null, "location": {"start": 0, "end": 0}}'
    Then the mismatches are "a.gleam verdict"

  Scenario: Both reject with the same first error
    Given the fixture "a.gleam" is "pub fn f() {\n  1 +\n}\n"
    And the oracle verdict for "a.gleam" is the first error gleam-parser reports
    Then the mismatches are ""

  Scenario: Both reject, with a different error kind
    Given the fixture "a.gleam" is "pub fn f() {\n  1 +\n}\n"
    And the oracle verdict for "a.gleam" is '{"accepted": false, "kind": "UnexpectedEof", "lexical_kind": null, "location": {"start": 17, "end": 19}}'
    Then the mismatches are "a.gleam error"

  Scenario: A changed fixture must be re-recorded
    Given the fixture "a.gleam" is "pub fn f() {\n  1\n}\n"
    And the oracle verdict for "a.gleam" was recorded for another text
    Then checking fails with "a.gleam changed: run `mise run rejection:record`"

  Scenario: Pending entries round-trip sorted
    Given the pending entries "b.gleam verdict, a.gleam error, a.gleam verdict"
    When I write and read the pending list
    Then the pending entries are "a.gleam error, a.gleam verdict, b.gleam verdict"

  Scenario: Fixtures on disk and recorded verdicts must agree
    Given the oracle verdict for "a.gleam" is '{"accepted": true}'
    Then the unrecorded problems for the files "a.gleam, b/new.gleam" are "b/new.gleam not recorded: run `mise run rejection:record`"
    And the unrecorded problems for the files "" are "a.gleam removed: run `mise run rejection:record`"
