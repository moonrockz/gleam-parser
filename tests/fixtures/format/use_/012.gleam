pub fn main() {
  use x, y <- await(
    file.read()
    |> promise.map(something),
  )
  todo
}
