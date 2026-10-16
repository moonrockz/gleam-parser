///|
/// The compiler's `UntypedExpr::start_byte_index`.
fn start_byte_index(e : @ast.Expr) -> Int32 {
  match e {
    Pipeline(expressions~) => start_byte_index(expressions[0])
    _ => e.location().start
  }
}

///|
fn expr_bin_op_precedence(e : @ast.Expr) -> Int32 {
  match e {
    BinOp(operator~, ..) => precedence(operator)
    Pipeline(..) => 5
    _ => max_precedence
  }
}

///|
fn expr_bin_op_name(e : @ast.Expr) -> @ast.BinOp? {
  match e {
    BinOp(operator~, ..) => Some(operator)
    _ => None
  }
}

///|
fn expr_can_have_multiple_per_line(e : @ast.Expr) -> Bool {
  match e {
    Int(..) | Float(..) | String(..) | Var(..) => true
    NegateBool(value~, ..) | NegateInt(value~, ..) =>
      expr_can_have_multiple_per_line(value)
    FieldAccess(container~, ..) => expr_can_have_multiple_per_line(container)
    _ => false
  }
}

///|
fn is_tuple_expr(e : @ast.Expr) -> Bool {
  e is Tuple(..)
}

///|
fn is_call(e : @ast.Expr) -> Bool {
  e is Call(..)
}

///|
fn is_binop_expr(e : @ast.Expr) -> Bool {
  e is BinOp(..)
}

///|
fn is_pipeline(e : @ast.Expr) -> Bool {
  e is Pipeline(..)
}

///|
/// The compiler's `CAPTURE_VARIABLE`.
let capture_variable : String = "_capture"

///|
fn is_capture_hole(argument : @ast.CallArg[@ast.Expr]) -> Bool {
  argument.value is Var(name~, ..) && name == capture_variable
}

///|
/// The compiler's `is_breakable_argument`: a call only when it is the only
/// argument.
fn is_breakable_argument(e : @ast.Expr, arity : Int32) -> Bool {
  match e {
    Call(..) => arity == 1
    Fn(..) | Block(..) | Case(..) | List(..) | Tuple(..) | BitArray(..) => true
    _ => false
  }
}

///|
/// What comes before an `as` message (the compiler's `PrecedingAs`).
priv enum PrecedingAs {
  Expression
  Keyword
}

///|
priv enum FnCapturePosition {
  RightHandSideOfPipe
  EverywhereElse
}

///|
/// The compiler's `expr`. One unit of fuel per nesting level.
fn Formatter::expr(
  self : Formatter,
  expression : @ast.Expr,
) -> @pretty.Doc raise FormatError {
  self.nested(op_format, () => {
    let comments = self.pop_comments(start_byte_index(expression))
    let document = match expression {
      Panic(message~, ..) =>
        self.append_as_message_expression(t("panic"), Keyword, message)
      Todo(message~, ..) =>
        self.append_as_message_expression(t("todo"), Keyword, message)
      Echo(expression~, message~, ..) => self.echo(expression, message)
      Pipeline(expressions~) => self.pipeline(expressions, false)
      Int(value~, ..) => int(value)
      Float(value~, ..) => float(value)
      String(value~, ..) => string(value)
      Block(statements~, location~) => self.block(location, statements, false)
      Var(name~, ..) => if name == capture_variable { t("_") } else { t(name) }
      TupleIndex(tuple~, index~, ..) => self.tuple_index(tuple, index)
      NegateInt(value~, ..) => self.negate_int(value)
      NegateBool(value~, ..) => self.negate_bool(value)
      Fn(kind=Capture(..), body~, ..) => self.fn_capture(body, EverywhereElse)
      Fn(
        arguments~,
        return_annotation~,
        body~,
        location~,
        end_of_head_byte_index~,
        ..
      ) =>
        self.expr_fn(
          arguments, return_annotation, body, location, end_of_head_byte_index,
        )
      List(elements~, tail~, location~) => self.list(elements, tail, location)
      Call(fun~, arguments~, location~, ..) =>
        self.call(fun, arguments, location)
      BinOp(operator~, left~, right~, ..) =>
        self.bin_op(operator, left, right, false)
      Case(subjects~, clauses~, location~) =>
        self.case_(
          subjects,
          match clauses {
            Some(c) => c
            None => [][:]
          },
          location,
        )
      FieldAccess(label~, container~, ..) =>
        self.expr(container) + t(".") + t(label)
      Tuple(elements~, location~) => self.tuple(elements, location)
      BitArray(segments~, location~) => {
        let docs = []
        for s in segments {
          docs.push(bit_array_segment(s, e => self.bit_array_segment_expr(e)))
        }
        let packing = self.items_sequence_packing(
          segments,
          None,
          s => s.location,
          s => expr_can_have_multiple_per_line(s.value),
          location,
        )
        self.bit_array(docs, packing, location)
      }
      RecordUpdate(constructor_~, record~, arguments~, location~, ..) =>
        self.record_update(constructor_, record, arguments, location)
    }
    commented(document, comments[:])
  })
}

