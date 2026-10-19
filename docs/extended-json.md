# Extended JSON version 1

This format preserves registered source-language targets. It is separate from
[compiler-compatible JSON](ast-json.md). Encode with `@gleam.encode_extended`
or `@ast.encode_extended`. Write deterministic bytes with `canonical`.

The envelope is:

```json
{
  "format": "gleam-parser-extended",
  "version": 1,
  "dialect": "gleam-1.19",
  "profiles": ["example/orbit@1"],
  "targets": ["erlang", "javascript", "orbit"],
  "parsed": {
    "module": {"definitions": []},
    "extra": {"comments": [], "doc_comments": [], "module_comments": [], "empty_lines": [], "new_lines": [], "trailing_commas": []},
    "warnings": []
  }
}
```

`parsed` uses the compiler-compatible node schema with two changes:

- A target name can be any canonical identity in `targets`.
- Function and custom-type definitions replace `external_erlang` and
  `external_javascript` with an `externals` array. Each entry has `target`,
  `module`, `function`, and `location`. No per-extension fields exist.

For example, a binding is:

```json
{
  "target": "orbit",
  "module": "example/domain",
  "function": "CustomerId",
  "location": {"start": 0, "end": 46}
}
```

The strings are opaque references. `location` covers the complete annotation
in UTF-8 byte offsets. `TargetedDefinition.target` remains a separate optional
restriction. A binding does not set it. The formatter can reorder bindings;
source positions change after formatting and reparsing.

Targets and profiles in the envelope are sorted in code-unit order. Bindings
are sorted with Erlang first, JavaScript second, then extensions in code-unit
order. Definition order and all node data are retained. `canonical` sorts
object keys using the existing compiler-compatible rules.

The decoder accepts only format version 1. It validates every extension name
through the public target constructor, requires both standard target identities,
and rejects duplicate registrations. Aliases such as `js` are not canonical
identities. Every target restriction, external binding, and target-bearing
warning must resolve through the embedded registry. Duplicate bindings and
legacy external fields are errors. External bindings on a definition that has
no external annotation grammar are errors. Errors use `DecodeError` and name
the failing JSON path. The remaining node validation follows the standard codec.

The dialect name must be nonempty. Profile identities must be nonempty and
unique. They describe the provider and version; they do not prove that the
provider is trusted. No registry lookup imports a module or runs profile code.
Applications provide the corresponding dialect when they parse source again.
The envelope identifies the dialect and registered targets; it does not serialize
arbitrary keyword or deprecation policy changes.

Extended JSON preserves AST data and trivia positions, not the original source
text or CST. Keep source separately for exact reconstruction and formatting
with comments. Compiler-compatible export of an extension-bearing AST raises
`ExportError`; it never drops extension information to make export succeed.
