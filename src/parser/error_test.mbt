///|
fn sp(a : Int32, b : Int32) -> @span.SrcSpan {
  @span.SrcSpan::from_ints(a, b).unwrap()
}

///|
test "every error kind is its compiler variant name" {
  @expect.expect_all(e => {
    e
    .expect(@parser.ParseErrorType::ExpectedEqual.kind())
    .to_equal("ExpectedEqual")
    e
    .expect(@parser.ParseErrorType::IncorrectName(Variable).kind())
    .to_equal("IncorrectName")
    e
    .expect(
      @parser.ParseErrorType::UnexpectedToken(
        token=Equal,
        expected=["x"][:],
        hint=None,
      ).kind(),
    )
    .to_equal("UnexpectedToken")
    e
    .expect(
      @parser.ParseErrorType::ListSpreadWithAnotherSpread(
        first_spread_location=sp(1, 2),
      ).kind(),
    )
    .to_equal("ListSpreadWithAnotherSpread")
    e
    .expect(
      @parser.ParseErrorType::TooMuchNesting(budget=@fuel.default_budget, spent=[]).kind(),
    )
    .to_equal("TooMuchNesting")
  })
}

///|
test "details carry the compiler's wording" {
  let unexpected = @parser.ParseErrorType::UnexpectedToken(
    token=Int(value="1", int_value=BigInt::from_int(1)),
    expected=["`=`"][:],
    hint=None,
  ).details()
  let keyword = @parser.ParseErrorType::UnexpectedToken(
    token=Keyword(Fn),
    expected=["`}`", "a record constructor"][:],
    hint=Some("Gleam is not an object oriented programming language."),
  ).details()
  let spread = @parser.ParseErrorType::ListSpreadWithAnotherSpread(
    first_spread_location=sp(4, 6),
  ).details()
  let name = @parser.ParseErrorType::IncorrectName(Module).details()
  let generics = @parser.ParseErrorType::TypeUsageAngleGenerics(
    module_=Some("set"),
    name="Set",
    arguments=[
        @ast.TypeAst::Constructor({
          location: sp(0, 3),
          name: Unqualified(name="Int", location=sp(0, 3)),
          arguments: [][:],
          start_parentheses: None,
        }),
      ][:],
  ).details()
  @expect.expect_all(e => {
    e.expect(unexpected.label_text).to_equal("I was not expecting this")
    e.expect(unexpected.text).to_equal("Found an Int, expected one of: \n- `=`")
    e.expect(unexpected.hint).to_equal(None)
    e
    .expect(keyword.text)
    .to_equal(
      "Found the keyword `fn`, expected one of: \n- `}`\n- a record constructor",
    )
    e
    .expect(keyword.hint)
    .to_equal(Some("Gleam is not an object oriented programming language."))
    e
    .expect(spread.label_text)
    .to_equal("I wasn't expecting a second list here")
    e.expect(spread.extra_labels.length()).to_equal(1)
    e.expect(spread.extra_labels[0].span).to_equal(sp(4, 6))
    e.expect(spread.extra_labels[0].text).to_equal("You're using a list here")
    e
    .expect(name.text)
    .to_equal(
      "A module name must start with a lowercase letter, and can contain a-z, 0-9,\nor _.",
    )
    e
    .expect(generics.text)
    .to_equal(
      "Type parameters use lowercase names and are surrounded by parentheses.\n\n    set.Set(Int)\n\nSee: https://tour.gleam.run/data-types/generic-custom-types/",
    )
    e.expect(generics.label_text).to_equal("I was expecting `(` here.")
    e
    .expect(@parser.ParseErrorType::ExtraSeparator.details().hint)
    .to_equal(Some("Try removing it?"))
    e
    .expect(@parser.ParseErrorType::ExpectedType.details().text)
    .to_equal("See: https://tour.gleam.run/basics/assignments/")
  })
}

///|
test "the record constructor error prints the fields as the compiler does" {
  let details = @parser.ParseErrorType::ExpectedRecordConstructor(
    type_name="Wibble",
    public=true,
    opaque_=false,
    fields=[
        @ast.RecordConstructorArg::{
          label: Some({ location: sp(0, 5), name: "field", }),
          ast: Constructor({
            location: sp(7, 10),
            name: Unqualified(name="Int", location=sp(7, 10)),
            arguments: [][:],
            start_parentheses: None,
          }),
          location: sp(0, 10),
          doc: None,
        },
        @ast.RecordConstructorArg::{
          label: Some({ location: sp(14, 19), name: "other", }),
          ast: Var({ location: sp(21, 22), name: "a", }),
          location: sp(14, 22),
          doc: None,
        },
      ][:],
  ).details()
  inspect(
    details.text,
    content=(
      #|Each custom type variant must have a constructor:
      #|
      #|pub type Wibble {
      #|  Wibble(
      #|    field: Int,
      #|    other: a,
      #|  )
      #|}
    ),
  )
}

