Feature: Explicit target profiles
  Standard Gleam stays strict. Applications register optional targets explicitly.

  Scenario: Core-only parsing rejects an extension
    When I parse target-profile source:
      """
      @target(orbit)
      pub const answer = 42
      """
    Then the target-profile error is "UnknownTarget"
    And the target-profile source is lossless

  Scenario: A new target works in both annotation forms
    Given the registered target "orbit"
    When I parse target-profile source:
      """
      @target(orbit)
      @external(orbit, "space/list", "length")
      pub fn length(xs: List(a)) -> Int
      """
    Then the target-profile source parses
    And definition 0 has target "orbit"
    And definition 0 has 1 external bindings
    And target-profile JSON and formatting preserve the metadata
    And compiler-compatible export rejects the extension
    And the target-profile source is lossless

  Scenario: External bindings do not select a target
    Given the registered target "orbit"
    And the registered target "nebula"
    When I parse target-profile source:
      """
      @external(erlang, "lists", "length")
      @external(javascript, "./ffi.mjs", "length")
      @external(orbit, "space/list", "length")
      @external(nebula, "space.List", "length")
      pub fn length(xs: List(a)) -> Int
      """
    Then the target-profile source parses
    And definition 0 has target ""
    And definition 0 has 4 external bindings
    And target-profile JSON and formatting preserve the metadata

  Scenario: External types use the same binding model
    Given the registered target "orbit"
    When I parse target-profile source:
      """
      @external(orbit, "domain", "CustomerId")
      pub type CustomerId
      """
    Then the target-profile source parses
    And definition 0 has 1 external bindings
    And target-profile JSON and formatting preserve the metadata

  Scenario: Duplicate annotations recover without source loss
    Given the registered target "orbit"
    When I parse target-profile source:
      """
      @external(orbit, "a", "f")
      @external(orbit, "b", "g")
      pub fn f() -> Int

      pub const recovered = 42
      """
    Then the target-profile error is "DuplicateAttribute"
    And the target-profile source is lossless

  Scenario: Registering one extension does not enable other names
    Given the registered target "orbit"
    When I parse target-profile source:
      """
      @external(unregistered, "m", "f")
      pub fn f() -> Int
      """
    Then the target-profile error is "UnknownTarget"
    And the target-profile source is lossless
