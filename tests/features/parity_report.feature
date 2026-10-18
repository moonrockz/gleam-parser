Feature: Parity reports
  The parity check writes its results as JSON, JUnit XML, HTML and a Markdown
  summary, so CI runs can attach them as build reports.

  Background:
    Given a parity run with baseline 3 files, 2 tokenized, 1 parsed, 0 matched
    And the file "gleam_stdlib@1.0.5/src/gleam/list.gleam" matched
    And the file "gleam_stdlib@1.0.5/src/gleam/int.gleam" parsed but differs at "$.module.definitions[0].location.end"
    And the file "lustre@5.7.1/src/lustre.gleam" failed with "GL-SCAN-001" at "12:5" "Invalid <char> & more"

  Scenario: JSON report carries counts, baseline delta and every file
    When I render the JSON report
    Then the JSON counts are 3 files, 3 tokenized, 2 parsed, 1 matched
    And the JSON delta is 0 files, 1 tokenized, 1 parsed, 1 matched
    And the JSON report lists 3 files
    And the JSON report names the pinned Gleam version
    And JSON file "lustre@5.7.1/src/lustre.gleam" has diagnostic "GL-SCAN-001"

  Scenario: JUnit report groups files by package and skips unmatched files
    When I render the JUnit report
    Then the JUnit report has a testsuite "gleam_stdlib@1.0.5" with 2 tests and 1 skipped
    And the JUnit report has a testsuite "lustre@5.7.1" with 1 tests and 1 skipped
    And the JUnit report contains 'message="GL-SCAN-001 at 12:5: Invalid &lt;char&gt; &amp; more"'
    And the JUnit report contains 'message="differs from the oracle at $.module.definitions[0].location.end"'
    And the JUnit baseline testcase passes

  Scenario: JUnit report fails the baseline testcase on a regression
    Given the baseline was 3 files, 3 tokenized, 2 parsed, 2 matched
    When I render the JUnit report
    Then the JUnit report contains '<failure message="matched: 1 &lt; baseline 2"'

  Scenario: HTML report shows count tiles and one row per file
    When I render the HTML report
    Then the HTML report contains "<title>Gleam parity</title>"
    And the HTML report contains 'data-status="matched"'
    And the HTML report contains 'data-status="parsed"'
    And the HTML report contains 'data-status="failing"'
    And the HTML report contains "Invalid &lt;char&gt; &amp; more"
    And the HTML report has 3 file rows

  Scenario: Markdown summary compares counts with the baseline
    When I render the Markdown summary
    Then the summary contains "| Matched | 1 | 0 | +1 |"
    And the summary contains "| Code | Description | Files |"
    And the summary contains "| GL-SCAN-001 | Lexical error (the message names the LexicalErrorType) | 1 |"

  Scenario: Failure codes table covers every failure code, most frequent first
    Given the file "gleam_stdlib@1.0.5/src/gleam/bool.gleam" failed with "GL-PARSE-001" at "3:1" "Syntax error: UnexpectedToken"
    And the file "gleam_stdlib@1.0.5/src/gleam/dict.gleam" failed with "GL-PARSE-001" at "4:1" "Syntax error: UnexpectedToken"
    When I render the Markdown summary
    Then the summary contains "| GL-PARSE-001 | Syntax error (the message names the ParseErrorType) | 2 |"
    And the summary lists "GL-PARSE-001" before "GL-SCAN-001"
