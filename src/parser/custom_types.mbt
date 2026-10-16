///|
/// A custom type or a type alias, with `type` (and `pub`, `opaque`)
/// consumed.
fn Parser::parse_custom_type(
  self : Parser,
  start : @span.ByteOffset,
  public : Bool,
  opaque_ : Bool,
  attributes : Attributes,
) -> @ast.Definition? raise ParseError {
  let documentation = self.take_documentation(start)
  let (name_start, name, parameters, end, name_end) = self.expect_type_name()
  let name_location = sp(name_start, name_end)
  let (constructors, end_position) : (
    Array[@ast.RecordConstructor],
    @span.ByteOffset,
  ) = match self.token0 {
    // `type Wibble {`: a custom type
    Some({ kind: LeftBrace, .. }) => {
      self.advance()
      // A lower-case name here is a syntax error with a helpful message.
      if self.token0 is Some({ kind: Name(_), span, .. }) {
        raise self.invalid_record_constructor_error(
          name,
          public,
          opaque_,
          span.start,
          span.end,
        )
      }
      let constructors = self.series_of(p => p.parse_record_constructor(), None)
      let close_end = self.expect_custom_type_close()
      (constructors, close_end)
    }
    // `type Wibble =`: a type alias
    Some({ kind: Equal, span: equal, .. }) => {
      self.advance()
      if opaque_ {
        parse_error(OpaqueTypeAlias, sp(start, end))
      }
      match self.parse_type() {
        Some(type_ast) => {
          let publicity = publicity(public, attributes.internal)
          return Some(
            TypeAlias({
              documentation,
              location: sp(start, type_ast.location().end),
              publicity,
              alias_: name,
              name_location,
              parameters: parameters[:],
              type_ast,
              deprecation: attributes.deprecated,
            }),
          )
        }
        None => parse_error(ExpectedType, equal)
      }
    }
    _ => ([], end)
  }
  let publicity = publicity(public, attributes.internal)
  Some(
    CustomType({
      documentation,
      location: sp(start, end),
      end_position,
      publicity,
      opaque_,
      name,
      name_location,
      parameters: parameters[:],
      constructors: constructors[:],
      deprecation: attributes.deprecated,
      external_erlang: attributes.external_erlang,
      external_javascript: attributes.external_javascript,
    }),
  )
}

///|
/// One variant: attributes (only `@deprecated` is allowed), an upper-case
/// name and optional `(fields)`.
fn Parser::parse_record_constructor(
  self : Parser,
) -> @ast.RecordConstructor? raise ParseError {
  let attributes = Attributes::new()
  let attr_loc = self.parse_attributes(attributes)
  if attr_loc is Some(attr_span) {
    if attributes.external_erlang is Some(_) ||
      attributes.external_javascript is Some(_) ||
      attributes.target is Some(_) ||
      attributes.internal is Some(_) {
      parse_error(UnknownAttributeRecordVariant, attr_span)
    }
  }
  match self.maybe_upname() {
    Some((name_start, constructor_name, name_end)) => {
      let documentation = self.take_documentation(name_start)
      let (arguments, arguments_end) = self.parse_record_constructor_arguments()
      Some({
        location: sp(
          name_start,
          if arguments_end > name_end {
            arguments_end
          } else {
            name_end
          },
        ),
        name_location: sp(name_start, name_end),
        name: constructor_name,
        arguments: arguments[:],
        documentation,
        deprecation: attributes.deprecated,
      })
    }
    None => None
  }
}

///|
/// A lower-case name where a variant was expected: `ExpectedRecordConstructor`
/// when the type looks like a record (fields, then `}`), otherwise
/// `IncorrectUpName`.
fn Parser::invalid_record_constructor_error(
  self : Parser,
  type_name : String,
  public : Bool,
  opaque_ : Bool,
  name_start : @span.ByteOffset,
  name_end : @span.ByteOffset,
) -> ParseError {
  let fields = try
    self.series_of(p => p.parse_record_constructor_field(), Some(Comma))
  catch {
    _ => None
  } noraise {
    f => Some(f)
  }
  match fields {
    Some(fields) if self.token0 is Some({ kind: RightBrace, .. }) => {
      let start = if fields.length() > 0 {
        fields[0].location.start
      } else {
        name_start
      }
      let end = if fields.length() > 0 {
        fields[fields.length() - 1].location.end
      } else {
        name_end
      }
      ParseError(
        error=ExpectedRecordConstructor(
          type_name~,
          public~,
          opaque_~,
          fields=fields[:],
        ),
        location=sp(start, end),
      )
    }
    _ => ParseError(error=IncorrectUpName, location=sp(name_start, name_end))
  }
}

