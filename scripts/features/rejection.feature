Feature: Rejection verdicts
  The rejection script records, per fixture, the oracle's verdict: accepted,
  or the error kind, lexical kind and location of its first error.

  Scenario: A parsed oracle line is an accepting verdict
    Given the oracle line '{"extra":{},"module":{},"warnings":[]}'
    Then the verdict is '{"accepted":true}'

  Scenario: An error line keeps the kind, lexical kind and location
    Given the oracle line '{"error":{"kind":"LexError","lexical_kind":"UnexpectedStringEnd","location":{"end":14,"start":10}}}'
    Then the verdict is '{"accepted":false,"kind":"LexError","lexical_kind":"UnexpectedStringEnd","location":{"end":14,"start":10}}'

  Scenario: A malformed error line is rejected
    Given the oracle line '{"error":{"kind":"X"}}'
    Then reading the verdict fails with "oracle: malformed error"

  Scenario: Fixture paths are sorted and relative to the fixtures directory
    Given the fixture files "tests/rejection/types/alias_without_type.gleam, tests/rejection/accepted/basic.gleam, tests/rejection/README.md"
    Then the fixtures under "tests/rejection" are "accepted/basic.gleam, types/alias_without_type.gleam"

  Scenario: The verdict key names the Gleam version
    Then the verdict key for version "1.19.2" is "gleam-1.19.2"
