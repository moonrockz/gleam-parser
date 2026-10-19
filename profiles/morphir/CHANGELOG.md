# Morphir profile changelog

## 0.1.2 - 2026-10-19

Publish Gleam source examples in the README and `profile()` API docs. The
examples show target restrictions, external types, and mixed Erlang, JavaScript,
and Morphir function bindings. A comparison table explains what the standard
preset and the enabled profile accept. The examples run as documentation tests.
Parsing behavior and the core 0.5.0 minimum dependency are unchanged.

## 0.1.1 - 2026-10-19

Re-export common core APIs so the documented setup works with only the Morphir
module in the consumer's manifest. Parsing still defaults to standard Gleam;
profile activation remains explicit. Update the tested README scenarios and
check an isolated consumer that imports only this module.

## 0.1.0 - 2026-10-19

Initial optional profile for `moonrockz/gleam-parser` 0.5.0. Explicitly enable
`profile()` to register the `morphir` target for `@target` and `@external`.
Functions and external types retain opaque module and symbol references with
source locations. The profile composes through the public core API and provides
no backend or foreign-symbol resolution.

See the [tested README scenarios](src/README.mbt.md) for installation,
configuration, composition, formatting, and extended JSON.
