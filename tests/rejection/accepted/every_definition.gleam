import gleam/list.{type Continue, map as list_map}
import gleam/option as opt

pub const limit: Int = 10

const names = ["a", "b"]

pub type Shape {
  Circle(radius: Float)
  Square(Float)
}

pub opaque type Id {
  Id(Int)
}

pub type Pair(a) =
  #(a, a)

@external(erlang, "erlang", "length")
pub fn len(xs: List(a)) -> Int

@deprecated("Use len")
pub fn size(xs: List(a)) -> Int {
  len(xs)
}

@internal
pub fn hidden() -> Nil {
  Nil
}

pub fn area(shape: Shape) -> Float {
  case shape {
    Circle(radius: r) -> 3.14 *. r *. r
    Square(s) -> s *. s
  }
}

fn private(x) {
  x
}
