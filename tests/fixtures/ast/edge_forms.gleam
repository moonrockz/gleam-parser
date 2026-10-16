fn ignored(label _value: option.) {
  Nil
}

fn warnings(list, point) {
  let prepended = [1 ..list]
  case point {
    Point(x..) -> x
    _ if -> prepended
  }
}
