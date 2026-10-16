fn main() {
  let a = 1
  let x = <<1, a, 2:bytes>>
  let size = <<3:2, 4:size(3), 5:bytes-size(4), 6:size(a)>>
  let unit = <<7:unit(1), 8:bytes-unit(2)>>
  x
}
