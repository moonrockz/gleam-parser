fn main() {
  echo [wibble, wobble]
    as {
      // Force this block to split
      "wibble" <> wobble()
    }
}
