///|
/// The compiler's `call`. A chain of calls (`a()()()`) is walked in a loop
/// from the innermost function out, with the compiler's pop order.
async fn Formatter::call(
  self : Formatter,
  function : @ast.Expr,
  arguments : ArrayView[@ast.CallArg[@ast.Expr]],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError + nocancel {
  let frames = [(arguments, location)]
  let mut fun = function
  while fun is Call(fun=f2, arguments=a2, location=l2, ..) {
    frames.push((a2, l2))
    fun = f2
  }
  let mut doc = match fun {
    Pipeline(..) => break_block(self.expr(fun))
    _ => self.expr(fun)
  }
  for k = frames.length() - 1; k >= 0; k = k - 1 {
    let (args, loc) = frames[k]
    let arity = args.length()
    doc = self.append_inlinable_wrapped_arguments(
      doc,
      args.to_owned(),
      loc,
      a => a.location,
      a => is_breakable_argument(a.value, arity),
      a => self.call_arg(a, arity),
    )
  }
  doc
}

///|
/// The compiler's `call_arg`.
async fn Formatter::call_arg(
  self : Formatter,
  argument : @ast.CallArg[@ast.Expr],
  arity : Int32,
) -> @pretty.Doc raise FormatError + nocancel {
  self.format_call_arg(argument, e => e.location(), e => {
    self.comma_separated_item(e, arity)
  })
}

///|
/// The compiler's `comma_separated_item`.
async fn Formatter::comma_separated_item(
  self : Formatter,
  expression : @ast.Expr,
  siblings : Int32,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::record_update_arg(
  self : Formatter,
  argument : @ast.RecordUpdateArg[@ast.Expr],
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::record_update(
  self : Formatter,
  constructor_ : @ast.Expr,
  record : @ast.RecordBeingUpdated[@ast.Expr],
  arguments : ArrayView[@ast.RecordUpdateArg[@ast.Expr]],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError + nocancel {
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
/// The compiler's `bin_op`. A left-nested chain (`a + b + c`) is walked in
/// a loop, not by recursion: the parser accepts a chain of any length, so
/// the formatter spends no fuel and no stack per link. The pops keep the
/// compiler's order: the leftmost operand, then, for each link from the
/// innermost out, the comments before the right operand and the operand.
async fn Formatter::bin_op(
  self : Formatter,
  name : @ast.BinOp,
  left : @ast.Expr,
  right : @ast.Expr,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError + nocancel {
  let ops = [name]
  let rights = [right]
  let mut leaf = left
  while leaf is BinOp(operator~, left=l, right=r, ..) {
    ops.push(operator)
    rights.push(r)
    leaf = l
  }
  let n = ops.length() - 1
  let mut doc = self.bin_op_side(ops[n], leaf, nest_steps)
  for k = n; k >= 0; k = k - 1 {
    let comments = self.pop_comments(start_byte_index(rights[k]))
    let name_doc = breakable_space + commented(binop(ops[k]), comments[:])
    let right_side = self.bin_op_side(ops[k], rights[k], nest_steps)
    doc = doc +
      (if nest_steps { nest(name_doc) } else { name_doc }) +
      t(" ") +
      right_side
    if k > 0 {
      // Link k is the left side of link k - 1 (`bin_op_side`).
      doc = if can_be_grouped_with(ops[k], ops[k - 1]) {
        doc
      } else {
        operator_side(group(doc), precedence(ops[k - 1]), precedence(ops[k]))
      }
    }
  }
  doc
}

///|
/// The compiler's `bin_op_side`.
async fn Formatter::bin_op_side(
  self : Formatter,
  operator : @ast.BinOp,
  side : @ast.Expr,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::pipeline(
  self : Formatter,
  expressions : ArrayView[@ast.Expr],
  nest_pipe : Bool,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::expression_on_right_hand_side_of_pipe(
  self : Formatter,
  nest_pipe : Bool,
  expression : @ast.Expr,
) -> @pretty.Doc raise FormatError + nocancel {
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
