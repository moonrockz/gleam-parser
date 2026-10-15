Feature: Syntax tree
  The node model names every node type by (category, kind) with the JSON
  vocabulary of docs/ast-json.md, and every traversal gives the same order.

  Scenario: The kind table agrees with the AST JSON schema
    When I read the kinds of the AST JSON schema
    Then every expression, pattern, constant, type, clause guard, bit array size and bit array option kind has one row in the kind table
    And every row's fields are JSON keys of the recorded fixtures

  Scenario: Every traversal visits the same nodes in the same order
    Given the Gleam module "pub fn add(a, b) {\n  case a {\n    0 -> b\n    _ -> a + b\n  }\n}\n"
    When I traverse it with walk, fold, reduce, a visitor, the event reader, push events and the cursor
    Then every traversal gives the same pre-order "module function arg arg expression case var clause int var clause discard bin_op var var"
