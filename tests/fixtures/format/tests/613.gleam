pub fn main() {
  #(value, fn(attr) {
    attr
    |> dynamic.int
    |> result.map(Value)
    |> result.map(AttributeChanged)
  })
}
