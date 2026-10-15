///|
/// A chain of `n` steps that counts down to zero and then counts back up
/// through its continuations.
fn count(n : Int32, k : (Int32) -> Step[Int32]) -> Step[Int32] {
  if n == 0 {
    give(k, 0)
  } else {
    More(() => count(n - 1, m => give(k, m + 1)))
  }
}

///|
fn count_decode(
  n : Int32,
  fail_at : Int32,
  k : (Int32) -> Decode[Int32] raise DecodeError,
) -> Decode[Int32] raise DecodeError {
  if n == fail_at {
    raise DecodeError(path="$", message="stopped at \{n}")
  }
  if n == 0 {
    yield_(k, 0)
  } else {
    Decoding(() => count_decode(n - 1, fail_at, m => yield_(k, m + 1)))
  }
}

///|
test "law: run executes 100000 chained steps in constant stack" {
  @expect.expect(run(count(100000, n => Done(n)))).to_equal(100000)
  @expect.expect(run_decode(count_decode(100000, -1, n => Decoded(n)))).to_equal(
    100000,
  )
}

///|
test "law: an error inside a decode step leaves run_decode" {
  let got = try {
    run_decode(count_decode(50, 20, n => Decoded(n))) |> ignore
    "no error"
  } catch {
    DecodeError(message~, ..) => message
  }
  @expect.expect(got).to_equal("stopped at 20")
}

///|
test "each keeps the element order and each_decode keeps the index" {
  let js = run(
    each([1, 2, 3][:], (n, k) => give(k, Json::number(n.to_double())), js => {
      Done(js.to_owned())
    }),
  )
  @expect.expect(js).to_equal([
    Json::number(1.0),
    Json::number(2.0),
    Json::number(3.0),
  ])
  let empty = run(
    each(
      ([] : Array[Int32])[:],
      (n, k) => give(k, Json::number(n.to_double())),
      js => Done(js.length()),
    ),
  )
  @expect.expect(empty).to_equal(0)
  let items : Array[Json] = [Json::string("a"), Json::string("b")]
  let got = run_decode(
    each_decode(items[:], (j, i, k) => yield_(k, "\{i}:\{j.stringify()}"), xs => {
      Decoded(xs.to_owned())
    }),
  )
  @expect.expect(got).to_equal(["0:\"a\"", "1:\"b\""])
}
