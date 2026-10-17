///|
/// The compiler's `list`.
async fn Formatter::list(
  self : Formatter,
  elements : ArrayView[@ast.Expr],
  tail : @ast.Expr?,
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError + nocancel {
  if elements.is_empty() {
    return match tail {
      Some(tl) => self.expr(tl)
      None => {
        let comments = self.pop_comments(location.end)
        match printed_comments(comments[:], false) {
          None => t("[]")
          Some(c) =>
            @pretty.force_break(
              t("[") + nest(empty_break) + c + empty_break + t("]"),
            )
        }
      }
    }
  }
  let packing = self.items_sequence_packing(
    elements,
    tail,
    e => e.location(),
    expr_can_have_multiple_per_line,
    location,
  )
  let comma = match packing {
    FitMultiplePerLine => flex_comma
    FitOnePerLine | BreakOnePerLine => comma_break
  }
  let list_size = elements.length() + (if tail is Some(_) { 1 } else { 0 })
  let mut is_empty = true
  let mut elements_doc = @pretty.empty()
  for element in elements {
    let empty_lines = self.pop_empty_lines(element.location().start)
    let element_doc = self.comma_separated_item(element, list_size)
    elements_doc = if is_empty {
      is_empty = false
      element_doc
    } else if empty_lines {
      elements_doc + @pretty.set_nesting(0, comma) + line_doc + element_doc
    } else {
      elements_doc + comma + element_doc
    }
  }
  let elements_doc = @pretty.next_break_fits(elements_doc, Disabled)
  let doc = open_square_break + elements_doc
  let (doc, last_break) = match tail {
    None => (nest(doc), trailing_comma_break)
    Some(tl) => {
      let comments = self.pop_comments(tl.location().start)
      let tail_doc = commented(t("..") + self.expr(tl), comments[:])
      (nest(doc + comma_break + tail_doc), empty_break)
    }
  }
  let comments = self.pop_comments(location.end)
  let doc = match printed_comments(comments[:], false) {
    None => doc + last_break + t("]")
    Some(c) =>
      @pretty.force_break(doc + nest(last_break) + c + line_doc + t("]"))
  }
  match packing {
    FitOnePerLine | FitMultiplePerLine => group(doc)
    BreakOnePerLine => @pretty.force_break(doc)
  }
}

///|
/// The compiler's `tuple`.
async fn Formatter::tuple(
  self : Formatter,
  elements : ArrayView[@ast.Expr],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError + nocancel {
  if elements.is_empty() {
    let comments = self.pop_comments(location.end)
    return match printed_comments(comments[:], false) {
      None => t("#()")
      Some(c) =>
        @pretty.force_break(
          t("#(") + nest(empty_break) + c + empty_break + t(")"),
        )
    }
  }
  let n = elements.length()
  self.append_inlinable_wrapped_arguments(
    t("#"),
    elements.to_owned(),
    location,
    e => e.location(),
    e => !is_tuple_expr(e) && is_breakable_argument(e, n),
    e => self.comma_separated_item(e, n),
  )
}

///|
/// The compiler's `bit_array_segment_expr`.
async fn Formatter::bit_array_segment_expr(
  self : Formatter,
  expression : @ast.Expr,
) -> @pretty.Doc raise FormatError + nocancel {
  match expression {
    BinOp(..) =>
      nest_if_broken(empty_break + self.expr(expression)) + empty_break
    _ => self.expr(expression)
  }
}
