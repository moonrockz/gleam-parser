fn main() {
  let a = 1
  let <<b, c, d:bytes>> = <<1, a, 2:bytes>>
  b
}
