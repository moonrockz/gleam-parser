Feature: Diagnostics rendered as the Gleam compiler prints them
  render_plain gives the compiler's layout: the severity and title, the
  locus, the source line with carets under the span, the text and the hint.

  Scenario Outline: Unicode display widths match the compiler
    Given the compiler diagnostic fixture "<fixture>"
    When I parse it and render the first diagnostic for "/src/parse/error.gleam"
    Then the report equals the compiler fixture

    Examples:
      | fixture                               |
      | unicode_fullwidth_at_sign             |
      | unicode_fullwidth_caret               |
      | unicode_fullwidth_colon               |
      | unicode_fullwidth_comma               |
      | unicode_fullwidth_exclamation_mark    |
      | unicode_fullwidth_full_stop           |
      | unicode_fullwidth_greater_than_sign   |
      | unicode_fullwidth_left_parenthesis    |
      | unicode_fullwidth_left_square_bracket |
      | unicode_fullwidth_less_than_sign      |
      | unicode_fullwidth_right_parenthesis   |
      | unicode_fullwidth_right_square_bracket|
      | unicode_fullwidth_vertical_line       |
      | unicode_ideographic_comma             |
      | unicode_ideographic_full_stop         |
      | unicode_zero_width_space              |

  Scenario: A syntax error with a hint
    Given the Gleam source:
      """
      const no_cute_bee = "cute" <>
      """
    When I parse it and render the first diagnostic for "src/main.gleam"
    Then the report is:
      """
      error: Syntax error
        ┌─ src/main.gleam:1:28
        │
      1 │ const no_cute_bee = "cute" <>
        │                            ^^ This operator has no value on its right side

      Hint: Remove it or put a value after it.
      """

  Scenario: A deprecation warning
    Given the Gleam source:
      """
      @target(erl)
      pub fn wibble() { panic }
      """
    When I parse it and render the first diagnostic for "src/main.gleam"
    Then the report is:
      """
      warning: Deprecated target shorthand syntax
        ┌─ src/main.gleam:1:9
        │
      1 │ @target(erl)
        │         ^^^ This should be replaced with `erlang`

      This shorthand target name is deprecated. Use the full name: `erlang`
      instead.
      """
