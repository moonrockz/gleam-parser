///|
/// The compiler's `argument_names`.
fn argument_names(names : @ast.ArgNames) -> @pretty.Doc {
  match names {
    Named(name~, ..) | Discard(name~, ..) => t(name)
    LabelledDiscard(label~, name~, ..) | NamedLabelled(label~, name~, ..) =>
      t(label) + t(" ") + t(name)
  }
}

///|
/// The compiler's `fn_arg`.
async fn Formatter::fn_arg(
  self : Formatter,
  argument : @ast.Arg,
) -> @pretty.Doc raise FormatError + nocancel {
  let comments = self.pop_comments(argument.location.start)
  let doc = match argument.annotation {
    None => argument_names(argument.names)
    Some(type_) =>
      argument_names(argument.names) + t(": ") + self.type_ast(type_)
  }
  commented(group(doc), comments[:])
}

///|
/// The compiler's `statement_fn`.
async fn Formatter::statement_fn(
  self : Formatter,
  function : @ast.Function,
) -> @pretty.Doc raise FormatError + nocancel {
  let attrs = attributes(
    function.deprecation,
    function.publicity,
    function.external_erlang,
    function.external_javascript,
  )
  let arguments = []
  for a in function.arguments {
    arguments.push(self.fn_arg(a))
  }
  let name = match function.name {
    Some(n) => n.name
    None => ""
  }
  let comments_limit = match function.return_annotation {
    Some(ann) => ann.location().start
    None => function.location.end
  }
  let signature = pub_(function.publicity) +
    t("fn ") +
    t(name) +
    self.wrap_arguments(arguments, comments_limit)
  let signature = match function.return_annotation {
    Some(annotation) => signature + t(" -> ") + self.type_ast(annotation)
    None => signature
  }
  if function.body.is_empty() {
    return attrs + group(signature)
  }
  let body = self.statements(function.body)
  let comments = self.pop_comments(function.end_position)
  let body = match printed_comments(comments[:], false) {
    Some(c) => body + line_doc + c
    None => body
  }
  let function_doc = group(signature + t(" {")) +
    group(nest(line_doc + body)) +
    line_doc +
    t("}")
  attrs + function_doc
}
