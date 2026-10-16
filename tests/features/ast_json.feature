Feature: Canonical AST JSON
  gleam-parser's AST mirrors the Gleam compiler's untyped AST at v1.19.2.
  Decoding the oracle's JSON of a module and encoding it again gives the same
  bytes.

  Scenario Outline: Round-trip the oracle's output
    Given the AST fixture "<fixture>"
    When I decode and encode the fixture
    Then the encoded JSON equals the fixture byte for byte

    Examples:
      | fixture                     |
      | empty                       |
      | comments_only               |
      | imports                     |
      | constants                   |
      | types                       |
      | functions                   |
      | expressions                 |
      | strings                     |
      | deprecated_syntax           |
      | target_shorthand            |
      | patterns                    |
      | bit_arrays                  |
      | guards                      |
      | use_pipes                   |
      | records                     |
      | imports_full                |
      | attributes                  |
      | doc_comments                |
      | crlf                        |
      | trailing_commas             |
      | nested                      |
      | edge_forms                  |
      | error_expected_equal        |
      | error_lexical               |
      | error_unexpected_eof        |
      | error_op_naked_right        |
      | error_no_let_binding        |
      | error_if_expression         |
      | error_lpar                  |
      | error_incorrect_name        |
      | error_unknown_attribute     |
      | error_duplicate_attribute   |
      | error_list_spreads          |
      | error_record_constructor    |
      | error_angle_generics        |
      | error_concat_pattern        |
      | error_extra_separator       |
      | error_remaining_input       |
      | error_lexical_in_body       |
      | error_expected_function     |
      | error_expected_definition   |
      | error_type_angle_definition |
      | error_redundant_internal    |
      | error_opaque_alias          |
      | error_import_separator      |
      | error_fn_in_type            |
      | error_call_in_guard         |

  Scenario: A string fixture keeps every character
    Given the AST fixture "strings"
    When I decode the fixture
    Then constant 3 has the string value "é 𝄞 \u{1F}"

  Scenario Outline: Malformed scalar values report their JSON path
    Given the expression JSON:
      """
      <json>
      """
    When I decode the expression
    Then the decode error is "<error>"

    Examples:
      | json | error |
      | {"kind":"var","location":{"start":-1,"end":0},"name":"x"} | $.location.start: expected a non-negative integer, found -1 |
      | {"kind":"tuple_index","location":{"start":0,"end":1},"index":-1,"tuple":{"kind":"var","location":{"start":0,"end":1},"name":"x"}} | $.index: expected an unsigned 64-bit integer, found -1 |
      | {"kind":"bit_array","location":{"start":0,"end":1},"segments":[{"location":{"start":0,"end":1},"value":{"kind":"var","location":{"start":0,"end":1},"name":"x"},"options":[{"kind":"unit","location":{"start":0,"end":1},"value":256}]}]} | $.segments[0].options[0].value: expected an integer in 0..255, found 256 |
      | {"kind":"int","location":{"start":0,"end":1},"value":"1","int_value":"01"} | $.int_value: not a canonical decimal integer |
      | {"kind":"float","location":{"start":0,"end":1},"value":"1e3"} | $.value: not a float literal |
