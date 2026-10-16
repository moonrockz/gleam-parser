///|
/// What `parse_module` returns: the AST (`module_`), the compiler's
/// `extra`, the warnings, the CST (every token, grouped per definition, also
/// the skipped ones) and the diagnostics. A definition with a syntax error
/// is not in `module_`; its tokens are a `Skipped` run in `cst`.
///
/// ```mbt check
/// test {
///   let r = @parser.parse_text("pub fn main() {\n  1\n}\n")
///   inspect(r.module_.definitions.length(), content="1")
///   inspect(r.has_errors(), content="false")
///   inspect(r.cst.to_source(), content="pub fn main() {\n  1\n}\n")
/// }
/// ```
pub(all) struct ParseResult {
  module_ : @ast.Module
  extra : @ast.ModuleExtra
  warnings : ArrayView[@ast.Warning]
  cst : @cst.ModuleCst
  diagnostics : ArrayView[@diagnostic.Diagnostic]
} derive(Eq, Debug)

///|
/// The oracle's `Parsed` shape: module, extra and warnings.
pub fn ParseResult::parsed(self : ParseResult) -> @ast.Parsed {
  { module_: self.module_, extra: self.extra, warnings: self.warnings, }
}

///|
/// Whether any diagnostic is an error.
pub fn ParseResult::has_errors(self : ParseResult) -> Bool {
  self.diagnostics.any(d => d.is_error())
}

///|
/// Parse a token stream into a module. Recovery per definition: an error is
/// reported, the parser skips to the next definition start (`import`,
/// `const`, `pub`, `fn`, `type`, `opaque` or `@` in column 1) and goes on.
/// The first error diagnostic has the compiler's kind and span. `config`
/// gives the dialect and the fuel budget (`Config::default()` when
/// absent).
pub fn parse_module(
  stream : @scanner.TokenStream,
  config? : @config.Config,
) -> ParseResult {
  let config = config.unwrap_or(@config.Config::default())
  let p = Parser(stream, config)
  let definitions : Array[@ast.TargetedDefinition] = []
  let cst_definitions : Array[@cst.DefinitionCst] = []
  let parse_diagnostics : Array[@diagnostic.Diagnostic] = []
  let mut first_error_lookahead : @span.ByteOffset? = None
  fn report(e : ParseError) {
    parse_diagnostics.push(e.to_diagnostic())
    if first_error_lookahead is None {
      first_error_lookahead = Some(p.farthest)
    }
  }

  while p.index0 < p.tokens.length() {
    let start_index = p.index0
    let warnings_start = p.warnings.length()
    let detached_start = p.detached_doc_comments.length()
    let commas_start = p.trailing_commas.length()
    let outcome = try p.parse_definition() catch {
      e => Err(e)
    } noraise {
      d => Ok(d)
    }
    match outcome {
      Ok(Some(targeted)) => {
        let tokens = p.tokens[start_index:p.index0]
        definitions.push(targeted)
        let (kind, name) = cst_kind(targeted.definition)
        cst_definitions.push(@cst.DefinitionCst(kind~, name~, tokens~))
      }
      Ok(None) => {
        p.warnings.truncate(warnings_start)
        p.detached_doc_comments.truncate(detached_start)
        p.trailing_commas.truncate(commas_start)
        // Not a definition start: a stray token (reported as the compiler
        // does) or a hole left by a lexical error (reported by the scanner).
        if p.token0 is Some(t) {
          report(
            ParseError(
              error=UnexpectedToken(
                token=t.kind,
                expected=["An import, const, type, or function."][:],
                hint=None,
              ),
              location=t.span,
            ),
          )
        }
        p.recover(start_index, cst_definitions)
      }
      Err(e) => {
        p.warnings.truncate(warnings_start)
        p.detached_doc_comments.truncate(detached_start)
        p.trailing_commas.truncate(commas_start)
        report(e)
        p.recover(start_index, cst_definitions)
      }
    }
  }
  let warnings : Array[@ast.Warning] = p.warnings.copy()
  for span in p.detached_doc_comments {
    warnings.push(DetachedDocComment(location=span))
  }
  for w in warnings {
    parse_diagnostics.push(warning_diagnostic(w))
  }
  let trivia = @cst.trivia_extra(stream)
  let extra : @ast.ModuleExtra = {
    ..trivia,
    trailing_commas: p.trailing_commas[:],
  }
  {
    module_: { definitions: definitions[:], },
    extra,
    warnings: warnings[:],
    cst: @cst.ModuleCst(stream, cst_definitions),
    diagnostics: order_diagnostics(
      stream.diagnostics,
      parse_diagnostics,
      first_error_lookahead,
      p.farthest,
    )[:],
  }
}

