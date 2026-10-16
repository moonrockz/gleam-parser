pub fn main() {
  [1, 2, 3]
  |> list.fold(from: 1, over: _, with: fn(a, b) {
    // a comment!
    a + b
  })
}
