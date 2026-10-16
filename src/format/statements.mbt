///|
/// The compiler's `statements`.
fn Formatter::statements(
  self : Formatter,
  statements : ArrayView[@ast.Statement],
) -> @pretty.Doc raise FormatError {
  let mut previous_position = 0
  let count = statements.length()
  let documents = []
  for i, statement in statements {
    let preceding_newline = self.pop_empty_lines(previous_position + 1)
    if i != 0 && preceding_newline {
      documents.push(two_lines_doc)
    } else if i != 0 {
      documents.push(line_doc)
    }
    previous_position = statement.location().end
    documents.push(group(self.statement(statement)))
    if statement is Use(_) && i == count - 1 {
      documents.push(line_doc)
      documents.push(t("todo"))
    }
  }
  if count == 1 && statements[0] is Expression(_) {
    @pretty.concat(documents)
  } else {
    @pretty.force_break(@pretty.concat(documents))
  }
}

///|
/// The compiler's `statement`. One unit of fuel per nesting level.
fn Formatter::statement(
  self : Formatter,
  statement : @ast.Statement,
) -> @pretty.Doc raise FormatError {
  self.nested(op_format, () => {
    match statement {
      Expression(e) => self.expr(e)
      Assignment(a) => self.assignment(a)
      Use(u) => self.use_(u)
      Assert(a) => self.assert_(a)
    }
  })
}

///|
/// The compiler's `assignment`.
fn Formatter::assignment(
  self : Formatter,
  assignment : @ast.Assignment,
) -> @pretty.Doc raise FormatError {
  let comments = self.pop_comments(assignment.location.start)
  let _ = self.pop_empty_lines(assignment.pattern.location().end)
  let (keyword, message) = match assignment.kind {
    Let | Generated => (t("let "), None)
    Assert(message~, ..) => (t("let assert "), message)
  }
  let pattern = self.pattern(assignment.pattern)
  let annotation = match assignment.annotation {
    Some(ann) => t(": ") + self.type_ast(ann)
    None => @pretty.empty()
  }
  let doc = keyword +
    group(pattern + annotation) +
    t(" =") +
    self.assigned_value(assignment.value)
  commented(
    self.append_as_message_expression(doc, Expression, message),
    comments[:],
  )
}

///|
/// The compiler's `case_clause_value`: the value after `->` or `=`.
fn Formatter::case_clause_value(
  self : Formatter,
  expression : @ast.Expr,
) -> @pretty.Doc raise FormatError {
  let doc = match expression {
    Fn(..) | List(..) | Tuple(..) | BitArray(..) => {
      let expression_comments = self.pop_comments(expression.location().start)
      let expression_doc = self.expr(expression)
      match printed_comments(expression_comments[:], true) {
        Some(c) => nest(line_doc + c + expression_doc)
        None => t(" ") + expression_doc
      }
    }
    Case(..) => nest(line_doc + self.expr(expression))
    Block(statements~, location~) =>
      t(" ") + self.block(location, statements, true)
    _ => nest(breakable_space + group(self.expr(expression)))
  }
  group(@pretty.next_break_fits(doc, Disabled))
}

///|
/// The compiler's `assigned_value`.
fn Formatter::assigned_value(
  self : Formatter,
  expression : @ast.Expr,
) -> @pretty.Doc raise FormatError {
  match expression {
    Case(..) => group(t(" ") + self.expr(expression))
    _ => self.case_clause_value(expression)
  }
}

///|
/// The compiler's `use_`.
fn Formatter::use_(
  self : Formatter,
  use_ : @ast.Use,
) -> @pretty.Doc raise FormatError {
  let comments = self.pop_comments(use_.location.start)
  let call = group(
    if is_call(use_.call) {
      t(" ") + self.expr(use_.call)
    } else {
      nest(breakable_space + self.expr(use_.call))
    },
  )
  let doc = if use_.assignments.is_empty() {
    t("use <-") + call
  } else {
    let assignments = []
    for a in use_.assignments {
      let pattern = self.pattern(a.pattern)
      let annotation = match a.annotation {
        Some(ann) => t(": ") + self.type_ast(ann)
        None => @pretty.empty()
      }
      assignments.push(group(pattern + annotation))
    }
    let left = group(
      nest(t("use") + breakable_space + @pretty.join(assignments, comma_break)) +
      breakable_space,
    )
    group(left + t("<-") + call)
  }
  commented(doc, comments[:])
}

///|
/// The compiler's `assert`.
fn Formatter::assert_(
  self : Formatter,
  assert_ : @ast.Assert,
) -> @pretty.Doc raise FormatError {
  let comments = self.pop_comments(assert_.location.start)
  let expression = if is_binop_expr(assert_.value) || is_pipeline(assert_.value) {
    nest(self.expr(assert_.value))
  } else {
    self.expr(assert_.value)
  }
  let doc = self.append_as_message_expression(
    expression,
    Expression,
    assert_.message,
  )
  commented(t("assert ") + doc, comments[:])
}

///|
/// The compiler's `block`.
fn Formatter::block(
  self : Formatter,
  location : @span.SrcSpan,
  statements : ArrayView[@ast.Statement],
  force_breaks : Bool,
) -> @pretty.Doc raise FormatError {
  let statements_doc = nest(breakable_space + self.statements(statements))
  let trailing = printed_comments(self.pop_comments(location.end)[:], false)
  let block_doc = match trailing {
    Some(c) =>
      @pretty.force_break(
        t("{") + statements_doc + nest(line_doc) + nest(c) + line_doc + t("}"),
      )
    None => t("{") + statements_doc + breakable_space + t("}")
  }
  if force_breaks {
    group(@pretty.force_break(block_doc))
  } else {
    group(block_doc)
  }
}
