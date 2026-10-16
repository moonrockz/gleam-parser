# Getting started

Add the module:

```bash
moon add moonrockz/gleam-parser
```

Import it in your package's `moon.pkg`. The module name has a hyphen, so give
the root package an alias:

```
import {
  "moonrockz/gleam-parser" @gleam,
}
```

Read the library version:

```mbt check
///|
test "gs: read the version" {
  @expect.expect(@gleam.version().split(".").count()).to_equal(3)
}
```

## Positions

Spans are UTF-8 byte offsets, as in the Gleam compiler. `SourceText` maps a
byte offset to a line and column, and to a UTF-16 offset for editors:

```mbt check
///|
test "gs: byte offset to position" {
  let st = @gleam.SourceText::new("let x = 1\nlet y = \"é\"")
  @expect.expect(st.position_of(@gleam.ByteOffset::new(10).unwrap())).to_equal(
    Some(@gleam.Position::new(2, 1).unwrap()),
  )
  @expect.expect(st.utf16_offset_of(@gleam.ByteOffset::new(10).unwrap())).to_equal(
    Some(@gleam.Utf16Offset::new(10).unwrap()),
  )
}
```
