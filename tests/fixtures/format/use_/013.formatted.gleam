pub fn main() {
  use x, y <- promise.await(
    file.read()
    |> promise.map(something),
  )
  todo
}
