///|
test "span constructor reports reversed endpoints and optional import rejects them" {
  let error = try {
    ignore(@span.SrcSpan(3, 2))
    None
  } catch {
    error => Some(error)
  }
  let valid = @span.SrcSpan(2, 3)
  @expect.expect_all(e => {
    e.expect(error).to_equal(Some(@span.ReversedSpan(start=3, end=2)))
    e.expect(@span.SrcSpan::from_ints(3, 2)).to_equal(None)
    e.expect(@span.SrcSpan::from_ints(2, 3)).to_equal(Some(valid))
  })
}

///|
test "byte offset constructor rejects negative values" {
  let result = try {
    ignore(@span.ByteOffset(-1))
    None
  } catch {
    error => Some(error)
  }
  let zero = @span.ByteOffset(0)
  @expect.expect_all(e => {
    e.expect(result).to_equal(Some(@span.InvalidByteOffset(-1)))
    e.expect(@span.ByteOffset::from_int(0)).to_equal(Some(zero))
  })
}

///|
test "position constructor identifies an invalid line or column" {
  let errors = []
  for (line, column) in [(0, 1), (1, 0)] {
    ignore(@span.Position(line, column)) catch {
      error => errors.push(error)
    }
  }
  let valid = @span.Position(2, 3)
  @expect.expect_all(e => {
    e
    .expect(errors)
    .to_equal([@span.InvalidLineNumber(0), @span.InvalidColumnNumber(0)])
    e.expect(@span.Position::from_ints(0, 1)).to_equal(None)
    e.expect(@span.Position::from_ints(2, 3)).to_equal(Some(valid))
  })
}

///|
fn[T] optional_value(make : () -> T raise) -> T? {
  Some(make()) catch {
    _ => None
  }
}

///|
test "law: raising and optional coordinate constructors agree" {
  let mut successes = 0
  @quickcheck.check(
    (value : Int32) => {
      if @span.ByteOffset::from_int(value) is Some(_) {
        successes += 1
      }
      optional_value(() => @span.ByteOffset(value)) ==
      @span.ByteOffset::from_int(value) &&
      optional_value(() => @span.Utf16Offset(value)) ==
      @span.Utf16Offset::from_int(value) &&
      optional_value(() => @span.ByteLength(value)) ==
      @span.ByteLength::from_int(value) &&
      optional_value(() => @span.LineNumber(value)) ==
      @span.LineNumber::from_int(value) &&
      optional_value(() => @span.ColumnNumber(value)) ==
      @span.ColumnNumber::from_int(value) &&
      optional_value(() => @span.LineCount(value)) ==
      @span.LineCount::from_int(value)
    },
    count=200,
    seed=2301,
  )
  @expect.expect(successes > 0).to_be_true()
}

///|
test "law: raising and optional range and position constructors agree" {
  let mut successes = 0
  @quickcheck.check(
    (input : (Int32, Int32)) => {
      let (start, end) = input
      if @span.SrcSpan::from_ints(start, end) is Some(_) {
        successes += 1
      }
      optional_value(() => @span.SrcSpan(start, end)) ==
      @span.SrcSpan::from_ints(start, end) &&
      optional_value(() => @span.Position(start, end)) ==
      @span.Position::from_ints(start, end)
    },
    count=200,
    seed=2302,
  )
  @expect.expect(successes > 0).to_be_true()
}

///|
test "native span and position constructors preserve boundary invariants" {
  let values = [-2147483648, -1, 0, 1, 2147483647]
  @expect.expect_all(e => {
    for start in values {
      for end in values {
        let span = optional_value(() => @span.SrcSpan(start, end))
        let position = optional_value(() => @span.Position(start, end))
        e.expect(span is Some(_)).to_equal(start >= 0 && end >= start)
        e.expect(position is Some(_)).to_equal(start >= 1 && end >= 1)
        e.expect(span).to_equal(@span.SrcSpan::from_ints(start, end))
        e.expect(position).to_equal(@span.Position::from_ints(start, end))
      }
    }
  })
}
