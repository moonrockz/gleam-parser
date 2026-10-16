# Validate source coordinates and bounded AST values

Use distinct types with restricted construction for byte offsets, UTF-16
offsets, byte lengths, one-based coordinates, line counts, tuple indexes,
bit array units, child indexes and node depths. Raw integers enter through
checked constructors and leave at serialization, string and array boundaries.
Changing the MoonBit API is necessary to prevent callers from mixing units
or creating values outside their domain. Keep the oracle JSON unchanged.

A normal source span must have non-negative, ordered endpoints. Preserve the
Gleam compiler's reversed `start..0` EOF location through a named constructor
and an importer for compiler spans. Do not normalize it into an ordinary
range. A reversed EOF location contains no bytes and has no byte length.
