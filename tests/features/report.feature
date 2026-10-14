Feature: Diagnostics rendered as the Gleam compiler prints them
  render_plain gives the compiler's layout: the severity and title, the
  locus, the source line with carets under the span, the text and the hint.

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
