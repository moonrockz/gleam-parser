Feature: Oracle goldens
  The goldens script runs the Rust oracle over every corpus file in the
  manifest and keeps one raw result per file: the oracle's JSON for a file
  it parses, or its error for a file it rejects.

  Scenario: Corpus keys follow the manifest
    Given the manifest:
      """
      {"gleam": "1.19.2", "packages": [
        {"name": "gleam_stdlib", "version": "1.0.5", "files": [
          {"path": "src/gleam/list.gleam", "sha256": "a"},
          {"path": "test/gleam/list_test.gleam", "sha256": "b"}]},
        {"name": "tom", "version": "2.1.0", "files": [{"path": "src/tom.gleam", "sha256": "c"}]}]}
      """
    Then the corpus keys are "gleam_stdlib@1.0.5/src/gleam/list.gleam, gleam_stdlib@1.0.5/test/gleam/list_test.gleam, tom@2.1.0/src/tom.gleam"

  Scenario: Oracle lines pair with the keys in order
    Given the oracle output:
      """
      {"extra":{},"module":{},"warnings":[]}
      {"error":{"kind":"UnexpectedEof","lexical_kind":null,"location":{"end":0,"start":0}}}
      """
    When I pair the output with the keys "a@1/src/a.gleam, a@1/src/b.gleam"
    Then the results are "a@1/src/a.gleam: parsed; a@1/src/b.gleam: rejected"

  Scenario: Fewer lines than keys is an error
    Given the oracle output:
      """
      {"extra":{},"module":{},"warnings":[]}
      """
    When I pair the output with the keys "a@1/src/a.gleam, a@1/src/b.gleam"
    Then pairing fails with "oracle: 1 results for 2 files"

  Scenario: A line that is not JSON is an error
    Given the oracle output:
      """
      thread 'main' panicked
      """
    When I pair the output with the keys "a@1/src/a.gleam"
    Then pairing fails with "oracle: not JSON for a@1/src/a.gleam"
