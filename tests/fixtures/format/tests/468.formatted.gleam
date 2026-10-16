pub fn main() {
  case
    {
      let assert Ok(x) = thing()
      let assert Ok(y) = thing()
      x + y
    }
  {
    _ -> Nil
  }
}
