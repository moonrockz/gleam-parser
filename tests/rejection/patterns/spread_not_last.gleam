pub fn f(xs) {
  case xs {
    [..rest, x] -> x
    _ -> 0
  }
}
