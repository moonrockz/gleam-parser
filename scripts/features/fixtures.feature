Feature: Fixture recording
  The recorder writes the oracle's JSON next to each .gleam fixture, in
  sorted order, and ignores other files.

  Scenario: Pair .gleam files with .json outputs
    Given the fixture directory "tests/fixtures/ast"
    And it holds the files "b.gleam, README.md, a.gleam, a.json"
    When I pair the fixtures
    Then the pairs are "tests/fixtures/ast/a.gleam -> tests/fixtures/ast/a.json; tests/fixtures/ast/b.gleam -> tests/fixtures/ast/b.json"
