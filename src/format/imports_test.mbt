///|
test "imports are sorted, unqualified names are sorted with types first, and a redundant alias is dropped" {
  @expect.expect_all(s => {
    s
    .expect(@format.format("import two\nimport one\n"))
    .to_equal("import one\nimport two\n")
    s
    .expect(@format.format("import one/two/three\n"))
    .to_equal("import one/two/three\n")
    s
    .expect(@format.format("import one.{b, a, type T, c as d}\n"))
    .to_equal("import one.{type T, a, b, c as d}\n")
    s.expect(@format.format("import one as one\n")).to_equal("import one\n")
    s
    .expect(@format.format("import one/two as three\n"))
    .to_equal("import one/two as three\n")
    s.expect(@format.format("import one as _\n")).to_equal("import one as _\n")
    s
    .expect(@format.format("import one.{a as a}\n"))
    .to_equal("import one.{a}\n")
  })
}

///|
test "imports separated by an empty line or a comment form groups that sort apart" {
  @expect.expect_all(s => {
    s
    .expect(
      @format.format("import two\nimport one\n\nimport four\nimport three\n"),
    )
    .to_equal("import one\nimport two\n\nimport four\nimport three\n")
    s
    .expect(@format.format("import two\n// c\nimport one\n"))
    .to_equal("import two\n\n// c\nimport one\n")
  })
}

///|
test "a long unqualified list breaks one name per line with a trailing comma" {
  inspect(
    @format.format(
      "import one.{aaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbb, cccccccccccccccccccc, dddddddddddddddddddddd}\n",
    ),
    content="import one.{\n  aaaaaaaaaaaaaaaaaa, bbbbbbbbbbbbbbbbbbbb, cccccccccccccccccccc,\n  dddddddddddddddddddddd,\n}\n",
  )
}

///|
test "a regular comment between a doc comment and an import is the group delimiter, then the doc comment" {
  // The compiler's `imports` prints the comment as the group's delimiter
  // and the doc comment goes with the import.
  inspect(
    @format.format("/// a\n// b\nimport one\n"),
    content="// b\n/// a\nimport one\n",
  )
}

///|
test "an import under a target attribute keeps it" {
  inspect(
    @format.format("@target(erlang)\nimport one\n"),
    content="@target(erlang)\nimport one\n",
  )
}
