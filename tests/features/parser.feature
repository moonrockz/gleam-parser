Feature: Parser parity with the Gleam compiler
  gleam-parser parses the fixtures as gleam-core v1.19.2 does: the canonical
  JSON of the AST, extra and warnings is the oracle's, byte for byte; a
  file the compiler rejects gives the compiler's first error kind and span.

  Scenario Outline: A fixture parses to the oracle's JSON
    Given the Gleam fixture "<fixture>"
    When I parse the fixture
    Then there is no error diagnostic
    And the parse result's canonical JSON equals the fixture
    And the CST rebuilds the source

    Examples:
      | fixture           |
      | empty             |
      | comments_only     |
      | imports           |
      | constants         |
      | types             |
      | functions         |
      | expressions       |
      | strings           |
      | deprecated_syntax |
      | target_shorthand  |
      | patterns          |
      | bit_arrays        |
      | guards            |
      | use_pipes         |
      | records           |
      | imports_full      |
      | attributes        |
      | doc_comments      |
      | crlf              |
      | trailing_commas   |
      | nested            |

  Scenario Outline: An error fixture gives the oracle's first error
    Given the Gleam fixture "<fixture>"
    When I parse the fixture
    Then the first error diagnostic is the oracle's error
    And the CST rebuilds the source

    Examples:
      | fixture                       |
      | error_expected_equal          |
      | error_lexical                 |
      | error_unexpected_eof          |
      | error_op_naked_right          |
      | error_no_let_binding          |
      | error_if_expression           |
      | error_lpar                    |
      | error_incorrect_name          |
      | error_unknown_attribute       |
      | error_duplicate_attribute     |
      | error_list_spreads            |
      | error_record_constructor      |
      | error_angle_generics          |
      | error_concat_pattern          |
      | error_extra_separator         |
      | error_remaining_input         |
      | error_lexical_in_body         |
      | error_expected_function       |
      | error_expected_definition     |
      | error_type_angle_definition   |
      | error_redundant_internal      |
      | error_opaque_alias            |
      | error_import_separator        |
      | error_fn_in_type              |
      | error_call_in_guard           |