///|
/// The compiler's `tuple_index`: `{t.1}.0` loses its braces.
fn Formatter::tuple_index(
  self : Formatter,
  tuple : @ast.Expr,
  index : UInt64,
) -> @pretty.Doc raise FormatError {
  let inner = match tuple {
    Block(statements~, ..) =>
      if statements.length() == 1 &&
        statements[0] is Expression(TupleIndex(tuple=t2, ..) as e) &&
        !is_tuple_expr(t2) {
        self.expr(e)
      } else {
        self.expr(tuple)
      }
    _ => self.expr(tuple)
  }
  inner + t(".") + t(index.to_string())
}

///|
/// The compiler's `negate_bool`.
fn Formatter::negate_bool(
  self : Formatter,
  e : @ast.Expr,
) -> @pretty.Doc raise FormatError {
  match e {
    NegateBool(value~, ..) => self.expr(value)
    BinOp(..) => t("!") + wrap_block(self.expr(e))
    _ => t("!") + self.expr(e)
  }
}

///|
/// The compiler's `negate_int`.
fn Formatter::negate_int(
  self : Formatter,
  e : @ast.Expr,
) -> @pretty.Doc raise FormatError {
  match e {
    NegateInt(value~, ..) => self.expr(value)
    Int(value~, ..) if value.has_prefix("-") =>
      int(value.view(start_offset=1).to_owned())
    BinOp(..) => t("- ") + self.expr(e)
    _ => t("-") + self.expr(e)
  }
}

///|
/// The compiler's `append_as_message_expression`.
fn Formatter::append_as_message_expression(
  self : Formatter,
  doc : @pretty.Doc,
  preceding_as : PrecedingAs,
  message : @ast.Expr?,
) -> @pretty.Doc raise FormatError {
  guard message is Some(message) else { return doc }
  let comments = self.pop_comments(message.location().start)
  let comments = printed_comments(comments[:], false)
  let as_ = match preceding_as {
    Keyword => space_as
    Expression => nest(breakable_space + t("as"))
  }
  let doc = match comments {
    Some(c) =>
      group(doc) +
      as_ +
      nest(line_doc + c + line_doc + group(self.expr(message)))
    None => {
      let message_doc = match (preceding_as, message) {
        (Keyword, Block(..)) => group(self.expr(message))
        _ => nest(group(self.expr(message)))
      }
      group(doc) + as_ + t(" ") + message_doc
    }
  }
  group(doc)
}

///|
/// The compiler's `echo`.
fn Formatter::echo(
  self : Formatter,
  expression : @ast.Expr?,
  message : @ast.Expr?,
) -> @pretty.Doc raise FormatError {
  guard expression is Some(expression) else {
    return self.append_as_message_expression(t("echo"), Keyword, message)
  }
  let doc = self.expr(expression)
  if is_binop_expr(expression) || is_pipeline(expression) {
    t("echo ") +
    self.append_as_message_expression(nest(doc), Expression, message)
  } else {
    t("echo ") + self.append_as_message_expression(doc, Expression, message)
  }
}

///|
/// The compiler's `expr_fn`.
fn Formatter::expr_fn(
  self : Formatter,
  arguments : ArrayView[@ast.Arg],
  return_annotation : @ast.TypeAst?,
  body : ArrayView[@ast.Statement],
  location : @span.SrcSpan,
  end_of_head_byte_index : Int32,
) -> @pretty.Doc raise FormatError {
  let docs = []
  for a in arguments {
    docs.push(self.fn_arg(a))
  }
  let arguments_doc = @pretty.next_break_fits(
    group(self.wrap_arguments(docs, end_of_head_byte_index)),
    Disabled,
  )
  let header = t("fn") + arguments_doc
  let header = match return_annotation {
    None => header
    Some(ann) => header + t(" -> ") + self.type_ast(ann)
  }
  let statements = self.statements(body)
  let body_doc = match
    printed_comments(self.pop_comments(location.end)[:], false) {
    None => statements
    Some(c) => @pretty.force_break(statements + line_doc + c)
  }
  group(header + t(" ") + wrap_block(body_doc))
}

///|
/// The compiler's `fn_capture`: `f(_)` is `f`; on the right of a pipe a
/// first unlabelled hole is dropped.
fn Formatter::fn_capture(
  self : Formatter,
  call : ArrayView[@ast.Statement],
  position : FnCapturePosition,
) -> @pretty.Doc raise FormatError {
  // The parser builds a capture as one call statement.
  guard call.length() == 1 &&
    call[0] is Expression(Call(fun~, arguments~, location~, ..)) else {
    return @pretty.empty()
  }
  if arguments.length() == 1 &&
    is_capture_hole(arguments[0]) &&
    arguments[0].label is None {
    return self.expr(fun)
  }
  let (rest, arity) = if position is RightHandSideOfPipe &&
    arguments.length() >= 1 &&
    is_capture_hole(arguments[0]) &&
    arguments[0].label is None {
    (arguments[1:], arguments.length() - 1)
  } else {
    (arguments, arguments.length())
  }
  let expression = self.expr(fun)
  self.append_inlinable_wrapped_arguments(
    expression,
    rest.to_owned(),
    location,
    a => a.location,
    a => is_breakable_argument(a.value, arity),
    a => self.call_arg(a, arity),
  )
}
