Feature: Parser configuration
  A Config comes from the defaults, a TOML text, the environment and the
  caller, merged with fallback: a set field wins over the layer below it.

  Scenario: Defaults
    When I resolve the configuration
    Then the fuel budget is 100
    And the dialect is "gleam-1.19"

  Scenario: A TOML text sets the fuel
    Given the TOML text "[parser]\nfuel = 550\n"
    When I resolve the configuration
    Then the fuel budget is 550

  Scenario: The environment wins over the TOML text
    Given the TOML text "[parser]\nfuel = 550\n"
    And the environment variable "GLEAM_PARSER_FUEL" is "2000"
    When I resolve the configuration
    Then the fuel budget is 2000

  Scenario: The caller wins over the environment
    Given the environment variable "GLEAM_PARSER_FUEL" is "2000"
    And the caller sets the fuel to 5
    When I resolve the configuration
    Then the fuel budget is 5

  Scenario Outline: A bad value is an error that names its source
    Given the TOML text "<toml>"
    And the environment variable "<variable>" is "<value>"
    When I resolve the configuration
    Then the configuration error names "<source>" with "<message>"

    Examples:
      | toml                       | variable          | value | source            | message                                   |
      | [parser]\nfuel = 0\n       |                   |       | parser.fuel       | must be at least 1                        |
      | [parser]\nfuel = 'x'\n     |                   |       | parser.fuel       | expected an integer, found a string       |
      | [parser]\nwidth = 80\n     |                   |       | parser.width      | unknown key                               |
      | [parser]\ngleam = '1.18'\n |                   |       | parser.gleam      | unknown Gleam version "1.18"; known: 1.19 |
      |                            | GLEAM_PARSER_FUEL |       | GLEAM_PARSER_FUEL | empty value                               |
      |                            | GLEAM_PARSER_FUEL | abc   | GLEAM_PARSER_FUEL | expected an integer, found "abc"          |
