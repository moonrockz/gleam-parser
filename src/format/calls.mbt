///|
/// The compiler's `call`.
fn Formatter::call(
  self : Formatter,
  function : @ast.Expr,
  arguments : ArrayView[@ast.CallArg[@ast.Expr]],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  let expression = match function {
    Pipeline(..) => break_block(self.expr(function))
    _ => self.expr(function)
  }
  let arity = arguments.length()
  self.append_inlinable_wrapped_arguments(
    expression,
    arguments.to_owned(),
    location,
    a => a.location,
    a => is_breakable_argument(a.value, arity),
    a => self.call_arg(a, arity),
  )
}

///|
/// The compiler's `call_arg`.
fn Formatter::call_arg(
  self : Formatter,
  argument : @ast.CallArg[@ast.Expr],
  arity : Int32,
) -> @pretty.Doc raise FormatError {
  self.format_call_arg(argument, e => e.location(), e => {
    self.comma_separated_item(e, arity)
  })
}

///|
/// The compiler's `comma_separated_item`.
fn Formatter::comma_separated_item(
  self : Formatter,
  expression : @ast.Expr,
  siblings : Int32,
) -> @pretty.Doc raise FormatError {
  match expression {
    BinOp(operator~, left~, right~, ..) if siblings > 1 => {
      let comments = self.pop_comments(start_byte_index(expression))
      commented(group(self.bin_op(operator, left, right, true)), comments[:])
    }
    Pipeline(expressions~) if siblings > 1 => {
      let comments = self.pop_comments(start_byte_index(expression))
      commented(group(self.pipeline(expressions, true)), comments[:])
    }
    _ => group(self.expr(expression))
  }
}

///|
/// The compiler's `record_update_arg`.
fn Formatter::record_update_arg(
  self : Formatter,
  argument : @ast.RecordUpdateArg[@ast.Expr],
) -> @pretty.Doc raise FormatError {
  let comments = self.pop_comments(argument.location.start)
  if argument.value.location() == argument.location {
    commented(t(argument.label) + t(":"), comments[:])
  } else {
    let doc = group(t(argument.label) + t(": ") + self.expr(argument.value))
    if is_binop_expr(argument.value) || is_pipeline(argument.value) {
      nest(commented(doc, comments[:]))
    } else {
      commented(doc, comments[:])
    }
  }
}

///|
priv enum UpdatePiece {
  Record(@ast.RecordBeingUpdated[@ast.Expr])
  Argument(@ast.RecordUpdateArg[@ast.Expr])
}

///|
fn UpdatePiece::location(self : UpdatePiece) -> @span.SrcSpan {
  match self {
    Record(r) => r.location
    Argument(a) => a.location
  }
}

///|
/// The compiler's `record_update`.
fn Formatter::record_update(
  self : Formatter,
  constructor_ : @ast.Expr,
  record : @ast.RecordBeingUpdated[@ast.Expr],
  arguments : ArrayView[@ast.RecordUpdateArg[@ast.Expr]],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  let constructor_doc = self.expr(constructor_)
  let pieces : Array[UpdatePiece] = [Record(record)]
  for a in arguments {
    pieces.push(Argument(a))
  }
  let n = pieces.length()
  self.append_inlinable_wrapped_arguments(
    constructor_doc,
    pieces,
    location,
    p => p.location(),
    p => {
      match p {
        Argument(a) => is_breakable_argument(a.value, n)
        Record(r) => is_breakable_argument(r.base, n)
      }
    },
    p => {
      match p {
        Argument(a) => self.record_update_arg(a)
        Record(r) => {
          let comments = self.pop_comments(r.location.start)
          commented(t("..") + self.expr(r.base), comments[:])
        }
      }
    },
  )
}

///|
/// The compiler's `bin_op`.
fn Formatter::bin_op(
  self : Formatter,
  name : @ast.BinOp,
  left : @ast.Expr,
  right : @ast.Expr,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError {
  let left_side = self.bin_op_side(name, left, nest_steps)
  let comments = self.pop_comments(start_byte_index(right))
  let name_doc = breakable_space + commented(binop(name), comments[:])
  let right_side = self.bin_op_side(name, right, nest_steps)
  left_side +
  (if nest_steps { nest(name_doc) } else { name_doc }) +
  t(" ") +
  right_side
}

///|
/// The compiler's `bin_op_side`.
fn Formatter::bin_op_side(
  self : Formatter,
  operator : @ast.BinOp,
  side : @ast.Expr,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError {
  let side_doc = match side {
    String(value~, ..) => bin_op_string(value)
    BinOp(operator~, left~, right~, ..) =>
      self.bin_op(operator, left, right, nest_steps)
    _ => self.expr(side)
  }
  match expr_bin_op_name(side) {
    Some(side_name) if can_be_grouped_with(side_name, operator) => side_doc
    _ =>
      operator_side(
        group(side_doc),
        precedence(operator),
        expr_bin_op_precedence(side),
      )
  }
}

///|
/// The compiler's `pipeline`.
fn Formatter::pipeline(
  self : Formatter,
  expressions : ArrayView[@ast.Expr],
  nest_pipe : Bool,
) -> @pretty.Doc raise FormatError {
  let first = expressions[0]
  let first_precedence = expr_bin_op_precedence(first)
  let first_doc = group(self.expr(first))
  let first_step = operator_side(first_doc, 5, first_precedence)
  let pipeline_start = first.location().start
  let pipeline_end = expressions[expressions.length() - 1].location().end
  let try_to_keep_on_one_line = !self.spans_multiple_lines(
    pipeline_start, pipeline_end,
  )
  let steps_separator = if try_to_keep_on_one_line {
    breakable_space
  } else {
    line_doc
  }
  let stops = [first_step]
  for expression in expressions[1:] {
    let comments = self.pop_comments(expression.location().start)
    let commented_pipe = commented(t("|> "), comments[:])
    let pipe = steps_separator + commented_pipe
    let pipe = if nest_pipe { nest(pipe) } else { pipe }
    let expression_doc = self.expression_on_right_hand_side_of_pipe(
      nest_pipe, expression,
    )
    let expression_doc = operator_side(
      expression_doc,
      4,
      expr_bin_op_precedence(expression),
    )
    stops.push(pipe + expression_doc)
  }
  if try_to_keep_on_one_line {
    @pretty.concat(stops)
  } else {
    @pretty.force_break(@pretty.concat(stops))
  }
}

///|
/// The compiler's `expression_on_right_hand_side_of_pipe`.
fn Formatter::expression_on_right_hand_side_of_pipe(
  self : Formatter,
  nest_pipe : Bool,
  expression : @ast.Expr,
) -> @pretty.Doc raise FormatError {
  let doc = match expression {
    Fn(kind=Capture(..), body~, ..) =>
      self.fn_capture(body, RightHandSideOfPipe)
    _ => self.expr(expression)
  }
  if nest_pipe {
    nest(doc)
  } else {
    doc
  }
}
