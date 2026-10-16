pub type Counter {
  Counter(a: Int, b: Int)
}

pub const c = Counter(0, 0)

pub const c2 = Counter(..c, a: 1, b: 2)
