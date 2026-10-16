pub fn main() {
  Builder(accumulator: "", update: fn(accum, val) { accum }, final: fn(accum) {
    accum
  })
}
