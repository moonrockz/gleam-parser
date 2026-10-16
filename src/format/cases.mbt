///|
fn guard_bin_op_name(g : @ast.ClauseGuard) -> @ast.BinOp? {
  match g {
    BinaryOperator(operator~, ..) => Some(operator)
    _ => None
  }
}

///|
fn guard_precedence(g : @ast.ClauseGuard) -> Int32 {
  match guard_bin_op_name(g) {
    Some(op) => precedence(op)
    None => max_precedence
  }
}

///|
/// The compiler's `case`.
fn Formatter::case_(
  self : Formatter,
  subjects : ArrayView[@ast.Expr],
  clauses : ArrayView[@ast.Clause],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  let subject_docs = []
  for subject in subjects {
    subject_docs.push(group(self.expr(subject)))
  }
  let subjects_doc = group(
    @pretty.next_break_fits(
      nest(case_break + @pretty.join(subject_docs, comma_break)) +
      breakable_space +
      t("{"),
      Disabled,
    ),
  )
  let clause_docs = []
  for i, clause in clauses {
    clause_docs.push(group(self.clause(clause, i)))
  }
  let clauses_doc = @pretty.concat(clause_docs)
  let comments = self.pop_comments(location.end)
  let closing = match printed_comments(comments[:], false) {
    None => line_doc + t("}")
    Some(c) => nest(line_doc + c) + line_doc + t("}")
  }
  @pretty.force_break(subjects_doc + nest(line_doc + clauses_doc) + closing)
}

///|
/// The compiler's `clause`.
fn Formatter::clause(
  self : Formatter,
  clause : @ast.Clause,
  index : Int32,
) -> @pretty.Doc raise FormatError {
  let space_before = self.pop_empty_lines(clause.location.start)
  let comments = self.pop_comments(clause.location.start)
  let clause_doc = match clause.guard_ {
    None => self.alternative_patterns(clause)
    Some(g) =>
      self.alternative_patterns(clause) +
      nest(breakable_space) +
      if_space +
      nest(group(self.clause_guard(g)))
  }
  let has_guard = clause.guard_ is Some(_)
  let has_multiple_subjects = clause.pattern.length() > 1
  let arrow_break = if has_guard || has_multiple_subjects {
    breakable_space
  } else {
    t(" ")
  }
  let clause_doc = group(
    group(clause_doc + arrow_break + t("->")) +
    self.case_clause_value(clause.then),
  )
  let clause_doc = match printed_comments(comments[:], false) {
    Some(c) => c + line_doc + clause_doc
    None => clause_doc
  }
  if index == 0 {
    clause_doc
  } else if space_before {
    two_lines_doc + clause_doc
  } else {
    line_doc + clause_doc
  }
}

///|
/// The compiler's `alternative_patterns`.
fn Formatter::alternative_patterns(
  self : Formatter,
  clause : @ast.Clause,
) -> @pretty.Doc raise FormatError {
  let has_guard = clause.guard_ is Some(_)
  let has_multiple_subjects = clause.pattern.length() > 1
  let alternatives_separator = if has_guard && !has_multiple_subjects {
    nest(breakable_space) + t("| ")
  } else {
    breakable_space + t("| ")
  }
  let alternatives : Array[ArrayView[@ast.Pattern]] = [clause.pattern]
  for a in clause.alternative_patterns {
    alternatives.push(a)
  }
  let alternative_docs = []
  for alternative_index, patterns in alternatives {
    let pattern_docs = []
    for pattern_index, pattern in patterns {
      let is_first_pattern_of_clause = pattern_index == 0 &&
        alternative_index == 0
      let pattern_doc = self.pattern(pattern)
      pattern_docs.push(
        if is_first_pattern_of_clause {
          pattern_doc
        } else {
          nest(pattern_doc)
        },
      )
    }
    alternative_docs.push(group(@pretty.join(pattern_docs, nest(comma_break))))
  }
  @pretty.join(alternative_docs, alternatives_separator)
}

///|
/// The compiler's `clause_guard_bin_op`, with the left spine walked in a
/// loop: the comments before each left side are popped top-down first (the
/// compiler pops them on the way down), then the leaf, then each right side
/// from the innermost link out.
fn Formatter::clause_guard_bin_op(
  self : Formatter,
  name : @ast.BinOp,
  left : @ast.ClauseGuard,
  right : @ast.ClauseGuard,
) -> @pretty.Doc raise FormatError {
  let ops = [name]
  let rights = [right]
  let lefts = [left]
  let mut leaf = left
  while leaf is BinaryOperator(operator~, left=l, right=r, ..) {
    ops.push(operator)
    rights.push(r)
    lefts.push(l)
    leaf = l
  }
  let n = ops.length() - 1
  let left_comments = []
  for k = 0; k <= n; k = k + 1 {
    left_comments.push(self.pop_comments(lefts[k].location().start))
  }
  let mut doc = self.clause_guard_bin_op_side(
    ops[n],
    leaf,
    guard_precedence(leaf),
  )
  doc = commented(doc, left_comments[n][:])
  for k = n; k >= 0; k = k - 1 {
    let right_comments = self.pop_comments(rights[k].location().start)
    let right_doc = self.clause_guard_bin_op_side(
      ops[k],
      rights[k],
      guard_precedence(rights[k]) - 1,
    )
    let right_doc = commented(
      binop(ops[k]) + t(" ") + right_doc,
      right_comments[:],
    )
    doc = doc + breakable_space + right_doc
    if k > 0 {
      // Link k is the left side of link k - 1 (`clause_guard_bin_op_side`).
      let side_precedence = precedence(ops[k])
      doc = if can_be_grouped_with(ops[k], ops[k - 1]) {
        operator_side(doc, precedence(ops[k - 1]), side_precedence)
      } else {
        operator_side(group(doc), precedence(ops[k - 1]), side_precedence)
      }
      doc = commented(doc, left_comments[k - 1][:])
    }
  }
  doc
}

///|
/// The compiler's `clause_guard_bin_op_side`.
fn Formatter::clause_guard_bin_op_side(
  self : Formatter,
  name : @ast.BinOp,
  side : @ast.ClauseGuard,
  side_precedence : Int32,
) -> @pretty.Doc raise FormatError {
  let side_doc = self.clause_guard(side)
  match guard_bin_op_name(side) {
    Some(side_name) if can_be_grouped_with(side_name, name) =>
      operator_side(side_doc, precedence(name), side_precedence)
    _ => operator_side(group(side_doc), precedence(name), side_precedence)
  }
}

///|
/// The compiler's `clause_guard`. One unit of fuel per nesting level.
fn Formatter::clause_guard(
  self : Formatter,
  guard_ : @ast.ClauseGuard,
) -> @pretty.Doc raise FormatError {
  self.nested(op_format, () => {
    match guard_ {
      BinaryOperator(operator~, left~, right~, ..) =>
        self.clause_guard_bin_op(operator, left, right)
      Var(name~, ..) => t(name)
      TupleIndex(tuple~, index~, ..) =>
        self.clause_guard(tuple) + t(".") + t(index.to_string())
      FieldAccess(container~, label~, ..) =>
        self.clause_guard(container) + t(".") + t(label)
      Constant(c) => self.const_expr(c)
      Not(expression~, ..) => t("!") + self.clause_guard(expression)
      Block(value~, ..) => group(wrap_block(self.clause_guard(value)))
    }
  })
}
