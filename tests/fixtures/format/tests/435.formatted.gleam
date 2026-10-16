pub fn main(x) {
  case x {
    [y, ..] -> y
    _ -> 0
  }
}
