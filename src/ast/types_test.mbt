///|
fn sp(a : Int32, b : Int32) -> @span.SrcSpan {
  @span.SrcSpan::from_ints(a, b).unwrap()
}

///|
test "a parsed module with one function builds and compares by value" {
  let body : Array[@ast.Statement] = [
    Expression(
      Int(location=sp(14, 15), value="1", int_value=BigInt::from_int(1)),
    ),
  ]
  let f = @ast.Function::{
    location: sp(0, 13),
    body_start: Some(@span.ByteOffset::from_int(13).unwrap()),
    end_position: @span.ByteOffset::from_int(16).unwrap(),
    name: Some({ location: sp(7, 11), name: "main", }),
    arguments: [][:],
    body: body[:],
    publicity: Public,
    deprecation: NotDeprecated,
    return_annotation: None,
    documentation: None,
    external_erlang: None,
    external_javascript: None,
  }
  let m = @ast.Module::{
    definitions: [
      @ast.TargetedDefinition::{ definition: Function(f), target: None, },
    ][:],
  }
  let parsed = @ast.Parsed::{
    module_: m,
    extra: @ast.ModuleExtra::empty(),
    warnings: [][:],
  }
  @expect.expect_all(e => {
    e.expect(parsed.module_.definitions.length()).to_equal(1)
    e.expect(parsed == parsed).to_be_true()
    e.expect(f.body[0]).to_equal(body[0])
    e.expect(@ast.ModuleExtra::empty().comments.length()).to_equal(0)
  })
}

///|
test "payload-free enums have snake_case names and read back" {
  @expect.expect_all(e => {
    e.expect(@ast.BinOp::LtEqFloat.name()).to_equal("lt_eq_float")
    e
    .expect(@ast.BinOp::of("remainder_int"))
    .to_equal(Some(@ast.BinOp::RemainderInt))
    e.expect(@ast.BinOp::of("nope")).to_equal(None)
    e.expect(@ast.Target::JavaScript.name()).to_equal("javascript")
    e.expect(@ast.Target::of("erlang")).to_equal(Some(@ast.Target::Erlang))
    e.expect(@ast.IntOperator::Remainder.name()).to_equal("remainder")
    e
    .expect(@ast.IntOperator::of("multiply"))
    .to_equal(Some(@ast.IntOperator::Multiply))
    e
    .expect(@ast.ImplicitCallArgOrigin::IncorrectArityUse.name())
    .to_equal("incorrect_arity_use")
    e
    .expect(@ast.ImplicitCallArgOrigin::of("pattern_field_spread"))
    .to_equal(Some(@ast.ImplicitCallArgOrigin::PatternFieldSpread))
    for op in @ast.BinOp::all() {
      e.expect(@ast.BinOp::of(op.name())).to_equal(Some(op))
    }
    e.expect(@ast.BinOp::all().length()).to_equal(22)
  })
}

///|
test "generic nodes hold expressions, patterns and constants" {
  let arg : @ast.CallArg[@ast.Expr] = {
    label: Some("x"),
    location: sp(0, 1),
    value: Var(location=sp(0, 1), name="x"),
    implicit: None,
  }
  let seg : @ast.BitArraySegment[@ast.Pattern] = {
    location: sp(0, 3),
    value: Discard(name="_", location=sp(0, 1)),
    options: [
      @ast.BitArrayOption::Size(
        location=sp(2, 3),
        value=@ast.Pattern::Int(
          location=sp(2, 3),
          value="8",
          int_value=BigInt::from_int(8),
        ),
        short_form=true,
      ),
    ][:],
  }
  let c : @ast.Constant = Tuple(location=sp(0, 5), elements=[][:])
  @expect.expect_all(e => {
    e.expect(arg.label).to_equal(Some("x"))
    e.expect(seg.options.length()).to_equal(1)
    e.expect(c == c).to_be_true()
  })
}
