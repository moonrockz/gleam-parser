pub type Counter {
  Counter(a: Int, b: Int)
}

fn main() {
  let c = Counter(0, 0)
  let c = Counter(..c, a: c.a + 1, b: c.a + c.b)
  c
}
