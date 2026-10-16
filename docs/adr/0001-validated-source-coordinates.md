# Validate source coordinates and bounded AST values

Use distinct types for byte offsets, UTF-16
offsets, byte lengths, one-based coordinates, line counts, tuple indexes,
bit array units, child indexes and node depths. Restrict construction when
the underlying type can hold an invalid value. Raw signed integers enter
through checked factories and leave at serialization, string and array boundaries.
Changing the MoonBit API is necessary to prevent callers from mixing units
or creating values outside their domain. Keep the oracle JSON unchanged.

Use MoonBit's native constructors when the arguments already guarantee the
invariant. `Position(line, column)` accepts validated coordinates.
`TupleIndex(value)` accepts any `UInt64`, whose entire range is valid.
Factories that validate raw values keep their `Option` result. This avoids
adding raised errors only to support constructor syntax.

A normal source span must have non-negative, ordered endpoints. Preserve the
Gleam compiler's reversed `start..0` EOF location through a named constructor
and an importer for compiler spans. Do not normalize it into an ordinary
range. A reversed EOF location contains no bytes and has no byte length.
