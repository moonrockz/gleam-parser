///|
/// The compiler's `imports`: consecutive imports form groups, split at an
/// empty line or a comment; each group is sorted; groups are kept apart
/// by an empty line.
fn Formatter::imports(
  self : Formatter,
  imports : Array[@ast.TargetedDefinition],
) -> Array[@pretty.Doc] raise FormatError {
  let groups : Array[@pretty.Doc] = []
  let current : Array[@ast.TargetedDefinition] = []
  let mut delimiter = @pretty.empty()
  for import_ in imports {
    let start = import_.definition.location().start
    let start_new_group = self.any_comments(start) ||
      self.any_empty_lines(start)
    if start_new_group {
      if !current.is_empty() {
        groups.push(delimiter + self.sorted_import_group(current))
        current.clear()
      }
      let comments = self.pop_comments(start)
      let _ = self.pop_empty_lines(start)
      delimiter = printed_comments(comments[:], true).unwrap_or(@pretty.empty())
    }
    current.push(import_)
  }
  if !current.is_empty() {
    groups.push(delimiter + self.sorted_import_group(current))
  }
  // intersperse TWO_LINES_DOCUMENT
  let out : Array[@pretty.Doc] = []
  for i, g in groups {
    if i > 0 {
      out.push(two_lines_doc)
    }
    out.push(g)
  }
  out
}

///|
/// The compiler's `sorted_import_group`.
fn Formatter::sorted_import_group(
  self : Formatter,
  imports : Array[@ast.TargetedDefinition],
) -> @pretty.Doc raise FormatError {
  let sorted = stable_sort_by(imports, (a, b) => {
    match (a.definition, b.definition) {
      (Import(x), Import(y)) => lexicographic(x.module_, y.module_)
      _ => 0
    }
  })
  let docs = []
  for i in sorted {
    docs.push(self.targeted_definition(i))
  }
  @pretty.join(docs, line_doc)
}

///|
/// The compiler's `unqualified_import`.
fn unqualified_import(import_ : @ast.UnqualifiedImport) -> @pretty.Doc {
  t(import_.name) +
  (match import_.as_name {
    None => @pretty.empty()
    Some(s) if s == import_.name => @pretty.empty()
    Some(s) => t(" as ") + t(s)
  })
}

///|
/// The import arm of the compiler's `definition`.
fn import_(import_ : @ast.Import) -> @pretty.Doc {
  let second = if import_.unqualified_values.is_empty() &&
    import_.unqualified_types.is_empty() {
    @pretty.empty()
  } else {
    let by_name = (a : @ast.UnqualifiedImport, b : @ast.UnqualifiedImport) => {
      lexicographic(a.name, b.name)
    }
    let types = stable_sort_by(import_.unqualified_types.to_owned(), by_name)
    let values = stable_sort_by(import_.unqualified_values.to_owned(), by_name)
    let docs = []
    for i in types {
      docs.push(t("type ") + unqualified_import(i))
    }
    for i in values {
      docs.push(unqualified_import(i))
    }
    let unqualified = @pretty.join(docs, flex_comma)
    let unqualified = group(
      nest(empty_break + unqualified) + trailing_comma_break,
    )
    t(".{") + unqualified + t("}")
  }
  let doc = t("import ") + t(import_.module_) + second
  let default_name = match import_.module_.rev_find("/") {
    Some(i) => import_.module_.view(start_offset=i + 1).to_owned()
    None => import_.module_
  }
  match import_.as_name {
    None => doc
    Some({ name: Variable(name), .. }) if name == default_name => doc
    Some({ name: Variable(name) | Discard(name), .. }) =>
      doc + t(" as ") + t(name)
  }
}
