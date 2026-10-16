Feature: Compiler format test cases as fixtures
  `format_cases.mbtx` reads the Gleam compiler's `assert_format!` and
  `assert_format_rewrite!` cases and writes each input as a fixture.

  Scenario Outline: Decode the escapes of a Rust string literal
    When I decode the Rust literal with text "<text>"
    Then the decoded text is "<decoded>"

    Examples:
      | text          | decoded     |
      | a\nb          | a\nb        |
      | tab\there     | tab\there   |
      | back\\slash   | back\\slash |
      | \u{1F600}     | 😀          |
      | \x41          | A           |

  Scenario: Decode a raw string literal
    When I decode the Rust literal:
      """
      r#"has "quotes" and \n"#
      """
    Then the decoded text is "has \"quotes\" and \\n"

  Scenario: A backslash before a line feed skips the next line's leading whitespace
    When I decode the Rust literal:
      """
      "a\
          b"
      """
    Then the decoded text is "ab"

  Scenario: Extract the arguments of the format macros
    Given the Rust source:
      """
      #[test]
      fn imports() {
          assert_format!("import one\n");
          assert_format!(
              "import two\n"
          );
          assert_format_rewrite!("import  three\n", "import three\n");
      }

      #[test]
      fn with_let() {
          let src = "const a = 1\n";
          let expected = "const a = 1\n";
          assert_format!(expected);
          assert_format_rewrite!(&src.replace('\n', "\r\n"), expected);
          assert_format_rewrite!(src.replace('\n', "\r"), expected);
      }

      #[test]
      fn big() {
          assert_format!(format!("pub fn main() {{\n{items}\n}}\n"));
      }

      #[test]
      fn disabled() {
          //    assert_format!(
          //        "pub type Curried(element) =\n"
          //    );
      }
      """
    When I extract the cases
    Then the inputs are:
      """
      import one\n
      import two\n
      import  three\n
      const a = 1\n
      const a = 1\r\n
      const a = 1\r
      """
    And 1 case is skipped with reason "format!"

  Scenario: Fixture paths come from the file stem and the 1-based index
    When I name case 7 of "format/src/tests/imports.rs"
    Then the fixture path is "imports/007.gleam"
    When I name case 12 of "format/src/tests.rs"
    Then the fixture path is "tests/012.gleam"
