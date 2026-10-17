///|
test "compiler character widths cover controls, marks, wide and ambiguous characters" {
  @expect.expect_all(e => {
    for
      (ch, expected) in [
        ('\u{0}', 0),
        ('\u{1F}', 0),
        (' ', 1),
        ('\u{7F}', 0),
        ('\u{9F}', 0),
        ('é', 1),
        ('Ω', 1),
        ('\u{301}', 0),
        ('\u{200B}', 0),
        ('界', 2),
        ('，', 2),
        ('𝄞', 1),
        ('😀', 2),
        ('\u{17D8}', 3),
        ('\u{FE0F}', 0),
        ('\u{10FFFF}', 1),
      ] {
      e.expect((ch, char_width(ch))).to_equal((ch, expected))
    }
  })
}

///|
test "law: Unicode width lookup agrees with a linear range model" {
  @quickcheck.check(
    (value : UInt32) => {
      let code = (value % 0x110000U).reinterpret_as_int()
      let expected = unicode_width_ranges
        .iter()
        .find_first(r => code >= r.0 && code < r.1)
        .map(r => r.2)
        .unwrap_or(1)
      char_width(code.unsafe_to_char()) == expected
    },
    count=300,
    seed=2401,
  )
}

///|
test "Unicode width ranges are ordered and non-overlapping" {
  let mut previous_end = 0
  @expect.expect_all(e => {
    for (start, end, width) in unicode_width_ranges {
      e
      .expect(start >= previous_end && end > start && end <= 0x110000)
      .to_be_true()
      e.expect(width == 0 || width == 2 || width == 3).to_be_true()
      previous_end = end
    }
  })
}
