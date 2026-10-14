fn exprs(x) {
  let ints = [1, -2, 0x1F, 0o7, 0b1, 1_000]
  let floats = [1.5, 1., 1.0e3, 1.0e-3, -2.5]
  let strings = ["a", "b\"c", "é𝄞", "\u{1F600}"]
  let block = {
    1
    2
  }
  let anon = fn(a: Int, b) -> Int { a + b }
  let capture = add(1, _)
  let list = [1, 2, ..x]
  let call = add(label: 1, 2)
  let ops = 1 + 2 * 3 - 4 / 5 % 6 <> "s" || a && b == c != d < e <= f > g >= h <. i <=. j >. k >=. l +. m -. n *. o /. p
  let pipe = x |> add(1) |> add(2, _) |> fn(y) { y }
  let c = case x, y {
    1, 2 -> "a"
    3, _ | 4, _ -> "b"
    a, b if a > b && b < 1 || !a.b -> "c"
    [h, ..t] as all if h.0 == 1 -> "d"
    "pre" <> rest -> rest
    "pre" as p <> rest -> p
    <<1, size:4, rest:bits>> -> "e"
    #(a, b) -> "f"
    option.Some(a: 1, ..) -> "g"
    Point(x: 1, y: _) -> "h"
    _ -> "i"
  }
  let empty_case = case x {}
  let access = record.field
  let tuple = #(1, "a").1
  let t = todo
  let t2 = todo as "later"
  let p = panic
  let p2 = panic as "boom"
  echo x
  echo x as "message"
  let bits = <<1, 2:size(x), 3:8-big, "a":utf8, 1:unit(2)-size(4), x:bits>>
  let update = Point(..point, x: 1)
  let update2 = module.Point(..point, y: 2)
  let n = !bool
  let m = -int
  let b = x.0.1
  ops
}

fn empty() {
}

fn nested_todo() {
  {
  }
}
