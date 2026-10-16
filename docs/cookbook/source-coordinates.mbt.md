# Work with source coordinates

Byte offsets and UTF-16 offsets use different units. Native constructors
raise typed errors for invalid input. Use a `from_*` factory when the
caller needs `Option` instead.

```mbt check
///|
test {
  let span = @gleam.SrcSpan(2, 5)
  let position = @gleam.Position(1, 2)
  let offset = @gleam.ByteOffset(2)
  @expect.expect_all(e => {
    e.expect(span.start).to_equal(offset)
    e.expect(position.column.to_int()).to_equal(2)
  })
}
```

Handle the error when the caller needs the reason for rejection. Error
cases retain the input that failed validation.

```mbt check
///|
test {
  let error = try {
    ignore(@gleam.SrcSpan(3, 2))
    None
  } catch {
    error => Some(error)
  }
  @expect.expect(error).to_equal(
    Some(@gleam.CoordinateError::ReversedSpan(start=3, end=2)),
  )
}
```

The optional factories reject the same invalid input with `None`.

```mbt check
///|
test {
  @expect.expect(@gleam.ByteOffset::from_int(-1)).to_equal(None)
  @expect.expect(@gleam.Utf16Offset::from_int(-1)).to_equal(None)
  @expect.expect(@gleam.Position::from_ints(0, 1)).to_equal(None)
  @expect.expect(@gleam.SrcSpan::from_ints(3, 2)).to_equal(None)
}
```

Use the typed offsets to query a source. Line and column numbers start at
one. Use `to_int()` when an editor protocol, JSON encoder or string API
needs a raw number.

Use `Position::at(line, column)` when both coordinates are already valid.
This method takes domain types and needs no validation.

```mbt check
///|
test {
  let line = @gleam.LineNumber::from_int(2).unwrap()
  let column = @gleam.ColumnNumber::from_int(1).unwrap()
  let position = @gleam.Position::at(line, column)
  @expect.expect(position).to_equal(@gleam.Position::from_ints(2, 1).unwrap())
}
```

```mbt check
///|
test {
  let source = @gleam.SourceText("é\n𝄞")
  guard @gleam.ByteOffset::from_int(3) is Some(byte) else {
    fail("invalid offset")
  }
  guard source.utf16_offset_of(byte) is Some(utf16) else {
    fail("not a boundary")
  }
  guard source.position_of(byte) is Some(position) else {
    fail("not a boundary")
  }
  @expect.expect_all(e => {
    e.expect(utf16.to_int()).to_equal(2)
    e.expect(source.byte_offset_of(utf16)).to_equal(Some(byte))
    e.expect(position.line.to_int()).to_equal(2)
    e.expect(position.column.to_int()).to_equal(1)
    e.expect(source.byte_length().to_int()).to_equal(7)
    e.expect(source.line_count().to_int()).to_equal(2)
  })
  guard @gleam.SrcSpan::from_offsets(byte, source.end_offset()) is Some(span) else {
    fail("reversed range")
  }
  @expect.expect(source.slice(span)).to_equal(Some("𝄞"))
  @expect.expect(span.length().map(n => n.to_int())).to_equal(Some(4))
}
```

A non-negative offset can still fall inside a multi-byte character or past
the source. Source lookups return `None` at those offsets.

```mbt check
///|
test {
  let source = @gleam.SourceText("é")
  let inside = @gleam.ByteOffset::from_int(1).unwrap()
  let outside = @gleam.ByteOffset::from_int(3).unwrap()
  @expect.expect_all(e => {
    e.expect(source.position_of(inside)).to_equal(None)
    e.expect(source.position_of(outside)).to_equal(None)
    e.expect(@gleam.ByteOffset::zero().shift(-1)).to_equal(None)
    e
    .expect(@gleam.ByteOffset::from_int(2147483647).unwrap().shift(1))
    .to_equal(None)
  })
}
```

The Gleam compiler uses `start..0` for some EOF errors. Create that location
with `SrcSpan::eof`, or import compiler offsets with `from_compiler`.
An EOF location whose start is after zero has no byte length and contains
no byte offsets. EOF at zero shares the empty range's representation.

