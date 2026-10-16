type Test {
  Test(x: Int, y: Float)
}

pub fn main() {
  let x = Test(1, 3.0)
  case x {
    _ if x == Test(1, 1.0) -> 1
    _ if x == Test(y: 2.0, x: 2) -> 2
    _ if x != Test(2, 3.0) -> 2
    _ -> 0
  }
}
