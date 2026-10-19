# Register targets in the core and publish profiles separately

The core owns validated target identities, registration, generic external
bindings, and shared annotation parsing. A profile supplies a named set of
registrations through public APIs. The Morphir profile is a separate module
that depends on the core. The core archive excludes all profile modules.
Installing the core therefore does not install or activate an extension.

Keep recognizable Erlang and JavaScript identities and add one extension
case with a validated name. Reject names that the scanner cannot read as a
single ordinary name. Reserve standard identities and aliases. Both annotation
forms use the registry. Preserve the compiler's rule that only `@target`
accepts the deprecated `erl` and `js` aliases.

Replace target-specific AST fields with an immutable collection that rejects
duplicate bindings. Keep restrictions separate from bindings. Parsing retains
all definitions; downstream target selection is an explicit consumer action.
Profile composition is explicit and rejects duplicate identities and target
conflicts. Named configuration uses only a caller-supplied profile registry.

Preserve compiler JSON as an interchange boundary. Its checked encoders reject
extension-bearing ASTs and retain the legacy external-field layout for standard
ASTs. A separate versioned format preserves generic bindings, the dialect name,
profile identities, and a validated target registry. Decoding this data never
imports profile code. Applications supply the applicable dialect when working
with source. Parse results retain their configuration; formatting defaults to
that configuration and rejects an explicitly different dialect.

These changes break AST constructors and encoder error signatures. Deliver them
in the 0.5 minor release with migration examples. The pinned compiler fixtures,
canonical bytes, diagnostic snapshots, and conformance baselines stay unchanged.
