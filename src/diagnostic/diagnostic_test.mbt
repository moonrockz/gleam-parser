///|
test "a diagnostic keeps its fields and knows its severity" {
  let d = @diagnostic.Diagnostic::new(
    code="GL-PARSE-001",
    severity=Error,
    title="Syntax error",
    message="I was expecting a '=' after this",
    span=@span.SrcSpan::new(4, 5),
    labels=[
      @diagnostic.Label::{
        span: @span.SrcSpan::new(4, 5),
        text: "I was expecting a '=' after this",
      },
    ],
  )
  @expect.expect_all(e => {
    e.expect(d.is_error()).to_be_true()
    e.expect(d.labels.length()).to_equal(1)
    e.expect(d.hint).to_equal(None)
    e.expect(d.code).to_equal("GL-PARSE-001")
  })
}

///|
test "a warning is not an error" {
  let d = @diagnostic.Diagnostic::new(
    code="GL-PARSE-002",
    severity=Warning,
    title="Deprecated syntax",
    message="This syntax is deprecated",
    span=@span.SrcSpan::new(0, 1),
  )
  @expect.expect(d.is_error()).to_be_false()
}

///|
test "every code has a description and unknown codes have none" {
  @expect.expect_all(e => {
    for code in @diagnostic.codes() {
      e.expect(@diagnostic.description(code) is Some(_)).to_be_true()
    }
    e.expect(@diagnostic.description("GL-NOPE-999")).to_equal(None)
    e.expect(@diagnostic.codes().length()).to_equal(5)
  })
}

///|
test "the code table matches AGENTS.md" {
  @expect.expect(@diagnostic.codes().to_owned()).to_equal([
    "GL-SCAN-001", "GL-PARSE-001", "GL-PARSE-002", "GL-PARSE-003", "GL-PARSE-004",
  ])
}

///|
test "a diagnostic carries the compiler's error kind" {
  let d = @diagnostic.Diagnostic::new(
    code="GL-SCAN-001",
    kind="UnrecognizedToken",
    severity=Error,
    title="Syntax error",
    message="I can't figure out what to do with this character",
    span=@span.SrcSpan::new(0, 0),
  )
  @expect.expect(d.kind).to_equal("UnrecognizedToken")
}

///|
test "the kind defaults to the empty string" {
  let d = @diagnostic.Diagnostic::new(
    code="GL-PARSE-004",
    severity=Error,
    title="Syntax error",
    message="Too much nesting",
    span=@span.SrcSpan::new(0, 0),
  )
  @expect.expect(d.kind).to_equal("")
}
