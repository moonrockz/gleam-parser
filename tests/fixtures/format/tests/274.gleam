fn main() {
  { os.system_time(os.Millisecond) < june_12_2020 * 1_000_000 }
  |> transform
  |> should.equal(True)
}
