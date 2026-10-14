name = "moonrockz/gleam_parser_tests"

version = "0.0.1"

import {
  "moonrockz/gleam-parser@0.0.0",
  "moonbitlang/x@0.5.5",
  "moonrockz/moonspec@0.11.0",
  "moonbitlang/async@0.22.4",
  "moonrockz/expect@0.6.1",
}

repository = "https://github.com/moonrockz/gleam-parser"

license = "Apache-2.0"

description = "Tests for moonrockz/gleam-parser (BDD features, corpus parity, rejection parity); not published"

source = "."

warnings = "-implicit_impl_as_method"
