# AST JSON

The canonical JSON of gleam-parser's AST. `@ast.encode_parsed` writes it,
`@ast.decode_parsed` reads it, and the Rust oracle `tools/gleam-ast-oracle`
writes the same bytes from the Gleam compiler's parser (v1.19.2). Parity is
byte equality of this text.

## Canonical form

- One JSON value, keys in sorted (byte) order, no whitespace, one trailing
  line feed from the oracle.
- Strings escape `"`, `\`, and control characters below U+0020 (`\n`, `\t`,
  `\r`, `\b`, `\f`, else `\u00xx` lower case); everything else is raw UTF-8.
- Numbers are integers (byte offsets, indices, `unit` values). A `u64`
  (`tuple_index.index`, a guard's `index`) is written with its exact digits;
  `decode_*` reads the digits, so values above 2^53 keep their precision.
- The codec does not recurse: `encode_*`, `decode_*` and `canonical` run on
  a step trampoline, so a value of any depth is handled on every target.
  The AST's derived `Eq` and `Debug` still recurse, and `@json.parse` has
  its own nesting limit (`max_nesting_depth`, default 1024) and recursion;
  neither is a limit of the codec.

Decoders require every schema field, including nullable fields. They ignore
unknown fields. A malformed value raises `DecodeError` with its JSON path.
Byte offsets must be non-negative integers that fit `Int32`. A span end can
precede its start only for the compiler's `start..0` EOF sentinel. Other
reversed spans are rejected. Tuple and guard indexes must fit `UInt64`.
A bit array `unit` must be an integer in `0..255`.

The MoonBit model uses validated domain types for these fields:
`ByteOffset`, `TupleIndex` and `BitArrayUnit`. Their constructors check raw
numbers at the input boundary. The encoder writes the same JSON numbers.
See [source coordinates](cookbook/source-coordinates.mbt.md) for migration
examples.

An `int_value` string uses canonical decimal digits: `0`, or an optional
`-` followed by a nonzero digit and more digits. Leading zeros, `-0`, `+`
and separators are rejected. A float's `value` must be one complete Gleam
float lexeme, including its decimal point. Conversion retains overflow to
infinity and underflow to zero, as the compiler does.

## Value shapes

| Compiler value | JSON |
|---|---|
| `SrcSpan` | `{"end":n,"start":n}` (UTF-8 byte offsets) |
| `u32` position | number |
| `EcoString` | string |
| `BigInt` (`int_value`) | decimal string |
| `LiteralFloatValue` (`float_value`) | not written; `value` (the lexeme) is enough |
| `Option<T>` | the value or `null` |
| `Vec<T>`, `Vec1<T>` | array |
| `(SrcSpan, EcoString)` (`SpannedString`) | `{"location":…,"name":s}` |
| `(EcoString, SrcSpan)` (a module reference) | `{"location":…,"name":s}` |
| `(u32, EcoString)` (documentation) | `{"start":n,"text":s}` |
| `(EcoString, EcoString, SrcSpan)` (`@external`) | `{"function":s,"location":…,"module":s}` |
| `(AssignName, SrcSpan)` (import alias) | `{"location":…,"name":<AssignName>}` |
| `Target`, `BinOp`, `IntOperator`, `ImplicitCallArgOrigin` | snake_case string (`"erlang"`, `"add_int"`, `"remainder"`, `"pattern_field_spread"`) |
| other enums | object with `"kind"` (snake_case variant name) and the variant's fields |
| a struct inside an enum variant (`Definition::Function(Function)`) | the struct's fields flattened beside `"kind"` |

## Top level

`{"extra":<ModuleExtra>,"module":{"definitions":[<TargetedDefinition>]},"warnings":[<Warning>]}`
or, for a file the compiler rejects, `{"error":{"kind":"<ParseErrorType variant>","lexical_kind":<string|null>,"location":…}}`
where `lexical_kind` is set for `LexError` (`"BadStringEscape"`,
`"InvalidUnicodeEscape.MissingOpeningBrace"`, …).

`ModuleExtra`: `comments`, `doc_comments`, `module_comments` (arrays of
spans, after the slashes), `empty_lines`, `new_lines`, `trailing_commas`
(arrays of byte offsets).

`TargetedDefinition`: `{"definition":<Definition>,"target":<Target|null>}`.

## Definitions

Kinds `function`, `type_alias`, `custom_type`, `import`, `module_constant`,
with the compiler's fields. Not written: `Module.name`, `Module.documentation`
(empty at parse time), `type_`, `return_type`, `typed_parameters`,
`implementations`, `purity`, `compiled_case`, `constructor`, `field_map`,
`record_constructor`, `definition_location`, `origin`, `names`,
`unused_definition_positions`, `extra_information`.

## Renamed keys

Three nodes have a field named `kind` in the compiler; it is written under
another key because `kind` names the node: `Expr::Fn.kind` → `fn_kind`,
`Expr::Todo.kind` → `todo_kind`, `Assignment.kind` → `assignment_kind`.
`TypeAstFn.return_` keeps its name. In the MoonBit types, fields whose
compiler name is a MoonBit keyword carry a trailing underscore (`module_`,
`guard_`, `opaque_`, `alias_`, `constructor_`); the JSON keys keep the
compiler's names.

## Kinds

- `Statement`: `expression` (`{"expression":<Expr>}`), `assignment`, `use`, `assert`.
- `Expr`: `int`, `float`, `string`, `block`, `var`, `fn`, `list`, `call`, `bin_op`, `pipeline`, `case`, `field_access`, `tuple`, `tuple_index`, `todo`, `panic`, `echo`, `bit_array`, `record_update`, `negate_bool`, `negate_int`.
- `Pattern`: `int`, `float`, `string`, `variable`, `bit_array_size` (`{"size":<BitArraySize>}`), `assign`, `discard`, `list`, `constructor`, `tuple`, `bit_array`, `string_prefix`.
- `Constant`: `int`, `float`, `string`, `tuple`, `list`, `record`, `record_update`, `bit_array`, `var`, `binary_operator`, `todo`.
- `TypeAst`: `constructor`, `fn`, `var`, `tuple`, `hole`; `TypeAstConstructorName`: `qualified`, `unqualified`.
- `ClauseGuard`: `block`, `binary_operator`, `not`, `var`, `tuple_index`, `field_access`, `constant` (`{"constant":<Constant>}`).
- `BitArraySize`: `int`, `variable`, `binary_operator`, `block`.
- `BitArrayOption`: `bytes`, `int`, `float`, `bits`, `utf8`, `utf16`, `utf32`, `utf8_codepoint`, `utf16_codepoint`, `utf32_codepoint`, `signed`, `unsigned`, `big`, `little`, `native`, `size`, `unit`.
- `ArgNames`: `discard`, `labelled_discard`, `named`, `named_labelled`.
- `Publicity`: `public`, `private`, `internal`; `Deprecation`: `not_deprecated`, `deprecated`; `AssignName`: `variable`, `discard`; `AssignmentKind`: `let`, `generated`, `assert`; `FunctionLiteralKind`: `capture`, `anonymous`, `use`; `TodoKind`: `keyword`, `empty_function`, `incomplete_use`, `empty_block`.
- `Warning`: `deprecated_list_prepend`, `deprecated_list_pattern`, `deprecated_list_catch_all_pattern`, `deprecated_list_spread_as_variable_pattern` (with `name`), `deprecated_record_spread_pattern`, `deprecated_empty_clause_guard`, `deprecated_target_shorthand` (with `target`), `detached_doc_comment`.

Variants the parser never builds are not in the schema: `Pattern::Invalid`,
`ClauseGuard::Invalid`, `ClauseGuard::ModuleSelect`, `Constant::Invalid`.

## Example

`tests/fixtures/ast/*.gleam` with their `*.json`.
