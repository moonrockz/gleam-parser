fn main() {
  let wibble = #(10, [0])
  case wibble {
    wibble if True && { wibble.0 == 10 || wibble.0 == 1 } -> Nil
    _ -> Nil
  }
}
