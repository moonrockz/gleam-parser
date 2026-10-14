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
