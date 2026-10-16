///|
/// A random parsed module, for the JSON round-trip laws. Every node kind of
/// `@ast` is reachable; depth is bounded by `size`. Spans are small random
/// numbers (the laws do not check them against a text). Edge values: empty
/// lists; `None` in every option; the largest and smallest BigInt digits a
/// test can hold; float lexemes `1.`, `1.e3`, `1_0.5`; strings with `"`,
/// `\`, control characters and non-ASCII; names with `_` and digits.
pub(all) struct GleamAst(@ast.Parsed) derive(Debug)

///|
pub fn GleamAst::parsed(self : GleamAst) -> @ast.Parsed {
  self.0
}

///|
fn ast_pick(rs : @splitmix.RandomState, n : Int32) -> Int32 {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn ast_span(rs : @splitmix.RandomState) -> @span.SrcSpan {
  let a = ast_pick(rs, 200)
  @span.SrcSpan::from_ints(a, a + ast_pick(rs, 40)).unwrap()
}

///|
fn ast_name(rs : @splitmix.RandomState) -> String {
  ["x", "foo_bar", "x1", "_y", "wibble", "é_not_allowed_but_data"][ast_pick(
    rs, 6,
  )]
}

///|
fn ast_upname(rs : @splitmix.RandomState) -> String {
  ["Ok", "Error", "Point", "Some", "T1"][ast_pick(rs, 5)]
}

///|
fn ast_string(rs : @splitmix.RandomState) -> String {
  ["", "a", "a\"b", "a\\b", "tab\t", "nl\n", "\u{1F}", "é𝄞", "\u{0}"][ast_pick(
    rs, 9,
  )]
}

///|
fn ast_int(rs : @splitmix.RandomState) -> (String, BigInt) {
  match ast_pick(rs, 6) {
    0 => ("0", BigInt::from_int(0))
    1 => ("-1", BigInt::from_int(-1))
    2 => ("0x1F", BigInt::from_int(31))
    3 => ("1_000", BigInt::from_int(1000))
    4 =>
      (
        "123456789012345678901234567890",
        BigInt::from_string("123456789012345678901234567890"),
      )
    _ => ("-9223372036854775809", BigInt::from_string("-9223372036854775809"))
  }
}

///|
fn ast_float(rs : @splitmix.RandomState) -> (String, Double) {
  let lexeme = [
      "1.5", "1.", "1.e3", "1_0.5", "-2.5", "1.0e-3", "1.0e99999999999",
    ][ast_pick(rs, 7)]
  (lexeme, @scanner.parse_float_value(lexeme).unwrap())
}

///|
fn[T] ast_opt(rs : @splitmix.RandomState, f : () -> T) -> T? {
  if ast_pick(rs, 2) == 0 {
    None
  } else {
    Some(f())
  }
}

///|
fn[T] ast_list(
  rs : @splitmix.RandomState,
  size : Int32,
  f : () -> T,
) -> ArrayView[T] {
  let n = if size <= 0 { 0 } else { ast_pick(rs, 3) }
  Array::makei(n, _ => f())[:]
}

///|
fn ast_publicity(rs : @splitmix.RandomState) -> @ast.Publicity {
  match ast_pick(rs, 3) {
    0 => Public
    1 => Private
    _ => Internal(attribute_location=ast_opt(rs, () => ast_span(rs)))
  }
}

///|
fn ast_deprecation(rs : @splitmix.RandomState) -> @ast.Deprecation {
  if ast_pick(rs, 3) == 0 {
    Deprecated(message=ast_string(rs))
  } else {
    NotDeprecated
  }
}

///|
fn ast_spanned(rs : @splitmix.RandomState) -> @ast.SpannedString {
  { location: ast_span(rs), name: ast_name(rs), }
}

///|
fn ast_doc(rs : @splitmix.RandomState) -> @ast.Documentation {
  {
    start: @span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
    text: ast_string(rs) + "\n",
  }
}

///|
fn ast_external(rs : @splitmix.RandomState) -> @ast.External {
  { module_: ast_name(rs), function: ast_name(rs), location: ast_span(rs), }
}

///|
fn ast_assign_name(rs : @splitmix.RandomState) -> @ast.AssignName {
  if ast_pick(rs, 2) == 0 {
    Variable(ast_name(rs))
  } else {
    Discard("_" + ast_name(rs))
  }
}

///|
pub fn gen_type_ast(size : Int32, rs : @splitmix.RandomState) -> @ast.TypeAst {
  let s = size / 2
  match (if size <= 0 { 2 + ast_pick(rs, 3) } else { ast_pick(rs, 5) }) {
    0 =>
      Constructor({
        location: ast_span(rs),
        name: if ast_pick(rs, 2) == 0 {
          Unqualified(name=ast_upname(rs), location=ast_span(rs))
        } else {
          Qualified(
            module_=ast_name(rs),
            module_location=ast_span(rs),
            dot_location=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
            name=ast_opt(rs, () => {
              location: ast_span(rs),
              name: ast_upname(rs),
            }),
          )
        },
        arguments: ast_list(rs, s, () => gen_type_ast(s, rs)),
        start_parentheses: ast_opt(rs, () => {
          @span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap()
        }),
      })
    1 =>
      Fn({
        location: ast_span(rs),
        arguments: ast_list(rs, s, () => gen_type_ast(s, rs)),
        return_: gen_type_ast(s, rs),
      })
    2 => Var({ location: ast_span(rs), name: ast_name(rs), })
    3 =>
      Tuple({
        location: ast_span(rs),
        elements: ast_list(rs, s, () => gen_type_ast(s, rs)),
      })
    _ => Hole({ location: ast_span(rs), name: "_" + ast_name(rs), })
  }
}

///|
fn gen_arg(size : Int32, rs : @splitmix.RandomState) -> @ast.Arg {
  let names : @ast.ArgNames = match ast_pick(rs, 4) {
    0 => Discard(name="_" + ast_name(rs), location=ast_span(rs))
    1 =>
      LabelledDiscard(
        label=ast_name(rs),
        label_location=ast_span(rs),
        name="_" + ast_name(rs),
        name_location=ast_span(rs),
      )
    2 => Named(name=ast_name(rs), location=ast_span(rs))
    _ =>
      NamedLabelled(
        label=ast_name(rs),
        label_location=ast_span(rs),
        name=ast_name(rs),
        name_location=ast_span(rs),
      )
  }
  {
    names,
    location: ast_span(rs),
    annotation: ast_opt(rs, () => gen_type_ast(size, rs)),
  }
}

///|
fn[A] gen_call_arg(rs : @splitmix.RandomState, value : A) -> @ast.CallArg[A] {
  {
    label: ast_opt(rs, () => ast_name(rs)),
    location: ast_span(rs),
    value,
    implicit: ast_opt(rs, () => {
      [
        @ast.ImplicitCallArgOrigin::Use,
        Pipe,
        PatternFieldSpread,
        IncorrectArityUse,
        RecordUpdate,
      ][ast_pick(rs, 5)]
    }),
  }
}

///|
fn[V] gen_segment(
  size : Int32,
  rs : @splitmix.RandomState,
  value : () -> V,
) -> @ast.BitArraySegment[V] {
  let option = () => {
    let loc = ast_span(rs)
    let o : @ast.BitArrayOption[V] = match ast_pick(rs, 17) {
      0 => Bytes(location=loc)
      1 => Int(location=loc)
      2 => Float(location=loc)
      3 => Bits(location=loc)
      4 => Utf8(location=loc)
      5 => Utf16(location=loc)
      6 => Utf32(location=loc)
      7 => Utf8Codepoint(location=loc)
      8 => Utf16Codepoint(location=loc)
      9 => Utf32Codepoint(location=loc)
      10 => Signed(location=loc)
      11 => Unsigned(location=loc)
      12 => Big(location=loc)
      13 => Little(location=loc)
      14 => Native(location=loc)
      15 => Size(location=loc, value=value(), short_form=ast_pick(rs, 2) == 0)
      _ =>
        Unit(
          location=loc,
          value=@ast.BitArrayUnit::from_int(ast_pick(rs, 256)).unwrap(),
        )
    }
    o
  }
  {
    location: ast_span(rs),
    value: value(),
    options: ast_list(rs, size, option),
  }
}

///|
pub fn gen_pattern(size : Int32, rs : @splitmix.RandomState) -> @ast.Pattern {
  let s = size / 2
  let leaf = size <= 0
  match (if leaf { ast_pick(rs, 5) } else { ast_pick(rs, 12) }) {
    0 => {
      let (value, int_value) = ast_int(rs)
      Int(location=ast_span(rs), value~, int_value~)
    }
    1 => {
      let (value, float_value) = ast_float(rs)
      Float(location=ast_span(rs), value~, float_value~)
    }
    2 => String(location=ast_span(rs), value=ast_string(rs))
    3 => Variable(location=ast_span(rs), name=ast_name(rs))
    4 => Discard(name="_" + ast_name(rs), location=ast_span(rs))
    5 => BitArraySize(gen_bit_array_size(s, rs))
    6 =>
      Assign(
        name=ast_name(rs),
        location=ast_span(rs),
        pattern=gen_pattern(s, rs),
      )
    7 =>
      List(
        location=ast_span(rs),
        elements=ast_list(rs, s, () => gen_pattern(s, rs)),
        tail=ast_opt(rs, () => {
          location: ast_span(rs),
          pattern: gen_pattern(s, rs),
        }),
      )
    8 =>
      Constructor(
        location=ast_span(rs),
        name_location=ast_span(rs),
        name=ast_upname(rs),
        arguments=ast_list(rs, s, () => gen_call_arg(rs, gen_pattern(s, rs))),
        module_=ast_opt(rs, () => ast_spanned(rs)),
        spread=ast_opt(rs, () => ast_span(rs)),
      )
    9 =>
      Tuple(
        location=ast_span(rs),
        elements=ast_list(rs, s, () => gen_pattern(s, rs)),
      )
    10 =>
      BitArray(
        location=ast_span(rs),
        segments=ast_list(rs, s, () => {
          gen_segment(s, rs, () => gen_pattern(s, rs))
        }),
      )
    _ =>
      StringPrefix(
        location=ast_span(rs),
        left_location=ast_span(rs),
        left_side_assignment=ast_opt(rs, () => {
          name: ast_name(rs),
          name_start_position: @span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
          location: ast_span(rs),
        }),
        right_location=ast_span(rs),
        left_side_string=ast_string(rs),
        right_side_assignment=ast_assign_name(rs),
      )
  }
}

///|
fn gen_bit_array_size(
  size : Int32,
  rs : @splitmix.RandomState,
) -> @ast.BitArraySize {
  let s = size / 2
  match (if size <= 0 { ast_pick(rs, 2) } else { ast_pick(rs, 4) }) {
    0 => {
      let (value, int_value) = ast_int(rs)
      Int(location=ast_span(rs), value~, int_value~)
    }
    1 => Variable(location=ast_span(rs), name=ast_name(rs))
    2 =>
      BinaryOperator(
        location=ast_span(rs),
        operator=[@ast.IntOperator::Add, Subtract, Multiply, Divide, Remainder][ast_pick(
            rs, 5,
          )],
        left=gen_bit_array_size(s, rs),
        right=gen_bit_array_size(s, rs),
      )
    _ => Block(location=ast_span(rs), inner=gen_bit_array_size(s, rs))
  }
}

///|
pub fn gen_constant(size : Int32, rs : @splitmix.RandomState) -> @ast.Constant {
  let s = size / 2
  match (if size <= 0 { ast_pick(rs, 3) } else { ast_pick(rs, 11) }) {
    0 => {
      let (value, int_value) = ast_int(rs)
      Int(location=ast_span(rs), value~, int_value~)
    }
    1 => {
      let (value, float_value) = ast_float(rs)
      Float(location=ast_span(rs), value~, float_value~)
    }
    2 => String(location=ast_span(rs), value=ast_string(rs))
    3 =>
      Tuple(
        location=ast_span(rs),
        elements=ast_list(rs, s, () => gen_constant(s, rs)),
      )
    4 =>
      List(
        location=ast_span(rs),
        elements=ast_list(rs, s, () => gen_constant(s, rs)),
        tail=ast_opt(rs, () => gen_constant(s, rs)),
      )
    5 =>
      Record(
        location=ast_span(rs),
        arguments_start_position=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
        module_=ast_opt(rs, () => ast_spanned(rs)),
        name=ast_upname(rs),
        arguments=ast_opt(rs, () => {
          ast_list(rs, s, () => gen_call_arg(rs, gen_constant(s, rs)))
        }),
      )
    6 =>
      RecordUpdate(
        location=ast_span(rs),
        constructor_location=ast_span(rs),
        module_=ast_opt(rs, () => ast_spanned(rs)),
        name=ast_upname(rs),
        record={ base: gen_constant(s, rs), location: ast_span(rs), },
        arguments=ast_list(rs, s, () => {
          label: ast_name(rs),
          location: ast_span(rs),
          value: gen_constant(s, rs),
        }),
      )
    7 =>
      BitArray(
        location=ast_span(rs),
        segments=ast_list(rs, s, () => {
          gen_segment(s, rs, () => gen_constant(s, rs))
        }),
      )
    8 =>
      Var(
        location=ast_span(rs),
        module_=ast_opt(rs, () => ast_spanned(rs)),
        name=ast_name(rs),
      )
    9 =>
      BinaryOperator(
        location=ast_span(rs),
        operator_start=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
        operator=@ast.BinOp::all()[ast_pick(rs, 22)],
        left=gen_constant(s, rs),
        right=gen_constant(s, rs),
      )
    _ =>
      Todo(
        location=ast_span(rs),
        message=ast_opt(rs, () => gen_constant(s, rs)),
      )
  }
}

///|
pub fn gen_clause_guard(
  size : Int32,
  rs : @splitmix.RandomState,
) -> @ast.ClauseGuard {
  let s = size / 2
  match (if size <= 0 { ast_pick(rs, 2) } else { ast_pick(rs, 7) }) {
    0 => Var(location=ast_span(rs), name=ast_name(rs))
    1 => Constant(gen_constant(s, rs))
    2 => Block(location=ast_span(rs), value=gen_clause_guard(s, rs))
    3 =>
      BinaryOperator(
        location=ast_span(rs),
        operator=@ast.BinOp::all()[ast_pick(rs, 22)],
        operator_start=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
        left=gen_clause_guard(s, rs),
        right=gen_clause_guard(s, rs),
      )
    4 => Not(location=ast_span(rs), expression=gen_clause_guard(s, rs))
    5 =>
      TupleIndex(
        location=ast_span(rs),
        index=@ast.TupleIndex(ast_pick(rs, 5).to_uint64()),
        tuple=gen_clause_guard(s, rs),
      )
    _ =>
      FieldAccess(
        label_location=ast_span(rs),
        index=ast_opt(rs, () => @ast.TupleIndex(ast_pick(rs, 5).to_uint64())),
        label=ast_name(rs),
        container=gen_clause_guard(s, rs),
      )
  }
}

///|
fn gen_statement(size : Int32, rs : @splitmix.RandomState) -> @ast.Statement {
  let s = size / 2
  match ast_pick(rs, 4) {
    0 => Expression(gen_expr(s, rs))
    1 =>
      Assignment({
        location: ast_span(rs),
        value: gen_expr(s, rs),
        pattern: gen_pattern(s, rs),
        kind: match ast_pick(rs, 3) {
          0 => Let
          1 => Generated
          _ =>
            Assert(
              location=ast_span(rs),
              assert_keyword_start=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
              message=ast_opt(rs, () => gen_expr(s, rs)),
            )
        },
        annotation: ast_opt(rs, () => gen_type_ast(s, rs)),
      })
    2 =>
      Use({
        call: gen_expr(s, rs),
        location: ast_span(rs),
        right_hand_side_location: ast_span(rs),
        assignments_location: ast_span(rs),
        assignments: ast_list(rs, s, () => {
          location: ast_span(rs),
          pattern: gen_pattern(s, rs),
          annotation: ast_opt(rs, () => gen_type_ast(s, rs)),
        }),
      })
    _ =>
      Assert({
        location: ast_span(rs),
        value: gen_expr(s, rs),
        message: ast_opt(rs, () => gen_expr(s, rs)),
      })
  }
}

///|
/// A non-empty statement list (`Vec1` in the compiler).
fn gen_body(
  size : Int32,
  rs : @splitmix.RandomState,
) -> ArrayView[@ast.Statement] {
  let n = 1 + (if size <= 0 { 0 } else { ast_pick(rs, 2) })
  Array::makei(n, _ => gen_statement(size, rs))[:]
}

///|
pub fn gen_expr(size : Int32, rs : @splitmix.RandomState) -> @ast.Expr {
  let s = size / 2
  match (if size <= 0 { ast_pick(rs, 4) } else { ast_pick(rs, 24) }) {
    0 => {
      let (value, int_value) = ast_int(rs)
      Int(location=ast_span(rs), value~, int_value~)
    }
    1 => {
      let (value, float_value) = ast_float(rs)
      Float(location=ast_span(rs), value~, float_value~)
    }
    2 => String(location=ast_span(rs), value=ast_string(rs))
    3 => Var(location=ast_span(rs), name=ast_name(rs))
    4 => Block(location=ast_span(rs), statements=gen_body(s, rs))
    5 =>
      Fn(
        location=ast_span(rs),
        kind=match ast_pick(rs, 3) {
          0 => Capture(hole=ast_span(rs))
          1 => Anonymous(head=ast_span(rs))
          _ => Use(location=ast_span(rs))
        },
        end_of_head_byte_index=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
        arguments=ast_list(rs, s, () => gen_arg(s, rs)),
        body=gen_body(s, rs),
        return_annotation=ast_opt(rs, () => gen_type_ast(s, rs)),
      )
    6 =>
      List(
        location=ast_span(rs),
        elements=ast_list(rs, s, () => gen_expr(s, rs)),
        tail=ast_opt(rs, () => gen_expr(s, rs)),
      )
    7 =>
      Call(
        location=ast_span(rs),
        fun=gen_expr(s, rs),
        arguments=ast_list(rs, s, () => gen_call_arg(rs, gen_expr(s, rs))),
        open_parenthesis=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
      )
    8 =>
      BinOp(
        location=ast_span(rs),
        operator=@ast.BinOp::all()[ast_pick(rs, 22)],
        operator_start=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
        left=gen_expr(s, rs),
        right=gen_expr(s, rs),
      )
    9 =>
      Pipeline(
        expressions=Array::makei(2 + ast_pick(rs, 2), _ => gen_expr(s, rs))[:],
      )
    10 =>
      Case(
        location=ast_span(rs),
        subjects=ast_list(rs, s, () => gen_expr(s, rs)),
        clauses=ast_opt(rs, () => {
          ast_list(rs, s, () => {
            location: ast_span(rs),
            pattern: Array::makei(1 + ast_pick(rs, 2), _ => gen_pattern(s, rs))[:],
            alternative_patterns: ast_list(rs, s, () => {
              ast_list(rs, s, () => gen_pattern(s, rs))
            }),
            guard_: ast_opt(rs, () => gen_clause_guard(s, rs)),
            then: gen_expr(s, rs),
          })
        }),
      )
    11 =>
      FieldAccess(
        location=ast_span(rs),
        label_location=ast_span(rs),
        label=ast_name(rs),
        container=gen_expr(s, rs),
      )
    12 =>
      Tuple(
        location=ast_span(rs),
        elements=ast_list(rs, s, () => gen_expr(s, rs)),
      )
    13 =>
      TupleIndex(
        location=ast_span(rs),
        index=@ast.TupleIndex(ast_pick(rs, 5).to_uint64()),
        tuple=gen_expr(s, rs),
      )
    14 =>
      Todo(
        kind=match ast_pick(rs, 4) {
          0 => Keyword
          1 => EmptyFunction(function_location=ast_span(rs))
          2 => IncompleteUse
          _ => EmptyBlock
        },
        location=ast_span(rs),
        message=ast_opt(rs, () => gen_expr(s, rs)),
      )
    15 =>
      Panic(location=ast_span(rs), message=ast_opt(rs, () => gen_expr(s, rs)))
    16 =>
      Echo(
        location=ast_span(rs),
        keyword_end=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
        expression=ast_opt(rs, () => gen_expr(s, rs)),
        message=ast_opt(rs, () => gen_expr(s, rs)),
      )
    17 =>
      BitArray(
        location=ast_span(rs),
        segments=ast_list(rs, s, () => gen_segment(s, rs, () => gen_expr(s, rs))),
      )
    18 =>
      RecordUpdate(
        location=ast_span(rs),
        spread_start=@span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
        constructor_=gen_expr(s, rs),
        record={ base: gen_expr(s, rs), location: ast_span(rs), },
        arguments=ast_list(rs, s, () => {
          label: ast_name(rs),
          location: ast_span(rs),
          value: gen_expr(s, rs),
        }),
      )
    19 => NegateBool(location=ast_span(rs), value=gen_expr(s, rs))
    _ => NegateInt(location=ast_span(rs), value=gen_expr(s, rs))
  }
}

///|
fn gen_definition(size : Int32, rs : @splitmix.RandomState) -> @ast.Definition {
  let s = size / 2
  match ast_pick(rs, 5) {
    0 =>
      Function({
        location: ast_span(rs),
        body_start: ast_opt(rs, () => {
          @span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap()
        }),
        end_position: @span.ByteOffset::from_int(ast_pick(rs, 200)).unwrap(),
        name: ast_opt(rs, () => ast_spanned(rs)),
        arguments: ast_list(rs, s, () => gen_arg(s, rs)),
        body: ast_list(rs, s, () => gen_statement(s, rs)),
        publicity: ast_publicity(rs),
        deprecation: ast_deprecation(rs),
        return_annotation: ast_opt(rs, () => gen_type_ast(s, rs)),
        documentation: ast_opt(rs, () => ast_doc(rs)),
        external_erlang: ast_opt(rs, () => ast_external(rs)),
        external_javascript: ast_opt(rs, () => ast_external(rs)),
      })
    1 =>
      TypeAlias({
        location: ast_span(rs),
        alias_: ast_upname(rs),
        name_location: ast_span(rs),
        parameters: ast_list(rs, s, () => ast_spanned(rs)),
        type_ast: gen_type_ast(s, rs),
        publicity: ast_publicity(rs),
        documentation: ast_opt(rs, () => ast_doc(rs)),
        deprecation: ast_deprecation(rs),
      })
    2 =>
      CustomType({
        location: ast_span(rs),
        end_position: @span.ByteOffset::from_int(ast_pick(rs, 200)).unwrap(),
        name: ast_upname(rs),
        name_location: ast_span(rs),
        publicity: ast_publicity(rs),
        constructors: ast_list(rs, s, () => {
          location: ast_span(rs),
          name_location: ast_span(rs),
          name: ast_upname(rs),
          arguments: ast_list(rs, s, () => {
            label: ast_opt(rs, () => ast_spanned(rs)),
            ast: gen_type_ast(s, rs),
            location: ast_span(rs),
            doc: ast_opt(rs, () => ast_doc(rs)),
          }),
          documentation: ast_opt(rs, () => ast_doc(rs)),
          deprecation: ast_deprecation(rs),
        }),
        documentation: ast_opt(rs, () => ast_doc(rs)),
        deprecation: ast_deprecation(rs),
        opaque_: ast_pick(rs, 2) == 0,
        parameters: ast_list(rs, s, () => ast_spanned(rs)),
        external_erlang: ast_opt(rs, () => ast_external(rs)),
        external_javascript: ast_opt(rs, () => ast_external(rs)),
      })
    3 =>
      Import({
        documentation: ast_opt(rs, () => ast_string(rs)),
        location: ast_span(rs),
        module_location: ast_span(rs),
        module_: "gleam/" + ast_name(rs),
        as_name: ast_opt(rs, () => {
          name: ast_assign_name(rs),
          location: ast_span(rs),
        }),
        unqualified_values: ast_list(rs, s, () => {
          location: ast_span(rs),
          name: ast_name(rs),
          name_position: @span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
          as_name: ast_opt(rs, () => ast_name(rs)),
        }),
        unqualified_types: ast_list(rs, s, () => {
          location: ast_span(rs),
          name: ast_upname(rs),
          name_position: @span.ByteOffset::from_int(ast_pick(rs, 100)).unwrap(),
          as_name: ast_opt(rs, () => ast_upname(rs)),
        }),
      })
    _ =>
      ModuleConstant({
        documentation: ast_opt(rs, () => ast_doc(rs)),
        location: ast_span(rs),
        publicity: ast_publicity(rs),
        name: ast_name(rs),
        name_location: ast_span(rs),
        annotation: ast_opt(rs, () => gen_type_ast(s, rs)),
        value: gen_constant(s, rs),
        deprecation: ast_deprecation(rs),
      })
  }
}

///|
fn gen_warning(rs : @splitmix.RandomState) -> @ast.Warning {
  let loc = ast_span(rs)
  match ast_pick(rs, 8) {
    0 => DeprecatedListPrepend(location=loc)
    1 => DeprecatedListPattern(location=loc)
    2 => DeprecatedListCatchAllPattern(location=loc)
    3 => DeprecatedListSpreadAsVariablePattern(location=loc, name=ast_name(rs))
    4 => DeprecatedRecordSpreadPattern(location=loc)
    5 => DeprecatedEmptyClauseGuard(location=loc)
    6 =>
      DeprecatedTargetShorthand(
        target=if ast_pick(rs, 2) == 0 { Erlang } else { JavaScript },
        location=loc,
      )
    _ => DetachedDocComment(location=loc)
  }
}

///|
pub fn gen_parsed(size : Int32, rs : @splitmix.RandomState) -> @ast.Parsed {
  let positions = () => {
    ast_list(rs, size, () => {
      @span.ByteOffset::from_int(ast_pick(rs, 300)).unwrap()
    })
  }
  {
    module_: {
      definitions: ast_list(rs, size, () => {
        definition: gen_definition(size, rs),
        target: ast_opt(rs, () => {
          if ast_pick(rs, 2) == 0 {
            Erlang
          } else {
            JavaScript
          }
        }),
      }),
    },
    extra: {
      module_comments: ast_list(rs, size, () => ast_span(rs)),
      doc_comments: ast_list(rs, size, () => ast_span(rs)),
      comments: ast_list(rs, size, () => ast_span(rs)),
      empty_lines: positions(),
      new_lines: positions(),
      trailing_commas: positions(),
    },
    warnings: ast_list(rs, size, () => gen_warning(rs)),
  }
}

///|
pub impl @quickcheck.Arbitrary for GleamAst with fn arbitrary(size, rs) {
  GleamAst(gen_parsed(size, rs))
}

///|
/// Shrinks by dropping one definition.
pub impl @quickcheck.Shrink for GleamAst with fn shrink(self) {
  let p = self.0
  let defs = p.module_.definitions
  Array::makei(defs.length(), i => {
    let fewer = defs.to_owned()
    ignore(fewer.remove(i))
    GleamAst({ ..p, module_: { definitions: fewer[:], }, })
  }).iter()
}

///|
/// The options of one random expression bit-array segment, for coverage
/// tests of `BitArrayOption`.
pub fn gen_bit_array_options(
  size : Int32,
  rs : @splitmix.RandomState,
) -> ArrayView[@ast.BitArrayOption[@ast.Expr]] {
  gen_segment(size, rs, () => gen_expr(size / 2, rs)).options
}
