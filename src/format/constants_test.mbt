///|
test "constants: annotation, records, vars, tuples, lists, bit arrays, operators, todo" {
  @expect.expect_all(s => {
    s
    .expect(@format.format("pub const x: Int = 1\n"))
    .to_equal("pub const x: Int = 1\n")
    s
    .expect(@format.format("const x = one.Two(a: 1, 2)\n"))
    .to_equal("const x = one.Two(a: 1, 2)\n")
    s
    .expect(@format.format("const x = one.two\n"))
    .to_equal("const x = one.two\n")
    s
    .expect(@format.format("const x = #(1, \"a\")\n"))
    .to_equal("const x = #(1, \"a\")\n")
    s
    .expect(@format.format("const x = [1,2,3]\n"))
    .to_equal("const x = [1, 2, 3]\n")
    s
    .expect(@format.format("const x = <<1, 2:size(8)-unit(1), \"a\":utf8>>\n"))
    .to_equal("const x = <<1, 2:size(8)-unit(1), \"a\":utf8>>\n")
    s
    .expect(@format.format("const x = 1 + 2 * 3\n"))
    .to_equal("const x = 1 + 2 * 3\n")
    s
    .expect(@format.format("const x = todo as \"later\"\n"))
    .to_equal("const x = todo as \"later\"\n")
    s
    .expect(@format.format("const x = Record(..base, a: 1)\n"))
    .to_equal("const x = Record(..base, a: 1)\n")
  })
}

///|
test "a list with a trailing comma breaks one item per line; packed items stay packed" {
  @expect.expect_all(s => {
    s
    .expect(@format.format("const x = [1, 2, 3,]\n"))
    .to_equal("const x = [\n  1,\n  2,\n  3,\n]\n")
    // A packed list with a trailing comma that fits on one line is packed
    // onto that line.
    s
    .expect(@format.format("const x = [\n  1, 2, 3,\n  4,\n]\n"))
    .to_equal("const x = [1, 2, 3, 4]\n")
    s
    .expect(
      @format.format(
        "const x = [\"aaaaaaaaaaaaaaaaaaaaaaaaa\", \"bbbbbbbbbbbbbbbbbbbbbbbbb\", \"ccccccccccccccccccccccc\"]\n",
      ),
    )
    .to_equal(
      "const x = [\n  \"aaaaaaaaaaaaaaaaaaaaaaaaa\",\n  \"bbbbbbbbbbbbbbbbbbbbbbbbb\",\n  \"ccccccccccccccccccccccc\",\n]\n",
    )
  })
}

///|
test "comments inside an empty list, before items and before the closing bracket are kept" {
  @expect.expect_all(s => {
    s
    .expect(@format.format("const x = [\n  // a\n]\n"))
    .to_equal("const x = [\n  // a\n]\n")
    s
    .expect(@format.format("const x = [\n  // a\n  1,\n  // b\n]\n"))
    .to_equal("const x = [\n  // a\n  1,\n  // b\n]\n")
    s
    .expect(@format.format("const x =\n  // c\n  [1]\n"))
    .to_equal("const x =\n  // c\n  [1]\n")
  })
}

///|
test "a long constant record breaks after the equals sign, then its arguments" {
  inspect(
    @format.format(
      "const x = Wibble(\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\", [1, 2, 3])\n",
    ),
    content="const x =\n  Wibble(\n    \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\n    [1, 2, 3],\n  )\n",
  )
}

///|
test "a doc comment before a regular comment stays above it, then an empty line" {
  inspect(
    @format.format("/// a\n// b\nconst x = 1\n"),
    content="/// a\n// b\n\nconst x = 1\n",
  )
}

///|
test "a constant of exactly 81 columns stays on one line; 82 columns break after the equals sign" {
  // The compiler counts `const ` as 5 columns (CONST_SPACE_DOCUMENT).
  @expect.expect_all(s => {
    s
    .expect(
      @format.format(
        "const a = \"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"\n",
      ),
    )
    .to_equal(
      "const a = \"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"\n",
    )
    s
    .expect(
      @format.format(
        "const a = \"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy\"\n",
      ),
    )
    .to_equal(
      "const a =\n  \"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy\"\n",
    )
  })
}

///|
test "a list tail after an empty line does not force one item per line" {
  inspect(
    @format.format("const x = [1, 2,\n\n  ..y]\n"),
    content="const x = [1, 2, ..y]\n",
  )
}
