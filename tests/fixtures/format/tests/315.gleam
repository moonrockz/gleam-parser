fn main() {
  case bool {
    True -> {
      "Wibble"
      |> io.println

      "Wobble"
      |> io.println

      Nil
    }
    False -> Nil
  }
}
