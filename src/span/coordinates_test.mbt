///|
test "coordinate constructors reject invalid values" {
  @expect.expect_all(e => {
    e.expect(@span.ByteOffset::new(-1)).to_equal(None)
    e.expect(@span.Utf16Offset::new(-1)).to_equal(None)
    e.expect(@span.ByteLength::new(-1)).to_equal(None)
    e.expect(@span.LineNumber::new(0)).to_equal(None)
    e.expect(@span.ColumnNumber::new(0)).to_equal(None)
    e.expect(@span.LineNumber::new(-1)).to_equal(None)
    e.expect(@span.ColumnNumber::new(-1)).to_equal(None)
    e.expect(@span.LineCount::new(0)).to_equal(None)
    e.expect(@span.LineCount::new(-1)).to_equal(None)
    e.expect(@span.LineCount::new(1).unwrap().to_int()).to_equal(1)
    e.expect(@span.ByteOffset::new(0).unwrap().to_int()).to_equal(0)
    e.expect(@span.LineNumber::new(1).unwrap().to_int()).to_equal(1)
    e.expect(@span.ColumnNumber::new(1).unwrap().to_int()).to_equal(1)
  })
}

///|
test "offset arithmetic checks underflow and overflow" {
  let zero = @span.ByteOffset::new(0).unwrap()
  let last = @span.ByteOffset::new(2147483647).unwrap()
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
    e.expect(@span.SrcSpan::new(-1, 3)).to_equal(None)
    e.expect(@span.SrcSpan::new(3, 2)).to_equal(None)
    e.expect(@span.SrcSpan::new(3, 0)).to_equal(None)
    e.expect(@span.Position::new(0, 1)).to_equal(None)
    e.expect(@span.Position::new(1, 0)).to_equal(None)
    let eof = @span.SrcSpan::eof(@span.ByteOffset::new(3).unwrap())
    e.expect(eof.is_eof()).to_be_true()
    e.expect(eof.start.to_int()).to_equal(3)
    e.expect(eof.end.to_int()).to_equal(0)
    e.expect(eof.length()).to_equal(None)
    e.expect(eof.contains(@span.ByteOffset::new(3).unwrap())).to_be_false()
    let at_zero = @span.SrcSpan::eof(@span.ByteOffset::zero())
    e.expect(at_zero).to_equal(@span.SrcSpan::new(0, 0).unwrap())
    e.expect(at_zero.length().map(n => n.to_int())).to_equal(Some(0))
    e
    .expect(
      @span.SrcSpan::from_compiler(
        @span.ByteOffset::new(3).unwrap(),
        @span.ByteOffset::new(2).unwrap(),
      ),
    )
    .to_equal(None)
  })
}

///|
test "law: coordinate constructors preserve exactly the valid integers" {
  @quickcheck.check(
    (value : Int32) => {
      @span.ByteOffset::new(value).map(x => x.to_int()) ==
      (if value >= 0 { Some(value) } else { None }) &&
      @span.Utf16Offset::new(value).map(x => x.to_int()) ==
      (if value >= 0 { Some(value) } else { None }) &&
      @span.ByteLength::new(value).map(x => x.to_int()) ==
      (if value >= 0 { Some(value) } else { None }) &&
      @span.LineNumber::new(value).map(x => x.to_int()) ==
      (if value >= 1 { Some(value) } else { None }) &&
      @span.ColumnNumber::new(value).map(x => x.to_int()) ==
      (if value >= 1 { Some(value) } else { None }) &&
      @span.LineCount::new(value).map(x => x.to_int()) ==
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
      @span.ByteOffset::new(value).unwrap().shift(delta).map(x => x.to_int()) ==
      expected &&
      @span.Utf16Offset::new(value).unwrap().shift(delta).map(x => x.to_int()) ==
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
      match @span.SrcSpan::new(start, end) {
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