///|
test "token_text is the compiler's Display" {
  @expect.expect_all(e => {
    e.expect(@parser.token_text(Keyword(Fn))).to_equal("`fn`")
    e.expect(@parser.token_text(RArrow)).to_equal("`->`")
    e.expect(@parser.token_text(Name("wibble"))).to_equal("`wibble`")
    e.expect(@parser.token_text(String("hi"))).to_equal("`hi`")
    e
    .expect(@parser.token_text(Float(value="1.5", float_value=1.5)))
    .to_equal("`1.5`")
    e.expect(@parser.token_text(GreaterEqualDot)).to_equal("`>=.`")
  })
}

///|
test "a parse error becomes a GL-PARSE-001 diagnostic; nesting a GL-PARSE-004" {
  let d = @parser.ParseError::to_diagnostic(
    ParseError(error=OpNakedRight, location=sp(27, 29)),
  )
  let deep = @parser.ParseError::to_diagnostic(
    ParseError(
      error=TooMuchNesting(budget=@fuel.default_budget, spent=[]),
      location=sp(3, 4),
    ),
  )
  @expect.expect_all(e => {
    e.expect(d.code).to_equal("GL-PARSE-001")
    e.expect(d.kind).to_equal("OpNakedRight")
    e.expect(d.title).to_equal("Syntax error")
    e.expect(d.message).to_equal("This operator has no value on its right side")
    e.expect(d.hint).to_equal(Some("Remove it or put a value after it."))
    e.expect(d.text).to_equal("")
    e.expect(d.span).to_equal(sp(27, 29))
    e.expect(d.severity).to_equal(@diagnostic.Severity::Error)
    e.expect(deep.code).to_equal("GL-PARSE-004")
    e.expect(deep.kind).to_equal("TooMuchNesting")
  })
}

///|
test "warnings become GL-PARSE-002 and GL-PARSE-003 diagnostics with the compiler's wording" {
  let prepend = @parser.warning_diagnostic(
    DeprecatedListPrepend(location=sp(9, 11)),
  )
  let variable = @parser.warning_diagnostic(
    DeprecatedListSpreadAsVariablePattern(location=sp(1, 5), name="x"),
  )
  let shorthand = @parser.warning_diagnostic(
    DeprecatedTargetShorthand(target=Erlang, location=sp(8, 11)),
  )
  let detached = @parser.warning_diagnostic(
    DetachedDocComment(location=sp(4, 29)),
  )
  @expect.expect_all(e => {
    e.expect(prepend.code).to_equal("GL-PARSE-002")
    e.expect(prepend.kind).to_equal("DeprecatedListPrepend")
    e.expect(prepend.severity).to_equal(@diagnostic.Severity::Warning)
    e.expect(prepend.title).to_equal("Deprecated prepend syntax")
    e
    .expect(prepend.message)
    .to_equal("This spread should be preceded by a comma")
    e
    .expect(prepend.text)
    .to_equal(
      "This syntax for prepending to a list is deprecated.\nWhen prepending an item to a list it should be preceded by a comma, like\nthis: `[item, ..list]`.",
    )
    e.expect(variable.message).to_equal("Replace this with `x`")
    e
    .expect(shorthand.message)
    .to_equal("This should be replaced with `erlang`")
    e
    .expect(shorthand.text)
    .to_equal(
      "This shorthand target name is deprecated. Use the full name: `erlang`\ninstead.",
    )
    e.expect(detached.code).to_equal("GL-PARSE-003")
    e.expect(detached.title).to_equal("Detached doc comment")
    e
    .expect(detached.hint)
    .to_equal(Some("Move the comment above the doc comment"))
    e
    .expect(detached.text)
    .to_equal(
      "This doc comment is followed by a regular comment so it is not attached to\nany definition.",
    )
  })
}

///|
test "the pythonic import error writes the literal word item, as the compiler does" {
  let d = @parser.ParseErrorType::IncorrectImportModuleSeparator(
    module_="gleam",
    item="io",
  ).details()
  @expect.expect(d.text).to_equal(
    "Perhaps you meant one of:\n\n    import gleam/io\n    import gleam.{item}",
  )
}
