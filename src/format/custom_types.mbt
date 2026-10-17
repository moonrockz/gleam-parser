///|
/// The compiler's `record_constructor`.
async fn Formatter::record_constructor(
  self : Formatter,
  constructor_ : @ast.RecordConstructor,
) -> @pretty.Doc raise FormatError + nocancel {
  let comments = self.pop_comments(constructor_.location.start)
  let doc_comments = self.doc_comments(constructor_.location.start)
  let attrs = attributes(constructor_.deprecation, Private, None, None)
  let doc = if constructor_.arguments.is_empty() {
    if self.any_comments(constructor_.location.end) {
      group(
        attrs +
        t(constructor_.name) +
        self.wrap_arguments([], constructor_.location.end),
      )
    } else {
      attrs + t(constructor_.name)
    }
  } else {
    let arguments = []
    for a in constructor_.arguments {
      let arg_comments = self.pop_comments(a.location.start)
      let argument = match a.label {
        Some(label) => t(label.name) + t(": ") + self.type_ast(a.ast)
        None => self.type_ast(a.ast)
      }
      arguments.push(
        commented(
          group(self.doc_comments(a.location.start) + argument),
          arg_comments[:],
        ),
      )
    }
    attrs +
    t(constructor_.name) +
    group(self.wrap_arguments(arguments, constructor_.location.end))
  }
  commented(group(doc_comments + doc), comments[:])
}

///|
/// The compiler's `custom_type`.
async fn Formatter::custom_type(
  self : Formatter,
  type_ : @ast.CustomType,
) -> @pretty.Doc raise FormatError + nocancel {
  let _ = self.pop_empty_lines(type_.location.end)
  let attrs = attributes(
    type_.deprecation,
    type_.publicity,
    type_.external_erlang,
    type_.external_javascript,
  )
  let doc = attrs +
    pub_(type_.publicity) +
    (if type_.opaque_ { t("opaque type ") } else { t("type ") }) +
    (if type_.parameters.is_empty() {
      t(type_.name)
    } else {
      let args = type_.parameters.iter().map(p => t(p.name)).to_array()
      group(t(type_.name) + self.wrap_arguments(args, type_.location.end))
    })
  if type_.constructors.is_empty() {
    return doc
  }
  let doc = doc + t(" {")
  let inner_parts = []
  for c in type_.constructors {
    let sep = if self.pop_empty_lines(c.location.start) {
      two_lines_doc
    } else {
      line_doc
    }
    inner_parts.push(sep + self.record_constructor(c))
  }
  let inner = @pretty.concat(inner_parts)
  let inner = match
    printed_comments(self.pop_comments(type_.end_position)[:], false) {
    Some(c) => inner + line_doc + c
    None => inner
  }
  doc + group(nest(inner)) + line_doc + t("}")
}
