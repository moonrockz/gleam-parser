import gleam/option.{Some, None,}

const tuple = #(1, 2,)

const list = [1, 2,]

const record = Some(1,)

pub type T(a, b,) {
  Variant(a, b,)
}

fn f(a, b,) -> #(Int, Int,) {
  let x = g(a, b,)
  let y = [a, ..x]
  let z = <<1, 2,>>
  case x, y {
    #(p, q,), _ -> p
    [p, ..], _ -> p
    _, _ -> 0
  }
  use a, b <- h(1,)
  fn(c, d,) { c }
  Point(..x, a: 1,)
}
