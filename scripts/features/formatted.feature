Feature: Record gleam format's output
  `formatted.mbtx` runs the `gleam` binary on every fixture and every
  corpus file and records the outputs.

  Scenario: A fixture's output file sits next to it
    When I name the output of "tests/fixtures/format/imports/007.gleam"
    Then the output path is "tests/fixtures/format/imports/007.formatted.gleam"

  Scenario: Lock lines are sorted by key and hold a hash or FORMAT_ERROR
    Given the results "b@1/src/b.gleam" formatted to "x\n", "a@1/src/a_long_name.gleam" rejected
    When I render the lock
    Then the lock is:
      """
      # <corpus key> <sha256 of gleam format output | FORMAT_ERROR>
      a@1/src/a_long_name.gleam FORMAT_ERROR
      b@1/src/b.gleam 73cb3858a687a8494ca3323053016282f3dad39d42cf62ca4e79dda2aac7d9ac
      """
