# Migrate to 0.5

Version 0.5 is a breaking minor release. Standard Gleam source, canonical JSON
bytes, diagnostics, and formatter output retain the Gleam 1.19.2 contract.

| Before | In 0.5 |
|---|---|
| `function.external_erlang` | `function.external_for(Erlang)` |
| `function.external_javascript` | `function.external_for(JavaScript)` |
| The two fields on `CustomType` | The same `external_for` lookup |
| AST constructors with two external fields | `externals: ExternalBindings::from_standard(erlang, javascript)` |
| A string array in `Dialect.targets` | A validated `TargetRegistry`; use `register_target` or `with_profile` |
| Exhaustive `Target` matches | Handle `Extension(TargetName)` as well as Erlang and JavaScript |
| Infallible module/definition JSON export | Handle typed `ExportError::NonStandardTarget` |
| A manually constructed `ParseResult` | Include the configuration in its `config` field |
| Exhaustive `FormatError` matches | Handle `DialectMismatch(expected~, supplied~)` |

`encode_parsed`, `encode_module`, `encode_targeted_definition`,
`encode_definition`, `encode_warning`, and `encode_oracle_output` now raise
`ExportError`. An extension target in any of these values fails explicitly.
Expression, pattern, type, constant, and other encoders that cannot carry target
metadata keep their signatures. No implicit lowering or selection is performed.

Use `ExternalBindings::empty().with_binding(target, external)` for new generic
AST construction. Duplicate targets raise `BindingError::DuplicateBinding`.
`from_standard` remains a convenience for the two legacy optional values.
Bindings are returned in deterministic order: Erlang, JavaScript, then extension
names in code-unit order. Annotation spans remain attached to each binding.

Use `@gleam.encode_extended(result)` and `decode_extended` for source parsed
with an extension dialect. At the AST package level, construct `@ast.Extended`
with the parsed value, dialect name, profile identities, and target registry,
then call `@ast.encode_extended`. The extended format has a separate version;
it does not change the compiler-compatible schema.

Formatting a parse result now uses its stored configuration by default. An
explicit configuration can change fuel, but its dialect must equal the parse
dialect. This prevents metadata from being erased by a configuration mismatch.
Keep the source separately from extended JSON for comment-aware formatting.

See the [tested scenarios](cookbook/target-profiles.mbt.md) and the optional
[Morphir README](../profiles/morphir/src/README.mbt.md).
