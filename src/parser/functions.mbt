///|
/// The name the compiler gives a capture's argument (`CAPTURE_VARIABLE`).
let capture_variable : String = "_capture"

///|
/// A parsed call argument: a value, or a hole (`_`) that makes the call a
/// capture.
priv enum ParserArg {
  Arg(@ast.CallArg[@ast.Expr])
  Hole(
    name~ : String,
    arg_location~ : @span.SrcSpan,
    discard_location~ : @span.SrcSpan,
    label~ : String?
  )
}

///|
/// A function head and body, after `fn` (and `pub`). `is_anon` for a
/// function literal: no name, no labels. Returns `Definition::Function`.
async fn Parser::parse_function(
  self : Parser,
  start : @span.ByteOffset,
  public : Bool,
  is_anon : Bool,
  attributes : Attributes,
) -> @ast.Definition? raise ParseError + nocancel {
  let documentation = if is_anon {
    None
  } else {
    self.take_documentation(start)
  }
  let mut name : @ast.SpannedString? = None
  if !is_anon {
    let (name_start, n, name_end) = self.expect_name(Function)
    name = Some({ location: sp(name_start, name_end), name: n, })
  }
  if self.maybe_one(Less) is Some((less_start, less_end)) {
    parse_error(FunctionDefinitionAngleGenerics, sp(less_start, less_end))
  }
  let _ = try self.expect_one(LeftParen) catch {
    e => raise add_anonymous_fn_hint(e)
  } noraise {
    v => v
  }
  let arguments = self.series_of(p => p.parse_fn_param(is_anon), Some(Comma))
  let (_, rpar_e) = self.expect_one_following_series(
    RightParen,
    "a function parameter",
  )
  // TypeScript-style return type annotation
  if self.maybe_one(Colon) is Some((colon_start, colon_end)) {
    parse_error(
      UnexpectedToken(
        token=Colon,
        expected=[token_text(RArrow)][:],
        hint=Some("Return type annotations are written using `->`, not `:`"),
      ),
      sp(colon_start, colon_end),
    )
  }
  let return_annotation = self.parse_type_annotation(RArrow)
  let (body_start, body, end, end_position) = match self.maybe_one(LeftBrace) {
    Some((left_brace_start, _)) => {
      let some_body = self.parse_statement_sequence()
      let (_, right_brace_end) = self.expect_one(RightBrace)
      let end = match return_annotation {
        Some(t) => t.location().end
        None => rpar_e
      }
      let body : Array[@ast.Statement] = match some_body {
        None =>
          [
            Expression(
              Todo(
                kind=EmptyFunction(function_location=sp(start, end)),
                location=sp(left_brace_start.shift(1).unwrap(), right_brace_end),
                message=None,
              ),
            ),
          ]
        Some((body, _)) => body
      }
      (Some(left_brace_start), body, end, right_brace_end)
    }
    None => (None, [], rpar_e, rpar_e)
  }
  let publicity = publicity(public, attributes.internal)
  Some(
    Function({
      documentation,
      location: sp(start, end),
      end_position,
      body_start,
      publicity,
      name,
      arguments: arguments[:],
      body: body[:],
      return_annotation,
      deprecation: attributes.deprecated,
      external_erlang: attributes.external_erlang,
      external_javascript: attributes.external_javascript,
    }),
  )
}

///|
/// `Public`, `Private` or `Internal`; `@internal` on a private definition
/// is `RedundantInternalAttribute` at the attribute.
fn publicity(
  public : Bool,
  internal : @span.SrcSpan?,
) -> @ast.Publicity raise ParseError {
  match (internal, public) {
    (None, true) => Public
    (None, false) => Private
    (Some(location), true) => Internal(attribute_location=Some(location))
    (Some(location), false) => parse_error(RedundantInternalAttribute, location)
  }
}

///|
/// One parameter: `_`, `a`, `label a`, `label _`, each with `: Type`.
async fn Parser::parse_fn_param(
  self : Parser,
  is_anon : Bool,
) -> @ast.Arg? raise ParseError + nocancel {
  let (start, names, end0) : (@span.ByteOffset, @ast.ArgNames, @span.ByteOffset) = match
    (self.token0, self.token1) {
    // labelled discard
    (
      Some({ kind: Name(label), span: label_span, .. }),
      Some({ kind: DiscardName(name), span: name_span, .. }),
    ) => {
      if is_anon {
        parse_error(UnexpectedLabel, label_span)
      }
      self.advance()
      self.advance()
      (
        label_span.start,
        LabelledDiscard(
          name~,
          name_location=name_span,
          label~,
          label_location=label_span,
        ),
        name_span.end,
      )
    }
    // discard
    (Some({ kind: DiscardName(name), span, .. }), _) => {
      self.advance()
      (span.start, Discard(name~, location=span), span.end)
    }
    // labelled name
    (
      Some({ kind: Name(label), span: label_span, .. }),
      Some({ kind: Name(name), span: name_span, .. }),
    ) => {
      if is_anon {
        parse_error(UnexpectedLabel, label_span)
      }
      self.advance()
      self.advance()
      (
        label_span.start,
        NamedLabelled(
          name~,
          name_location=name_span,
          label~,
          label_location=label_span,
        ),
        name_span.end,
      )
    }
    // name
    (Some({ kind: Name(name), span, .. }), _) => {
      self.advance()
      (span.start, Named(name~, location=span), span.end)
    }
    _ => return None
  }
  let annotation = self.parse_type_annotation(Colon)
  let end = match annotation {
    Some(a) => a.location().end
    None => end0
  }
  Some({ location: sp(start, end), names, annotation, })
}