///|
/// `parse_module` of the tokens of `text`.
pub fn parse_text(text : String, config? : @config.Config) -> ParseResult {
  parse_module(@scanner.tokenize_text(text), config?)
}

///|
fn cst_kind(d : @ast.Definition) -> (@cst.DefinitionKind, String?) {
  match d {
    Function(f) => (Function, f.name.map(n => n.name))
    TypeAlias(t) => (TypeAlias, Some(t.alias_))
    CustomType(c) => (CustomType, Some(c.name))
    Import(i) => (Import, Some(i.module_))
    ModuleConstant(c) => (Constant, Some(c.name))
  }
}

///|
/// Skip from the failed definition's first token to the next definition
/// start (or the end), record the run as a `Skipped` CST definition and
/// point the lookahead at the start.
fn Parser::recover(
  self : Parser,
  from : Int32,
  cst_definitions : Array[@cst.DefinitionCst],
) -> Unit {
  let mut i = from + 1
  while i < self.tokens.length() && !self.at_definition_start(i) {
    i += 1
  }
  cst_definitions.push(
    @cst.DefinitionCst(kind=Skipped, name=None, tokens=self.tokens[from:i]),
  )
  // Doc comments inside the skipped run belong to the skipped definition,
  // not to the next one.
  if i > from {
    let run_end = self.tokens[i - 1].span.end
    while self.doc_head < self.doc_comments.length() &&
          self.doc_comments[self.doc_head].0.start < run_end {
      self.doc_head += 1
    }
  }
  self.seek(i)
}

///|
/// The compiler's order: a lexical error that its lexer reached before the
/// parser stopped (start before `first_error_lookahead`) comes first; then
/// everything else by position, `UnexpectedEof` (span `0..0`) at the end
/// of the text.
fn order_diagnostics(
  scanner : ArrayView[@diagnostic.Diagnostic],
  parser : Array[@diagnostic.Diagnostic],
  first_error_lookahead : @span.ByteOffset?,
  text_end : @span.ByteOffset,
) -> Array[@diagnostic.Diagnostic] {
  let first : Array[@diagnostic.Diagnostic] = []
  let rest : Array[@diagnostic.Diagnostic] = []
  for d in scanner {
    match first_error_lookahead {
      Some(lookahead) if d.span.start < lookahead => first.push(d)
      _ => rest.push(d)
    }
  }
  for d in parser {
    rest.push(d)
  }
  fn key(d : @diagnostic.Diagnostic) -> @span.ByteOffset {
    if d.kind == "UnexpectedEof" {
      text_end
    } else {
      d.span.start
    }
  }

  // A stable sort by position: insertion into `first`.
  for d in rest {
    let mut i = first.length()
    while i > 0 &&
          key(first[i - 1]) > key(d) &&
          !(first_error_lookahead is Some(l) &&
          first[i - 1].code == "GL-SCAN-001" &&
          first[i - 1].span.start < l) {
      i -= 1
    }
    first.insert(i, d)
  }
  first
}

