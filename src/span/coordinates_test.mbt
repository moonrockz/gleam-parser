///|
test "coordinate constructors reject invalid values" {
  @expect.expect_all(e => {
    e.expect(@span.ByteOffset::from_int(-1)).to_equal(None)
    e.expect(@span.Utf16Offset::from_int(-1)).to_equal(None)
    e.expect(@span.ByteLength::from_int(-1)).to_equal(None)
    e.expect(@span.LineNumber::from_int(0)).to_equal(None)
    e.expect(@span.ColumnNumber::from_int(0)).to_equal(None)
    e.expect(@span.LineNumber::from_int(-1)).to_equal(None)
    e.expect(@span.ColumnNumber::from_int(-1)).to_equal(None)
    e.expect(@span.LineCount::from_int(0)).to_equal(None)
    e.expect(@span.LineCount::from_int(-1)).to_equal(None)
    e.expect(@span.LineCount::from_int(1).unwrap().to_int()).to_equal(1)
    e.expect(@span.ByteOffset::from_int(0).unwrap().to_int()).to_equal(0)
    e.expect(@span.LineNumber::from_int(1).unwrap().to_int()).to_equal(1)
    e.expect(@span.ColumnNumber::from_int(1).unwrap().to_int()).to_equal(1)
  })
}

///|
test "offset arithmetic checks underflow and overflow" {
  let zero = @span.ByteOffset::from_int(0).unwrap()
  let last = @span.ByteOffset::from_int(2147483647).unwrap()
  @expect.expect_all(e => {
    e.expect(zero.shift(-1)).to_equal(None)
    e.expect(last.shift(1)).to_equal(None)
    e.expect(zero.shift(2147483647)).to_equal(Some(last))
    e.expect(last.shift(-2147483647)).to_equal(Some(zero))
  })
}

///|
test "spans validate ranges and represent compiler EOF spans explicitly" {
  @expect.expect_all(e => {
    e.expect(@span.SrcSpan::from_ints(-1, 3)).to_equal(None)
    e.expect(@span.SrcSpan::from_ints(3, 2)).to_equal(None)
    e.expect(@span.SrcSpan::from_ints(3, 0)).to_equal(None)
    e.expect(@span.Position::from_ints(0, 1)).to_equal(None)
    e.expect(@span.Position::from_ints(1, 0)).to_equal(None)
    let eof = @span.SrcSpan::eof(@span.ByteOffset::from_int(3).unwrap())
    e.expect(eof.is_eof()).to_be_true()
    e.expect(eof.start.to_int()).to_equal(3)
    e.expect(eof.end.to_int()).to_equal(0)
    e.expect(eof.length()).to_equal(None)
    e.expect(eof.contains(@span.ByteOffset::from_int(3).unwrap())).to_be_false()
    let at_zero = @span.SrcSpan::eof(@span.ByteOffset::zero())
    e.expect(at_zero).to_equal(@span.SrcSpan::from_ints(0, 0).unwrap())
    e.expect(at_zero.length().map(n => n.to_int())).to_equal(Some(0))
    e
    .expect(
      @span.SrcSpan::from_compiler(
        @span.ByteOffset::from_int(3).unwrap(),
        @span.ByteOffset::from_int(2).unwrap(),
      ),
    )
    .to_equal(None)
  })
}

///|
test "law: coordinate constructors preserve exactly the valid integers" {
  @quickcheck.check(
    (value : Int32) => {
      @span.ByteOffset::from_int(value).map(x => x.to_int()) ==
      (if value >= 0 { Some(value) } else { None }) &&
      @span.Utf16Offset::from_int(value).map(x => x.to_int()) ==
      (if value >= 0 { Some(value) } else { None }) &&
      @span.ByteLength::from_int(value).map(x => x.to_int()) ==
      (if value >= 0 { Some(value) } else { None }) &&
      @span.LineNumber::from_int(value).map(x => x.to_int()) ==
      (if value >= 1 { Some(value) } else { None }) &&
      @span.ColumnNumber::from_int(value).map(x => x.to_int()) ==
      (if value >= 1 { Some(value) } else { None }) &&
      @span.LineCount::from_int(value).map(x => x.to_int()) ==
      (if value >= 1 { Some(value) } else { None })
    },
    count=200,
    seed=2201,
  )
}

///|
test "law: offset shifts agree with signed wide arithmetic" {
  @quickcheck.check(
    (input : (Int32, Int32)) => {
      let (raw, delta) = input
      let value = raw & 2147483647
      let sum = value.to_int64() + delta.to_int64()
      let expected = if sum >= 0L && sum <= 2147483647L {
        Some(sum.to_int())
      } else {
        None
      }
      @span.ByteOffset::from_int(value)
      .unwrap()
      .shift(delta)
      .map(x => x.to_int()) ==
      expected &&
      @span.Utf16Offset::from_int(value)
      .unwrap()
      .shift(delta)
      .map(x => x.to_int()) ==
      expected
    },
    count=200,
    seed=2202,
  )
}

///|
test "law: ordinary spans exist exactly for non-negative ordered endpoints" {
  @quickcheck.check(
    (input : (Int32, Int32)) => {
      let (start, end) = input
      match @span.SrcSpan::from_ints(start, end) {
        None => start < 0 || end < start
        Some(span) =>
          start >= 0 &&
          end >= start &&
          span.start.to_int() == start &&
          span.end.to_int() == end &&
          span.length().map(x => x.to_int()) == Some(end - start) &&
          !span.contains(span.end) &&
          span.contains(span.start) == (start < end)
      }
    },
    count=200,
    seed=2203,
  )
}
