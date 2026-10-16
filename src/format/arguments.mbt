///|
/// The compiler's `wrap_function_call_arguments`.
fn Formatter::wrap_function_call_arguments(
  self : Formatter,
  arguments : Array[@pretty.Doc],
  location : @span.SrcSpan,
) -> @pretty.Doc {
  if arguments.is_empty() {
    return t("()")
  }
  let arguments_doc = nest_if_broken(
    empty_break + @pretty.join(arguments, comma_break),
  )
  let comments = self.pop_comments(location.end)
  let closing = match printed_comments(comments[:], false) {
    None => trailing_comma_break + t(")")
    Some(c) =>
      @pretty.force_break(
        nest(trailing_comma_break) + nest(c) + line_doc + t(")"),
      )
  }
  group(t("(") + arguments_doc + closing)
}

///|
/// The compiler's `wrap_arguments`.
fn Formatter::wrap_arguments(
  self : Formatter,
  arguments : Array[@pretty.Doc],
  comments_limit : Int32,
) -> @pretty.Doc {
  if arguments.is_empty() {
    let comments = self.pop_comments(comments_limit)
    return match printed_comments(comments[:], false) {
      Some(c) =>
        @pretty.force_break(nest_if_broken(t("(") + empty_break + c)) +
        empty_break +
        t(")")
      None => t("()")
    }
  }
  let doc = open_paren_break + @pretty.join(arguments, comma_break)
  let comments = self.pop_comments(comments_limit)
  match printed_comments(comments[:], false) {
    Some(c) =>
      @pretty.force_break(nest_if_broken(doc + trailing_comma_break + c)) +
      empty_break +
      t(")")
    None => nest_if_broken(doc) + trailing_comma_break + t(")")
  }
}

///|
/// The compiler's `wrap_arguments_with_spread`.
fn Formatter::wrap_arguments_with_spread(
  self : Formatter,
  arguments : Array[@pretty.Doc],
  comments_limit : Int32,
) -> @pretty.Doc {
  if arguments.is_empty() {
    return self.wrap_arguments(arguments, comments_limit)
  }
  let doc = open_paren_break +
    @pretty.join(arguments, comma_break) +
    comma_break +
    t("..")
  let comments = self.pop_comments(comments_limit)
  match printed_comments(comments[:], false) {
    Some(c) =>
      @pretty.force_break(nest_if_broken(doc + trailing_comma_break + c)) +
      empty_break +
      t(")")
    None => nest_if_broken(doc) + trailing_comma_break + t(")")
  }
}
