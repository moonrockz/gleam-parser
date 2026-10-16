# Validate source coordinates and bounded AST values

Use distinct types for byte offsets, UTF-16
offsets, byte lengths, one-based coordinates, line counts, tuple indexes,
bit array units, child indexes and node depths. Restrict construction when
the underlying type can hold an invalid value. Raw signed integers enter
through checked factories and leave at serialization, string and array boundaries.
Changing the MoonBit API is necessary to prevent callers from mixing units
or creating values outside their domain. Keep the oracle JSON unchanged.

Provide MoonBit native smart constructors that raise typed validation
errors. Pair them with named `from_*` factories that return `Option` for
the same valid inputs. Errors retain the rejected value or endpoints.
Use `from_int` for one integer and `from_ints` for a coordinate pair.
`Position::at` accepts validated coordinates without failure.
`TupleIndex(value)` accepts any `UInt64`, whose entire range is valid.
Its optional `from_int64` factory rejects negative signed inputs.

Validated scalar wrappers use `#valtype` records with private fields. A tuple struct
already has a generated constructor with the type's name. Private record
fields allow a custom constructor with that name and keep raw values
behind validation. Keep `derive(Debug)` and update debug examples to the
record representation. Value types preserve the parser's WebAssembly stack
budget; boxed records made the deep-function rejection fixture overflow.
Canonical JSON does not change.

A normal source span must have non-negative, ordered endpoints. Preserve the
Gleam compiler's reversed `start..0` EOF location through a named constructor
and an importer for compiler spans. Do not normalize it into an ordinary
range. A reversed EOF location contains no bytes and has no byte length.
