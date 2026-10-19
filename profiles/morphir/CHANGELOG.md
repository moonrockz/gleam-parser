# Morphir profile changelog

## 0.1.0 - 2026-10-19

Initial optional profile for `moonrockz/gleam-parser` 0.5.0. Explicitly enable
`profile()` to register the `morphir` target for `@target` and `@external`.
Functions and external types retain opaque module and symbol references with
source locations. The profile composes through the public core API and provides
no backend or foreign-symbol resolution.

See the [tested README scenarios](src/README.mbt.md) for installation,
configuration, composition, formatting, and extended JSON.
