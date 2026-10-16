pub fn main() {
  Builder(
    accumulator: "",
    update: fn(accum, val) { accum <> val },
    final: fn(accum) { accum },
  )
}
