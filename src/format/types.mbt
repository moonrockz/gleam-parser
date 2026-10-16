///|
/// The compiler's `type_ast_constructor`.
fn Formatter::type_ast_constructor(
  self : Formatter,
  name : @ast.TypeAstConstructorName,
  arguments : ArrayView[@ast.TypeAst],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  let head = match name {
    Unqualified(name~, ..) => t(name)
    Qualified(module_~, name~, ..) =>
      t(module_) +
      t(".") +
      (match name {
        Some(n) => t(n.name)
        None => @pretty.empty()
      })
  }
  if arguments.is_empty() {
    head
  } else {
    head + self.type_arguments(arguments, location)
  }
}

///|
/// The compiler's `type_ast`. One unit of fuel per nesting level.
fn Formatter::type_ast(
  self : Formatter,
  type_ : @ast.TypeAst,
) -> @pretty.Doc raise FormatError {
  self.nested(op_format, () => {
    let comments = self.pop_comments(type_.location().start)
    let doc = match type_ {
      Hole(h) => t(h.name)
      Constructor(c) =>
        self.type_ast_constructor(c.name, c.arguments, c.location)
      Fn(f) =>
        group(t("fn") + self.type_arguments(f.arguments, f.location)) +
        t(" ->") +
        nest(group(breakable_space + self.type_ast(f.return_)))
      Var(v) => t(v.name)
      Tuple(tu) => t("#") + self.type_arguments(tu.elements, tu.location)
    }
    commented(group(doc), comments[:])
  })
}

///|
/// The compiler's `type_arguments`.
fn Formatter::type_arguments(
  self : Formatter,
  arguments : ArrayView[@ast.TypeAst],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  let docs = []
  for a in arguments {
    docs.push(self.type_ast(a))
  }
  self.wrap_arguments(docs, location.end)
}

///|
/// The compiler's `type_alias`.
fn Formatter::type_alias(
  self : Formatter,
  alias_ : @ast.TypeAlias,
) -> @pretty.Doc raise FormatError {
  let attrs = attributes(alias_.deprecation, alias_.publicity, None, None)
  let head = attrs + pub_(alias_.publicity) + t("type ") + t(alias_.alias_)
  let head = if alias_.parameters.is_empty() {
    head
  } else {
    let args = alias_.parameters.iter().map(p => t(p.name)).to_array()
    head + group(self.wrap_arguments(args, alias_.location.end))
  }
  head + t(" =") + nest(group(line_doc + self.type_ast(alias_.type_ast)))
}