///|
/// One definition with its attributes; `None` when `token0` does not start
/// one (and no attribute was seen).
fn Parser::parse_definition(
  self : Parser,
) -> @ast.TargetedDefinition? raise ParseError {
  let attributes = Attributes()
  let location = self.parse_attributes(attributes)
  let def : @ast.Definition? = match (self.token0, self.token1) {
    (Some({ kind: Keyword(Import), span, .. }), _) => {
      self.advance()
      self.parse_import(span.start)
    }
    (Some({ kind: Keyword(Const), span, .. }), _) => {
      self.advance()
      self.parse_module_const(span.start, false, attributes)
    }
    (Some({ kind: Keyword(Pub), span, .. }), Some({ kind: Keyword(Const), .. })) => {
      self.advance()
      self.advance()
      self.parse_module_const(span.start, true, attributes)
    }
    (Some({ kind: Keyword(Fn), span, .. }), _) => {
      self.advance()
      self.parse_function(span.start, false, false, attributes)
    }
    (Some({ kind: Keyword(Pub), span, .. }), Some({ kind: Keyword(Fn), .. })) => {
      self.advance()
      self.advance()
      self.parse_function(span.start, true, false, attributes)
    }
    (Some({ kind: Keyword(Type), span, .. }), _) => {
      self.advance()
      self.parse_custom_type(span.start, false, false, attributes)
    }
    (Some({ kind: Keyword(Pub), span, .. }), Some({ kind: Keyword(Opaque), .. })
    ) => {
      self.advance()
      self.advance()
      let _ = self.expect_one(Keyword(Type))
      self.parse_custom_type(span.start, true, true, attributes)
    }
    (Some({ kind: Keyword(Pub), span, .. }), Some({ kind: Keyword(Type), .. })) => {
      self.advance()
      self.advance()
      self.parse_custom_type(span.start, true, false, attributes)
    }
    // A private opaque type is an analysis error, not a parse error.
    (
      Some({ kind: Keyword(Opaque), span, .. }),
      Some({ kind: Keyword(Type), .. }),
    ) => {
      self.advance()
      self.advance()
      self.parse_custom_type(span.start, false, true, attributes)
    }
    _ => None
  }
  match (def, location) {
    (Some(definition), _) if definition is Function(_) ||
      definition is CustomType(_) =>
      Some({ definition, target: attributes.target, })
    (Some(definition), None) => Some({ definition, target: attributes.target, })
    (_, Some(location)) if attributes.has_function_only() =>
      parse_error(ExpectedFunctionDefinition, location)
    (Some(definition), _) => Some({ definition, target: attributes.target, })
    (_, Some(location)) => parse_error(ExpectedDefinition, location)
    (None, None) => None
  }
}

///|
/// `@name(...)` attributes; their span, or `None` without any.
fn Parser::parse_attributes(
  self : Parser,
  attributes : Attributes,
) -> @span.SrcSpan? raise ParseError {
  let mut attributes_span : @span.SrcSpan? = None
  while self.maybe_one(At) is Some((start, end)) {
    if attributes_span is None {
      attributes_span = Some(sp(start, end))
    }
    let end = self.parse_attribute(start, attributes)
    attributes_span = attributes_span.map(s => sp(s.start, end))
  }
  attributes_span
}

///|
fn Parser::parse_attribute(
  self : Parser,
  start : @span.ByteOffset,
  attributes : Attributes,
) -> @span.ByteOffset raise ParseError {
  let (_, name, end) = self.expect_name(Attribute)
  if !self.config.dialect.knows_attribute(name) {
    parse_error(UnknownAttribute, sp(start, end))
  }
  match name {
    "external" => {
      if self.maybe_one(LeftParen) is None {
        parse_error(ExpectedExternalArguments, sp(start, end))
      }
      self.parse_external_attribute(start, end, attributes)
    }
    "target" => self.parse_target_attribute(start, end, attributes)
    "deprecated" => self.parse_deprecated_attribute(start, end, attributes)
    "internal" => parse_internal_attribute(start, end, attributes)
    _ => parse_error(UnknownAttribute, sp(start, end))
  }
}

