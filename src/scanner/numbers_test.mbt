///|
test "parse_int_value reads every literal form" {
  @expect.expect_all(e => {
    e
    .expect(@scanner.parse_int_value("42"))
    .to_equal(Some(BigInt::from_int(42)))
    e
    .expect(@scanner.parse_int_value("-42"))
    .to_equal(Some(BigInt::from_int(-42)))
    e
    .expect(@scanner.parse_int_value("1_000_000"))
    .to_equal(Some(BigInt::from_int(1000000)))
    e
    .expect(@scanner.parse_int_value("0xFF"))
    .to_equal(Some(BigInt::from_int(255)))
    e
    .expect(@scanner.parse_int_value("-0xff"))
    .to_equal(Some(BigInt::from_int(-255)))
    e
    .expect(@scanner.parse_int_value("0o17"))
    .to_equal(Some(BigInt::from_int(15)))
    e
    .expect(@scanner.parse_int_value("0b1_01"))
    .to_equal(Some(BigInt::from_int(5)))
    e
    .expect(@scanner.parse_int_value("123456789012345678901234567890"))
    .to_equal(Some(BigInt::from_string("123456789012345678901234567890")))
    e.expect(@scanner.parse_int_value("0x")).to_equal(None)
    e.expect(@scanner.parse_int_value("12a")).to_equal(None)
    e.expect(@scanner.parse_int_value("")).to_equal(None)
    e.expect(@scanner.parse_int_value("0b12")).to_equal(None)
  })
}

///|
test "parse_float_value reads the compiler's float forms" {
  @expect.expect_all(e => {
    e.expect(@scanner.parse_float_value("1.5")).to_equal(Some(1.5))
    e.expect(@scanner.parse_float_value("-1.5")).to_equal(Some(-1.5))
    e.expect(@scanner.parse_float_value("1.")).to_equal(Some(1.0))
    e.expect(@scanner.parse_float_value("1.e3")).to_equal(Some(1000.0))
    e.expect(@scanner.parse_float_value("1.0e-3")).to_equal(Some(0.001))
    e.expect(@scanner.parse_float_value("1_000.5")).to_equal(Some(1000.5))
    e.expect(@scanner.parse_float_value("1.0e400")).to_equal(Some(1.0 / 0.0))
    e.expect(@scanner.parse_float_value("abc")).to_equal(None)
    e.expect(@scanner.parse_float_value("1.0e")).to_equal(None)
  })
}

///|
test "exponents beyond Int range give infinity or zero like Rust" {
  @expect.expect_all(e => {
    e
    .expect(@scanner.parse_float_value("1.0e2147483648"))
    .to_equal(Some(1.0 / 0.0))
    e
    .expect(@scanner.parse_float_value("-1.0e99999999999"))
    .to_equal(Some(-1.0 / 0.0))
    e.expect(@scanner.parse_float_value("1.0e-99999999999")).to_equal(Some(0.0))
    e.expect(@scanner.parse_float_value("0.0e99999999999")).to_equal(Some(0.0))
  })
}
