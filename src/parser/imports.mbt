///|
/// `import a/b.{c, type D as E} as f`, with `import` consumed.
fn Parser::parse_import(
  self : Parser,
  import_start : @span.ByteOffset,
) -> @ast.Definition? raise ParseError {
  let mut start = @span.ByteOffset::zero()
  let mut end = @span.ByteOffset::zero()
  let module_ = StringBuilder()
  let mut last_segment_end = @span.ByteOffset::zero()
  // Gather module names
  while true {
    let (s, name, e) = self.expect_name(Module)
    if module_.is_empty() {
      start = s
    } else {
      module_.write_string("/")
    }
    module_.write_string(name)
    end = e
    last_segment_end = e
    // Useful error for `import a/.{b}`
    if self.maybe_one(SlashDot) is Some((slash, _)) {
      parse_error(
        ExpectedName,
        sp(slash.shift(1).unwrap(), slash.shift(1).unwrap()),
      )
    }
    if self.maybe_one(Slash) is None {
      break
    }
  }
  let module_name = module_.to_string()
  let documentation = self.take_documentation(start).map(d => d.text)
  let mut unqualified_values : Array[@ast.UnqualifiedImport] = []
  let mut unqualified_types : Array[@ast.UnqualifiedImport] = []
  if self.maybe_one(Dot) is Some((dot_start, dot_end)) {
    try self.expect_one(LeftBrace) catch {
      e => {
        // `import gleam.io`: a Python-like import, unless the module has a
        // `/` already.
        if module_name.contains("/") {
          raise e
        }
        match e {
          ParseError(
            error=UnexpectedToken(token=Name(item) | UpName(item), ..),
            ..
          ) =>
            parse_error(
              IncorrectImportModuleSeparator(module_=module_name, item~),
              sp(dot_start, dot_end),
            )
          _ => raise e
        }
      }
    } noraise {
      _ => ()
    }
    let (values, types) = self.parse_unqualified_imports()
    unqualified_values = values
    unqualified_types = types
    let (_, e) = self.expect_one(RightBrace)
    end = e
  }
  let mut as_name : @ast.ImportAlias? = None
  if self.maybe_one(Keyword(As)) is Some((as_start, _)) {
    let (_, name, e) = self.expect_assign_name()
    end = e
    as_name = Some({ name, location: sp(as_start, end), })
  }
  Some(
    Import({
      documentation,
      location: sp(import_start, end),
      module_location: sp(start, last_segment_end),
      module_: module_name,
      as_name,
      unqualified_values: unqualified_values[:],
      unqualified_types: unqualified_types[:],
    }),
  )
}

///|
/// `[Name (as Name)? | UpName (as UpName)? | type UpName (as UpName)?](, ...)*,?`
/// Not a `series_of`: a trailing comma here is not recorded.
fn Parser::parse_unqualified_imports(
  self : Parser,
) -> (Array[@ast.UnqualifiedImport], Array[@ast.UnqualifiedImport]) raise ParseError {
  let values : Array[@ast.UnqualifiedImport] = []
  let types : Array[@ast.UnqualifiedImport] = []
  while true {
    match self.token0 {
      Some({ kind: Name(name), span, .. }) => {
        self.advance()
        let mut location = span
        let mut as_alias : String? = None
        if self.maybe_one(Keyword(As)) is Some(_) {
          let (_, as_name, end) = self.expect_name(AsPattern)
          as_alias = Some(as_name)
          location = sp(span.start, end)
        }
        values.push({
          name,
          location,
          name_position: span.start,
          as_name: as_alias,
        })
      }
      Some({ kind: UpName(name), span, .. }) => {
        self.advance()
        let mut location = span
        let mut as_alias : String? = None
        if self.maybe_one(Keyword(As)) is Some(_) {
          let (_, as_name, end) = self.expect_upname()
          as_alias = Some(as_name)
          location = sp(span.start, end)
        }
        values.push({
          name,
          location,
          name_position: span.start,
          as_name: as_alias,
        })
      }
      Some({ kind: Keyword(Type), span, .. }) => {
        self.advance()
        let (name_start, name, end) = self.expect_upname()
        let mut location = sp(span.start, end)
        let mut as_alias : String? = None
        if self.maybe_one(Keyword(As)) is Some(_) {
          let (_, as_name, e) = self.expect_upname()
          as_alias = Some(as_name)
          location = sp(span.start, e)
        }
        types.push({
          name,
          location,
          name_position: name_start,
          as_name: as_alias,
        })
      }
      _ => break
    }
    if self.maybe_one(Comma) is None {
      break
    }
  }
  (values, types)
}

///|
/// `const name (: T)? = value`, with `const` (and `pub`) consumed.
fn Parser::parse_module_const(
  self : Parser,
  start : @span.ByteOffset,
  public : Bool,
  attributes : Attributes,
) -> @ast.Definition? raise ParseError {
  let (name_start, name, name_end) = self.expect_name(Constant)
  let documentation = self.take_documentation(name_start)
  let annotation = self.parse_type_annotation(Colon)
  let (eq_s, eq_e) = self.expect_one(Equal)
  match self.parse_const_value() {
    Some(value) => {
      let annotation_end = match annotation {
        Some(a) => a.location().end
        None => @span.ByteOffset::zero()
      }
      let publicity = publicity(public, attributes.internal)
      Some(
        ModuleConstant({
          documentation,
          // After the annotation when there is one, otherwise after the name.
          location: sp(
            start,
            if annotation_end > name_end {
              annotation_end
            } else {
              name_end
            },
          ),
          publicity,
          name,
          name_location: sp(name_start, name_end),
          annotation,
          value,
          deprecation: attributes.deprecated,
        }),
      )
    }
    None => parse_error(NoValueAfterEqual, sp(eq_s, eq_e))
  }
}
