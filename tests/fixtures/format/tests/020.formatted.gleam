pub type Curried(element) =
  fn(element) -> fn(element) -> element
