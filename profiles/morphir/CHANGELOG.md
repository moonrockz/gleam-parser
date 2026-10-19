# Morphir profile changelog

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
