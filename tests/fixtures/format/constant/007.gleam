pub const wibble = ["Hello", "world"]

pub const wobble = [
  "Some really long message that causes the line to wrap",
  // Some comment
  "Something else",
  // Prepend the values to `wibble`
  ..wibble
  // End of list
]
