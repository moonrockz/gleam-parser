Feature: Gleam parity corpus
  The corpus script pins Hex packages: it reads the package list, finds each
  repository on Hex, and writes a manifest with the zipball hash and the
  hash of every .gleam file under src/ and test/.

  Scenario: Read package coordinates
    Given the package list:
      """
      # core
      gleam_stdlib@1.0.5

      lustre@5.7.1 github.com/lustre-labs/lustre#v5.7.1
      """
    When I read the package list
    Then the packages are "gleam_stdlib@1.0.5, lustre@5.7.1 (github.com/lustre-labs/lustre#v5.7.1)"

  Scenario: Reject a line without a version
    Given the package list:
      """
      gleam_stdlib
      """
    When I read the package list
    Then reading fails with "invalid package line: gleam_stdlib (expected name@version [github.com/owner/repo#tag])"

  Scenario: Reject an override that is not a GitHub repository
    Given the package list:
      """
      tom@2.1.0 gitlab.com/lpil/tom#v2.1.0
      """
    When I read the package list
    Then reading fails with "invalid package line: tom@2.1.0 gitlab.com/lpil/tom#v2.1.0 (expected name@version [github.com/owner/repo#tag])"

  Scenario: Find the repository in the Hex metadata
    Given the Hex metadata '{"meta": {"links": {"Repository": "https://github.com/gleam-lang/stdlib", "Website": "https://gleam.run"}}}'
    When I look for the repository of "gleam_stdlib@1.0.5"
    Then the repository is "https://github.com/gleam-lang/stdlib" with tag "v1.0.5"

  Scenario: Accept a GitHub link under another key, without the .git suffix
    Given the Hex metadata '{"meta": {"links": {"GitHub": "https://github.com/lpil/tom.git/"}}}'
    When I look for the repository of "tom@2.1.0"
    Then the repository is "https://github.com/lpil/tom" with tag "v2.1.0"

  Scenario: Stop when the Hex metadata has no GitHub link
    Given the Hex metadata '{"meta": {"links": {"Website": "https://example.com"}}}'
    When I look for the repository of "wibble@1.0.0"
    Then looking fails with "wibble@1.0.0: no GitHub repository in the Hex metadata; add github.com/owner/repo#tag to packages.txt"

  Scenario: An override wins over the Hex metadata
    Given the Hex metadata '{"meta": {"links": {"Repository": "https://github.com/a/b"}}}'
    When I look for the repository of "x@1.0.0 github.com/c/d#release-1.0.0"
    Then the repository is "https://github.com/c/d" with tag "release-1.0.0"

  Scenario: The zipball is the GitHub archive of the tag
    Then the zipball of "https://github.com/gleam-lang/stdlib" at "v1.0.5" is "https://github.com/gleam-lang/stdlib/archive/refs/tags/v1.0.5.zip"

  Scenario: Manifest entries survive a write and read
    Given a manifest entry for "gleam_stdlib@1.0.5" with file "src/gleam/list.gleam" hashed "ab"
    When I write and read the manifest
    Then the manifest entry is unchanged
    And the manifest names Gleam "1.19.2"

  Scenario: A failed download names the tag override
    Then the download failure message for "wibble@1.0.0" at "https://github.com/a/b/archive/refs/tags/v1.0.0.zip" is "wibble@1.0.0: cannot download https://github.com/a/b/archive/refs/tags/v1.0.0.zip; if the tag is not v1.0.0, add github.com/owner/repo#tag to packages.txt"
