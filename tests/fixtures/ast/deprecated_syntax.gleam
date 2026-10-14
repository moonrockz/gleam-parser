fn f(list) {
  case list {
    [first..rest] -> rest
    [..] -> []
    [..x] -> x
    Point(..) -> []
  }
}