///|
/// `(field, label: Type, …)` of a variant; `end` is 0 with no parentheses.
fn Parser::parse_record_constructor_arguments(
  self : Parser,
) -> (Array[@ast.RecordConstructorArg], @span.ByteOffset) raise ParseError {
  if self.maybe_one(LeftParen) is Some(_) {
    let arguments = self.series_of(
      p => p.parse_record_constructor_field(),
      Some(Comma),
    )
    let (_, end) = self.expect_one_following_series(
      RightParen,
      "a constructor argument name",
    )
    (arguments, end)
  } else {
    ([], @span.ByteOffset::zero())
  }
}

///|
/// `label: Type` or `Type`, with the doc comment before it.
fn Parser::parse_record_constructor_field(
  self : Parser,
) -> @ast.RecordConstructorArg? raise ParseError {
  match (self.token0, self.token1) {
    (
      Some({ kind: Name(name), span, .. }),
      Some({ kind: Colon, span: colon, .. }),
    ) => {
      self.advance()
      self.advance()
      let doc = self.take_documentation(span.start)
      match self.parse_type() {
        Some(type_ast) =>
          Some({
            label: Some({ location: span, name, }),
            ast: type_ast,
            location: sp(span.start, type_ast.location().end),
            doc,
          })
        None => parse_error(ExpectedType, sp(span.start, colon.end))
      }
    }
    _ =>
      match self.parse_type() {
        Some(type_ast) => {
          let doc = match self.token0 {
            Some(t) => self.take_documentation(t.span.start)
            None => None
          }
          Some({
            label: None,
            ast: type_ast,
            location: type_ast.location(),
            doc,
          })
        }
        None => None
      }
  }
}

///|
/// `Name` or `Name(a, b)`: start, name, parameters, end after `)` (or the
/// name), and the name's end.
fn Parser::expect_type_name(
  self : Parser,
) -> (
  @span.ByteOffset,
  String,
  Array[@ast.SpannedString],
  @span.ByteOffset,
  @span.ByteOffset,
) raise ParseError {
  let (start, upname, end) = self.expect_upname()
  match self.maybe_one(LeftParen) {
    Some((par_s, _)) => {
      let arguments = self.series_of(p => p.maybe_name(), Some(Comma))
      let (_, par_e) = self.expect_one_following_series(RightParen, "a name")
      if arguments.length() == 0 {
        parse_error(TypeDefinitionNoArguments, sp(par_s, par_e))
      }
      let parameters = arguments.map(a => @ast.SpannedString::{
        location: sp(a.0, a.2),
        name: a.1,
      })
      (start, upname, parameters, par_e, end)
    }
    None =>
      match self.maybe_one(Less) {
        Some((less_start, less_end)) => {
          // Names or upnames are accepted in this error path; the example in
          // the message uses lower case.
          let arguments = self.series_of(
            p => {
              match p.maybe_name() {
                Some(n) => Some(n.1.to_lower())
                None => p.maybe_upname().map(n => n.1.to_lower())
              }
            },
            Some(Comma),
          )
          let arguments = if arguments.length() == 0 {
            ["value"]
          } else {
            arguments
          }
          parse_error(
            TypeDefinitionAngleGenerics(name=upname, arguments=arguments[:]),
            sp(less_start, less_end),
          )
        }
        None => (start, upname, [], end, end)
      }
  }
}

///|
/// The `}` of a custom type, or `UnexpectedToken` with a hint when a
/// function follows (Gleam has no methods).
fn Parser::expect_custom_type_close(
  self : Parser,
) -> @span.ByteOffset raise ParseError {
  match self.maybe_one(RightBrace) {
    Some((_, end)) => end
    None =>
      match self.next_token() {
        None =>
          parse_error(
            UnexpectedEof,
            sp(@span.ByteOffset::zero(), @span.ByteOffset::zero()),
          )
        Some(t) => {
          let hint = match (t.kind, self.token0) {
            (Keyword(Fn), _)
            | (Keyword(Pub), Some({ kind: Keyword(Fn), .. })) =>
              Some(
                @scanner.wrap(
                  "Gleam is not an object oriented programming language so\nfunctions are declared separately from types.",
                ),
              )
            _ => None
          }
          parse_error(
            UnexpectedToken(
              token=t.kind,
              expected=[token_text(RightBrace), "a record constructor"][:],
              hint~,
            ),
            t.span,
          )
        }
      }
  }
}