///|
fn Parser::parse_target_attribute(
  self : Parser,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
  attributes : Attributes,
) -> @span.ByteOffset raise ParseError {
  let (paren_start, paren_end) = self.expect_one(LeftParen)
  let target = self.expect_target(sp(paren_start, paren_end))
  if attributes.target is Some(_) {
    parse_error(DuplicateAttribute, sp(start, end))
  }
  let (_, close) = self.expect_one(RightParen)
  attributes.target = Some(target)
  close
}

///|
/// `erlang` or `javascript`; the shorthands `erl` and `js` with a
/// deprecation warning; `UnknownTarget` for another name;
/// `ExpectedTargetName` at the parenthesis for anything else.
fn Parser::expect_target(
  self : Parser,
  paren_location : @span.SrcSpan,
) -> @ast.Target raise ParseError {
  match self.next_token() {
    None =>
      parse_error(
        UnexpectedEof,
        sp(@span.ByteOffset::zero(), @span.ByteOffset::zero()),
      )
    Some({ kind: Name(name), span, .. }) =>
      match name {
        "js" => {
          self.warn(DeprecatedTargetShorthand(location=span, target=JavaScript))
          JavaScript
        }
        "erl" => {
          self.warn(DeprecatedTargetShorthand(location=span, target=Erlang))
          Erlang
        }
        _ =>
          match @ast.Target::of(name) {
            Some(t) if self.config.dialect.knows_target(name) => t
            _ => parse_error(UnknownTarget, span)
          }
      }
    Some(_) => parse_error(ExpectedTargetName, paren_location)
  }
}

///|
fn Parser::parse_external_attribute(
  self : Parser,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
  attributes : Attributes,
) -> @span.ByteOffset raise ParseError {
  let (_, target_name, _) = self.expect_name(Target)
  let target : @ast.Target = match @ast.Target::of(target_name) {
    Some(t) if self.config.dialect.knows_target(target_name) => t
    _ => parse_error(UnknownTarget, sp(start, end))
  }
  let _ = self.expect_one(Comma)
  let (_, module_, _) = self.expect_string()
  let _ = self.expect_one(Comma)
  let (_, function, _) = self.expect_string()
  let _ = self.maybe_one(Comma)
  let (_, close) = self.expect_one(RightParen)
  if attributes.has_external_for(target) {
    parse_error(DuplicateAttribute, sp(start, close))
  }
  attributes.set_external_for(target, {
    module_,
    function,
    location: sp(start, close),
  })
  close
}

///|
fn Parser::parse_deprecated_attribute(
  self : Parser,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
  attributes : Attributes,
) -> @span.ByteOffset raise ParseError {
  // As the compiler, `expect_one` and `expect_string` consume a token when
  // they fail (its lexer then reads one token further); the error is
  // replaced by `ExpectedDeprecationMessage`.
  let _ = try self.expect_one(LeftParen) catch {
    _ => parse_error(ExpectedDeprecationMessage, sp(start, end))
  } noraise {
    v => v
  }
  if attributes.deprecated is Deprecated(..) {
    parse_error(DuplicateAttribute, sp(start, end))
  }
  let (_, message, _) = try self.expect_string() catch {
    _ => parse_error(ExpectedDeprecationMessage, sp(start, end))
  } noraise {
    v => v
  }
  let (_, close) = self.expect_one(RightParen)
  attributes.deprecated = Deprecated(message~)
  close
}

///|
fn parse_internal_attribute(
  start : @span.ByteOffset,
  end : @span.ByteOffset,
  attributes : Attributes,
) -> @span.ByteOffset raise ParseError {
  match attributes.internal {
    Some(_) => parse_error(DuplicateAttribute, sp(start, end))
    None => {
      attributes.internal = Some(sp(start, end))
      end
    }
  }
}