///|
/// Call arguments without the parentheses.
async fn Parser::parse_fn_arguments(
  self : Parser,
) -> Array[ParserArg] raise ParseError + nocancel {
  self.series_of(p => p.parse_fn_argument(), Some(Comma))
}

///|
/// One call argument: `_`, `expr`, `a: _`, `a: expr`, `a:`.
async fn Parser::parse_fn_argument(
  self : Parser,
) -> ParserArg? raise ParseError + nocancel {
  let label : (@span.ByteOffset, String, @span.ByteOffset)? = match
    (self.token0, self.token1) {
    (
      Some({ kind: Name(name), span, .. }),
      Some({ kind: Colon, span: colon, .. }),
    ) => {
      self.advance()
      self.advance()
      Some((span.start, name, colon.end))
    }
    _ => None
  }
  match self.parse_expression() {
    Some(value) =>
      match label {
        Some((start, label, _)) =>
          Some(
            Arg({
              implicit: None,
              label: Some(label),
              location: sp(start, value.location().end),
              value,
            }),
          )
        None =>
          Some(
            Arg({
              implicit: None,
              label: None,
              location: value.location(),
              value,
            }),
          )
      }
    None =>
      match self.maybe_discard_name() {
        Some((name_start, name, name_end)) =>
          match label {
            Some((label_start, label, _)) =>
              Some(
                Hole(
                  label=Some(label),
                  arg_location=sp(label_start, name_end),
                  discard_location=sp(name_start, name_end),
                  name~,
                ),
              )
            None =>
              Some(
                Hole(
                  label=None,
                  arg_location=sp(name_start, name_end),
                  discard_location=sp(name_start, name_end),
                  name~,
                ),
              )
          }
        None =>
          match label {
            Some((start, label, end)) =>
              Some(
                Arg({
                  implicit: None,
                  label: Some(label),
                  location: sp(start, end),
                  value: Var(name=label, location=sp(start, end)),
                }),
              )
            None => None
          }
      }
  }
}

///|
/// A call, or a capture (`f(_, 1)`) when one argument is a hole.
fn make_call(
  fun : @ast.Expr,
  arguments : Array[ParserArg],
  start : @span.ByteOffset,
  end : @span.ByteOffset,
  open_parenthesis : @span.ByteOffset,
) -> @ast.Expr raise ParseError {
  let mut hole_location : @span.SrcSpan? = None
  let call_arguments : Array[@ast.CallArg[@ast.Expr]] = []
  for argument in arguments {
    match argument {
      Arg(arg) => call_arguments.push(arg)
      Hole(name~, arg_location~, discard_location~, label~) => {
        if hole_location is Some(_) {
          parse_error(TooManyArgHoles, sp(start, end))
        }
        hole_location = Some(discard_location)
        if name != "_" {
          parse_error(
            UnexpectedToken(
              token=Name(name),
              expected=["An expression", "An underscore"][:],
              hint=None,
            ),
            arg_location,
          )
        }
        call_arguments.push({
          implicit: None,
          label,
          location: arg_location,
          value: Var(location=discard_location, name=capture_variable),
        })
      }
    }
  }
  let call : @ast.Expr = Call(
    location=sp(start, end),
    fun~,
    arguments=call_arguments[:],
    open_parenthesis~,
  )
  match hole_location {
    None => call
    Some(hole) =>
      Fn(
        location=sp(start, end),
        end_of_head_byte_index=end,
        kind=Capture(hole~),
        arguments=[
            @ast.Arg::{
              location: hole,
              annotation: None,
              names: Named(name=capture_variable, location=hole),
            },
          ][:],
        body=[@ast.Statement::Expression(call)][:],
        return_annotation=None,
      )
  }
}

///|
/// The doc comments before `until` that no regular comment separates from
/// it, joined with `\n` after each line, and their start. A doc comment
/// with a regular comment between it and `until` is detached (a warning)
/// and dropped. Doc comments at or after `until` stay for the next
/// definition.
fn Parser::take_documentation(
  self : Parser,
  until : @span.ByteOffset,
) -> @ast.Documentation? {
  let content = StringBuilder()
  let mut doc_start = @span.ByteOffset::from_int(2147483647).unwrap()
  while self.doc_head < self.doc_comments.length() {
    let (span, line) = self.doc_comments[self.doc_head]
    if span.start < doc_start {
      doc_start = span.start
    }
    if span.start >= until {
      break
    }
    if self.has_comment_between(span.start, until) {
      // A doc comment before a regular comment is ignored.
      self.doc_head += 1
      self.detached_doc_comments.push(span)
      continue
    }
    content.write_string(line)
    content.write_string("\n")
    self.doc_head += 1
  }
  let text = content.to_string()
  if text == "" {
    None
  } else {
    Some({ start: doc_start, text, })
  }
}

///|
/// Whether a regular comment overlaps `start..end` (inclusive at both
/// ends), as `ModuleExtra::has_comment_between`.
fn Parser::has_comment_between(
  self : Parser,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
) -> Bool {
  for c in self.comments {
    if c.end >= start && c.start <= end {
      return true
    }
    if c.start > end {
      break
    }
  }
  false
}
