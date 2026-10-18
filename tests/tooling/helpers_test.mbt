///|
test "SHA-256 uses raw bytes and lowercase hex" {
  @expect.expect_all(s => {
    s
    .expect(@tooling.sha256_hex(b""))
    .to_equal(
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )
    s
    .expect(@tooling.sha256_hex(b"abc"))
    .to_equal(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )
  })
}

///|
test "law: lexical ordering agrees with each pair in code unit order" {
  let ordered = ["", "a", "aa", "b", "é", "😀", "\u{e000}"]
  @expect.expect_all(s => {
    for i in 0..<ordered.length() {
      for j in 0..<ordered.length() {
        s
        .expect(@tooling.compare_lexical(ordered[i], ordered[j]).compare(0))
        .to_equal(i.compare(j))
      }
    }
  })
}