```mbt check
///|
test {
  let start = @gleam.ByteOffset::from_int(5).unwrap()
  let location = @gleam.SrcSpan::eof(start)
  @expect.expect_all(e => {
    e.expect(location.is_eof()).to_be_true()
    e.expect(location.end.to_int()).to_equal(0)
    e.expect(location.length()).to_equal(None)
    e.expect(location.contains(start)).to_be_false()
  })
}
```

## Migrate callers that used raw integers

- Use `SrcSpan(start, end)` and `Position(line, column)` with raw integers
  to raise `CoordinateError` on invalid input. Use `from_ints` to get
  `Option`. Direct struct construction is no longer available.
- `SrcSpan::length` returns `ByteLength?`. It returns `None` for a reversed
  EOF location. `contains` takes a `ByteOffset`.
- Span endpoints and AST source positions are `ByteOffset`. Source lookups,
  `Tree::node_at` and cursor offset queries take `ByteOffset`.
- `byte_offset_of` takes `Utf16Offset`. `utf16_offset_of` returns it.
- `byte_length` returns `ByteLength`. Use `end_offset` for the final byte
  offset. `line_count` returns `LineCount`.
- AST tuple indexes use `TupleIndex`. Use `TupleIndex(value)` with a
  `UInt64` to preserve the full compiler range. Bit array units use
  `BitArrayUnit`.
- `PathStep.index` and `NodePath::child` use `ChildIndex`. Traversal depths
  use `NodeDepth`. Their constructors reject negative integers.
- Construct comments with `Comment(kind~, content~, span~)` to raise
  `CommentError`, or use `Comment::from_parts` to get `Option`. Both reject
  an EOF sentinel or a span shorter than the slash prefix. Direct comment
  struct construction is no longer available.

## Use MoonBit constructors

Use `SourceText(text)`, `Tree(result)`, `TreeCursor(root)` and
`EventReader(root)` to build source and syntax values. Use `Fuel(budget~)`
and `Operation(name)` for recursion fuel. These constructors return the
value directly. The old `::new` methods are deprecated aliases.

`TupleIndex(value)` replaces the deprecated `TupleIndex::from_uint64`.
If the tuple index constructor is ambiguous with the AST node variant,
use `TupleIndex::TupleIndex(value)` or supply an expected `TupleIndex` type.

For validated values, choose how the caller handles invalid input:

| Raising constructor | Optional factory | Error type |
| --- | --- | --- |
| `SrcSpan(start, end)` | `SrcSpan::from_ints(start, end)` | `CoordinateError` |
| `Position(line, column)` | `Position::from_ints(line, column)` | `CoordinateError` |
| `ByteOffset(value)`, `Utf16Offset(value)` | `from_int(value)` on each type | `CoordinateError` |
| `ByteLength(value)`, `LineCount(value)` | `from_int(value)` on each type | `CoordinateError` |
| `LineNumber(value)`, `ColumnNumber(value)` | `from_int(value)` on each type | `CoordinateError` |
| `Budget(units)` | `Budget::from_int(units)` | `InvalidBudget` |
| `BitArrayUnit(value)` | `BitArrayUnit::from_int(value)` | `InvalidBitArrayUnit` |
| `ChildIndex(value)`, `NodeDepth(value)` | `from_int(value)` on each type | `TraversalValueError` |
| `Comment(kind~, content~, span~)` | `Comment::from_parts(kind~, content~, span~)` | `CommentError` |

`SrcSpan::from_offsets(start, end)` takes validated offsets and returns
`None` for reversed endpoints. It replaces the deprecated `between`.
Use `Position::at` for total construction from a `LineNumber` and
`ColumnNumber`. The old optional `::new` methods remain deprecated aliases
for the named factories. `TupleIndex::from_int64` validates signed indexes;
the native `TupleIndex(UInt64)` constructor accepts every unsigned value.

The AST JSON schema and the text of formatted Gleam remain unchanged.
