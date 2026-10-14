/// A doc.
pub type Point {
  Point(x: Int, y: Int)
}

pub opaque type Stack(a) {
  Empty
  /// Push docs.
  Push(head: a, tail: Stack(a))
}

@deprecated("use Point")
type Old =
  #(Int, Int)

pub type Handler(a, b) =
  fn(a, List(b)) -> Result(a, option.Option(b))

@external(erlang, "ets", "table")
pub type Table

type Hole =
  _
