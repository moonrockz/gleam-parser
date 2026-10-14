fn pipes(xs) {
  xs
  |> list.map(fn(x) { x + 1 })
  |> list.filter(keep)
  |> list.fold(0, add)
  |> echo
  |> echo as "after"
  |> io.debug
}

fn uses() {
  use <- defer()
  use a <- with_one(1)
  use #(b, c), d: Int <- with_more(2, 3)
  use <- with_last
  a + b + c + d
}

fn captures(f) {
  let g = f(1, _, 3)
  let h = add(label: _, other: 2)
  let i = f(_)
  g(2) + h(3) + i(4)
}
