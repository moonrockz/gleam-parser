# Work with source coordinates

Byte offsets and UTF-16 offsets use different units. Construct each with
its own checked constructor. A negative input returns `None`.

```mbt check
///|
test {
  @expect.expect(@gleam.ByteOffset::new(-1)).to_equal(None)
  @expect.expect(@gleam.Utf16Offset::new(-1)).to_equal(None)
  @expect.expect(@gleam.Position::new(0, 1)).to_equal(None)
  @expect.expect(@gleam.SrcSpan::new(3, 2)).to_equal(None)
}
```

Use the typed offsets to query a source. Line and column numbers start at
one. Use `to_int()` when an editor protocol, JSON encoder or string API
needs a raw number.

```mbt check
///|
test {
  let source = @gleam.SourceText::new("é\n𝄞")
  guard @gleam.ByteOffset::new(3) is Some(byte) else { fail("invalid offset") }
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
  guard @gleam.SrcSpan::between(byte, source.end_offset()) is Some(span) else {
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
  let source = @gleam.SourceText::new("é")
  let inside = @gleam.ByteOffset::new(1).unwrap()
  let outside = @gleam.ByteOffset::new(3).unwrap()
  @expect.expect_all(e => {
    e.expect(source.position_of(inside)).to_equal(None)
    e.expect(source.position_of(outside)).to_equal(None)
    e.expect(@gleam.ByteOffset::zero().shift(-1)).to_equal(None)
    e
    .expect(@gleam.ByteOffset::new(2147483647).unwrap().shift(1))
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
  let start = @gleam.ByteOffset::new(5).unwrap()
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

- `SrcSpan::new` and `Position::new` now return `Option`. Handle `None` at
  the input boundary. Direct struct construction is no longer available.
- `SrcSpan::length` returns `ByteLength?`. It returns `None` for a reversed
  EOF location. `contains` takes a `ByteOffset`.
- Span endpoints and AST source positions are `ByteOffset`. Source lookups,
  `Tree::node_at` and cursor offset queries take `ByteOffset`.
- `byte_offset_of` takes `Utf16Offset`. `utf16_offset_of` returns it.
- `byte_length` returns `ByteLength`. Use `end_offset` for the final byte
  offset. `line_count` returns `LineCount`.
- AST tuple indexes use `TupleIndex`. Use `from_uint64` to preserve the full
  compiler range. Bit array units use `BitArrayUnit`.
- `PathStep.index` and `NodePath::child` use `ChildIndex`. Traversal depths
  use `NodeDepth`. Their constructors reject negative integers.

The AST JSON schema and the text of formatted Gleam remain unchanged.
