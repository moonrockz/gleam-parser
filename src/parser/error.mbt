///|
/// Where an incorrect name was found (the compiler's
/// `IncorrectNamePosition`).
pub(all) enum IncorrectNamePosition {
  AsPattern
  Module
  Function
  Attribute
  Constant
  Target
  Variable
} derive(Eq, Debug)

///|
/// The compiler's `ParseErrorType`, one variant each, plus `TooMuchNesting`
/// (gleam-parser's own limit). `LexError` carries the scanner's diagnostic
/// for a lexical error met by a snippet parser.
pub(all) enum ParseErrorType {
  ExpectedEqual
  ExpectedExpr
  ExpectedName
  ExpectedPattern
  ExpectedType
  ExpectedUpName
  ExpectedValue
  ExpectedDefinition
  ExpectedDeprecationMessage
  ExpectedExternalArguments
  ExpectedFunctionDefinition
  ExpectedTargetName
  ExprLparStart
  ExtraSeparator
  IncorrectName(IncorrectNamePosition)
  IncorrectUpName
  InvalidBitArraySegment
  InvalidBitArrayUnit
  InvalidTailPattern
  InvalidTupleAccess
  LexError(@diagnostic.Diagnostic)
  NestedBitArrayPattern
  NoLetBinding
  NoValueAfterEqual
  NotConstType
  OpNakedRight
  OpaqueTypeAlias
  TooManyArgHoles
  DuplicateAttribute
  UnknownAttribute
  UnknownTarget
  ListSpreadWithoutElements
  ListSpreadFollowedByElements
  ListSpreadWithAnotherSpread(first_spread_location~ : @span.SrcSpan)
  UnexpectedLabel
  UnexpectedEof
  UnexpectedReservedWord
  UnexpectedToken(
    token~ : @scanner.TokenKind,
    expected~ : ArrayView[String],
    hint~ : String?
  )
  UnexpectedFunction
  ConcatPatternVariableLeftHandSide
  ConcatPatternVariableWithSuffix(name~ : String)
  ListSpreadWithoutTail
  ExpectedFunctionBody
  RedundantInternalAttribute
  InvalidModuleTypePattern
  ListPatternSpreadFollowedByElements
  ExpectedRecordConstructor(
    type_name~ : String,
    public~ : Bool,
    opaque_~ : Bool,
    fields~ : ArrayView[@ast.RecordConstructorArg]
  )
  CallInClauseGuard
  IfExpression
  TypeDefinitionNoArguments
  UnknownAttributeRecordVariant
  IncorrectImportModuleSeparator(module_~ : String, item~ : String)
  EmptyGuardBlock
  ConstantInsideFunction
  FunctionDefinitionAngleGenerics
  TypeUsageAngleGenerics(
    module_~ : String?,
    name~ : String,
    arguments~ : ArrayView[@ast.TypeAst]
  )
  TypeDefinitionAngleGenerics(name~ : String, arguments~ : ArrayView[String])
  MissingConstantAsMessage
  RecordUpdateAfterFields
  TooMuchNesting(budget~ : @fuel.Budget, spent~ : Array[@fuel.Spent])
} derive(Eq, Debug)

///|
/// A syntax error: the compiler's error and its span.
pub(all) suberror ParseError {
  ParseError(error~ : ParseErrorType, location~ : @span.SrcSpan)
} derive(Eq, Debug)

///|
/// The compiler's `ParseErrorDetails`: the body text, the primary label
/// text, the extra labels and the hint.
pub(all) struct ParseErrorDetails {
  text : String
  label_text : String
  extra_labels : ArrayView[@diagnostic.Label]
  hint : String?
} derive(Eq, Debug)

///|
/// The variant name (`UnexpectedToken`, …), as the oracle writes it.
pub fn ParseErrorType::kind(self : ParseErrorType) -> String {
  match self {
    ExpectedEqual => "ExpectedEqual"
    ExpectedExpr => "ExpectedExpr"
    ExpectedName => "ExpectedName"
    ExpectedPattern => "ExpectedPattern"
    ExpectedType => "ExpectedType"
    ExpectedUpName => "ExpectedUpName"
    ExpectedValue => "ExpectedValue"
    ExpectedDefinition => "ExpectedDefinition"
    ExpectedDeprecationMessage => "ExpectedDeprecationMessage"
    ExpectedExternalArguments => "ExpectedExternalArguments"
    ExpectedFunctionDefinition => "ExpectedFunctionDefinition"
    ExpectedTargetName => "ExpectedTargetName"
    ExprLparStart => "ExprLparStart"
    ExtraSeparator => "ExtraSeparator"
    IncorrectName(_) => "IncorrectName"
    IncorrectUpName => "IncorrectUpName"
    InvalidBitArraySegment => "InvalidBitArraySegment"
    InvalidBitArrayUnit => "InvalidBitArrayUnit"
    InvalidTailPattern => "InvalidTailPattern"
    InvalidTupleAccess => "InvalidTupleAccess"
    LexError(_) => "LexError"
    NestedBitArrayPattern => "NestedBitArrayPattern"
    NoLetBinding => "NoLetBinding"
    NoValueAfterEqual => "NoValueAfterEqual"
    NotConstType => "NotConstType"
    OpNakedRight => "OpNakedRight"
    OpaqueTypeAlias => "OpaqueTypeAlias"
    TooManyArgHoles => "TooManyArgHoles"
    DuplicateAttribute => "DuplicateAttribute"
    UnknownAttribute => "UnknownAttribute"
    UnknownTarget => "UnknownTarget"
    ListSpreadWithoutElements => "ListSpreadWithoutElements"
    ListSpreadFollowedByElements => "ListSpreadFollowedByElements"
    ListSpreadWithAnotherSpread(..) => "ListSpreadWithAnotherSpread"
    UnexpectedLabel => "UnexpectedLabel"
    UnexpectedEof => "UnexpectedEof"
    UnexpectedReservedWord => "UnexpectedReservedWord"
    UnexpectedToken(..) => "UnexpectedToken"
    UnexpectedFunction => "UnexpectedFunction"
    ConcatPatternVariableLeftHandSide => "ConcatPatternVariableLeftHandSide"
    ConcatPatternVariableWithSuffix(..) => "ConcatPatternVariableWithSuffix"
    ListSpreadWithoutTail => "ListSpreadWithoutTail"
    ExpectedFunctionBody => "ExpectedFunctionBody"
    RedundantInternalAttribute => "RedundantInternalAttribute"
    InvalidModuleTypePattern => "InvalidModuleTypePattern"
    ListPatternSpreadFollowedByElements => "ListPatternSpreadFollowedByElements"
    ExpectedRecordConstructor(..) => "ExpectedRecordConstructor"
    CallInClauseGuard => "CallInClauseGuard"
    IfExpression => "IfExpression"
    TypeDefinitionNoArguments => "TypeDefinitionNoArguments"
    UnknownAttributeRecordVariant => "UnknownAttributeRecordVariant"
    IncorrectImportModuleSeparator(..) => "IncorrectImportModuleSeparator"
    EmptyGuardBlock => "EmptyGuardBlock"
    ConstantInsideFunction => "ConstantInsideFunction"
    FunctionDefinitionAngleGenerics => "FunctionDefinitionAngleGenerics"
    TypeUsageAngleGenerics(..) => "TypeUsageAngleGenerics"
    TypeDefinitionAngleGenerics(..) => "TypeDefinitionAngleGenerics"
    MissingConstantAsMessage => "MissingConstantAsMessage"
    RecordUpdateAfterFields => "RecordUpdateAfterFields"
    TooMuchNesting(..) => "TooMuchNesting"
  }
}

///|
/// The compiler's `Display` for a token: its text in backquotes. A name,
/// number or string shows its own text.
pub fn token_text(kind : @scanner.TokenKind) -> String {
  let s = match kind {
    Name(n) | UpName(n) | DiscardName(n) => n
    Int(value~, ..) | Float(value~, ..) => value
    String(v) => v
    LeftParen => "("
    RightParen => ")"
    LeftSquare => "["
    RightSquare => "]"
    LeftBrace => "{"
    RightBrace => "}"
    Plus => "+"
    Minus => "-"
    Star => "*"
    Slash => "/"
    Less => "<"
    Greater => ">"
    LessEqual => "<="
    GreaterEqual => ">="
    Percent => "%"
    PlusDot => "+."
    MinusDot => "-."
    StarDot => "*."
    SlashDot => "/."
    LessDot => "<."
    GreaterDot => ">."
    LessEqualDot => "<=."
    GreaterEqualDot => ">=."
    Concatenate => "<>"
    Colon => ":"
    Comma => ","
    Hash => "#"
    Bang => "!"
    Equal => "="
    EqualEqual => "=="
    NotEqual => "!="
    Vbar => "|"
    VbarVbar => "||"
    AmperAmper => "&&"
    LtLt => "<<"
    GtGt => ">>"
    Pipe => "|>"
    Dot => "."
    RArrow => "->"
    LArrow => "<-"
    DotDot => ".."
    At => "@"
    Keyword(k) => k.text()
    Error => "?"
  }
  "`\{s}`"
}

///|
/// What the compiler says it found (`UnexpectedToken` text).
fn found_text(kind : @scanner.TokenKind) -> String {
  match kind {
    Int(..) => "an Int"
    Float(..) => "a Float"
    String(_) => "a String"
    DiscardName(_) => "a discard name"
    Name(_) | UpName(_) => "a name"
    Keyword(_) => "the keyword \{token_text(kind)}"
    _ => token_text(kind)
  }
}

///|
/// The source form of a type annotation (`TypeAst::print`), for messages.
pub fn type_ast_text(t : @ast.TypeAst) -> String {
  let sb = StringBuilder()
  write_type_ast(sb, t)
  sb.to_string()
}

///|
fn write_type_ast(sb : StringBuilder, t : @ast.TypeAst) -> Unit {
  fn list(xs : ArrayView[@ast.TypeAst]) {
    for i, x in xs {
      if i > 0 {
        sb.write_string(", ")
      }
      write_type_ast(sb, x)
    }
  }

  match t {
    Var(v) => sb.write_string(v.name)
    Hole(h) => sb.write_string(h.name)
    Tuple(tuple) => {
      sb.write_string("#(")
      list(tuple.elements)
      sb.write_string(")")
    }
    Fn(f) => {
      sb.write_string("fn(")
      list(f.arguments)
      sb.write_string(") -> ")
      write_type_ast(sb, f.return_)
    }
    Constructor(c) => {
      match c.name {
        Unqualified(name~, ..) => sb.write_string(name)
        Qualified(module_~, name~, ..) => {
          sb.write_string(module_)
          sb.write_string(".")
          if name is Some(n) {
            sb.write_string(n.name)
          }
        }
      }
      if c.arguments.length() > 0 {
        sb.write_string("(")
        list(c.arguments)
        sb.write_string(")")
      }
    }
  }
}

///|
fn details(
  text : String,
  label_text : String,
  hint? : String,
  extra_labels~ : Array[@diagnostic.Label] = [],
) -> ParseErrorDetails {
  { text, label_text, extra_labels: extra_labels[:], hint, }
}

///|
/// The compiler's `ParseErrorType::details()`: body text, primary label,
/// extra labels and hint, with its exact wording and `wrap` at 75 bytes.
pub fn ParseErrorType::details(self : ParseErrorType) -> ParseErrorDetails {
  match self {
    ExpectedEqual => details("", "I was expecting a '=' after this")
    ExpectedExpr => details("", "I was expecting an expression after this")
    ExpectedName => details("", "I was expecting a name here")
    ExpectedPattern => details("", "I was expecting a pattern after this")
    ExpectedType =>
      details(
        "See: https://tour.gleam.run/basics/assignments/", "I was expecting a type after this",
      )
    ExpectedUpName => details("", "I was expecting a type name here")
    ExpectedValue => details("", "I was expecting a value after this")
    ExpectedDefinition => details("", "I was expecting a definition after this")
    ExpectedDeprecationMessage =>
      details(
        "See: https://tour.gleam.run/functions/deprecations/", "A deprecation attribute must have a string message.",
      )
    ExpectedExternalArguments =>
      details(
        "",
        "This attribute is incomplete",
        hint="See https://tour.gleam.run/advanced-features/externals/",
      )
    ExpectedFunctionDefinition =>
      details("", "I was expecting a function definition after this")
    ExpectedTargetName =>
      details(
        "Try `erlang`, `javascript`.", "I was expecting a target name after this",
      )
    ExtraSeparator =>
      details("", "This is an extra delimiter", hint="Try removing it?")
    ExprLparStart =>
      details(
        "",
        "This parenthesis cannot be understood here",
        hint="To group expressions in Gleam, use \"{\" and \"}\"; tuples are created with `#(` and `)`.",
      )
    IncorrectName(kind) => {
      let subject = match kind {
        AsPattern => "A name after `as`"
        Module => "A module name"
        Function => "A function name"
        Attribute => "An attribute name"
        Constant => "A constant name"
        Target => "A target name"
        Variable => "A variable name"
      }
      details(
        @scanner.wrap(
          "\{subject} must start with a lowercase letter, and can contain a-z, 0-9, or _.",
        ),
        "I'm expecting a lowercase name here",
      )
    }
    IncorrectUpName =>
      details(
        "",
        "I'm expecting a type name here",
        hint=@scanner.wrap(
          "Type names start with a uppercase letter, and can contain a-z, A-Z, or 0-9.",
        ),
      )
    InvalidBitArraySegment =>
      details(
        "See: https://tour.gleam.run/data-types/bit-arrays/",
        "This is not a valid BitArray segment option",
        hint="Valid BitArray segment options are:\n" +
          @scanner.wrap(
            "bits, bytes, int, float, utf8, utf16, utf32, utf8_codepoint, utf16_codepoint, utf32_codepoint, signed, unsigned, big, little, native, size, unit.",
          ),
      )
    InvalidBitArrayUnit =>
      details(
        "See: https://tour.gleam.run/data-types/bit-arrays/",
        "This is not a valid BitArray unit value",
        hint="Unit must be an integer literal >= 1 and <= 256.",
      )
    InvalidTailPattern =>
      details("", "This part of a list pattern can only be a name or a discard")
    InvalidTupleAccess =>
      details(
        "",
        "This integer is not valid for tuple access",
        hint="Only non negative integer literals like 0, or 1_000 can be used.",
      )
    LexError(d) => details(d.text, d.message)
    NestedBitArrayPattern => details("", "BitArray patterns cannot be nested")
    NotConstType =>
      details(
        "See: https://tour.gleam.run/basics/constants/", "This type is not allowed in module constants",
      )
    NoLetBinding =>
      details(
        "See: https://tour.gleam.run/basics/assignments/",
        "There must be a 'let' to bind variable to value",
        hint="Use let for binding.",
      )
    NoValueAfterEqual =>
      details("", "I was expecting to see a value after this equals sign")
    OpaqueTypeAlias =>
      details(
        "See: https://tour.gleam.run/basics/type-aliases/", "Type Aliases cannot be opaque",
      )
    OpNakedRight =>
      details(
        "",
        "This operator has no value on its right side",
        hint="Remove it or put a value after it.",
      )
    TooManyArgHoles =>
      details(
        "See: https://tour.gleam.run/functions/functions/",
        "There is more than 1 argument hole in this function call",
        hint="Function calls can have at most one argument hole.",
      )
    UnexpectedEof => details("", "The module ended unexpectedly")
    ListSpreadWithoutElements =>
      details(
        "See: https://tour.gleam.run/basics/lists/",
        "This spread does nothing",
        hint="Try prepending some elements [1, 2, ..list].",
      )
    ListSpreadWithAnotherSpread(first_spread_location~) =>
      details(
        [
          "Lists are immutable and singly-linked, so to join two or more lists",
          "all the elements of the lists would need to be copied into a new list.",
          "This would be slow, so there is no built-in syntax for it.",
        ].join("\n"),
        "I wasn't expecting a second list here",
        extra_labels=[
          { span: first_spread_location, text: "You're using a list here", },
        ],
      )
    ListSpreadFollowedByElements =>
      details(
        [
          "Lists are immutable and singly-linked, so to append items to them", "all the elements of a list would need to be copied into a new list.",
          "This would be slow, so there is no built-in syntax for it.",
        ].join("\n"),
        "I wasn't expecting elements after this",
        hint="Prepend items to the list and then reverse it once you are done.",
      )
    ListPatternSpreadFollowedByElements =>
      details(
        [
          "Lists are immutable and singly-linked, so to match on the end", "of a list would require the whole list to be traversed. This",
          "would be slow, so there is no built-in syntax for it. Pattern", "match on the start of the list instead.",
        ].join("\n"),
        "I wasn't expecting elements after this",
      )
    UnexpectedReservedWord =>
      details(
        "",
        "This is a reserved word",
        hint="I was expecting to see a name here.",
      )
    UnexpectedLabel =>
      details(
        "Please remove the argument label.", "Argument labels are not allowed for anonymous functions",
      )
    UnexpectedToken(token~, expected~, hint~) => {
      let lines = ["Found \{found_text(token)}, expected one of: "]
      for s in expected {
        lines.push("- \{s}")
      }
      details(lines.join("\n"), "I was not expecting this", hint?)
    }
    ConcatPatternVariableLeftHandSide =>
      details(
        [
          "We can't tell what size this prefix should be so we don't know", "how to handle this pattern.",
          "", "If you want to match one character consider using `pop_grapheme`",
          "from the stdlib's `gleam/string` module.",
        ].join("\n"),
        "This must be a string literal",
      )
    ConcatPatternVariableWithSuffix(name~) =>
      details(
        [
          "A string pattern can only match on a literal string prefix.",
          "",
          @scanner.wrap(
            "Matching on a literal suffix is not possible, because `\{name}` would have an unknown size.",
          ),
        ].join("\n"),
        "This pattern is not allowed",
      )
    UnexpectedFunction =>
      details("", "Functions can only be called within other functions")
    ListSpreadWithoutTail =>
      details(
        "If a list expression has a spread then a tail must also be given.", "I was expecting a value after this spread",
      )
    UnknownAttribute =>
      details(
        "",
        "I don't recognise this attribute",
        hint="Try `deprecated`, `external` or `internal` instead.",
      )
    DuplicateAttribute =>
      details("This attribute has already been given.", "Duplicate attribute")
    UnknownTarget =>
      details("Try `erlang`, `javascript`.", "I don't recognise this target")
    ExpectedFunctionBody => details("", "This function does not have a body")
    RedundantInternalAttribute =>
      details(
        "Only a public definition can be annotated as internal.",
        "Redundant internal attribute",
        hint="Remove the `@internal` annotation.",
      )
    InvalidModuleTypePattern =>
      details(
        [
          "I'm expecting a pattern here,", "or a variable to bind a value to, etc.",
        ].join("\n"),
        "Invalid pattern",
        hint="A pattern can be a constructor name, a literal value\nSee: https://tour.gleam.run/flow-control/case-expressions/",
      )
    ExpectedRecordConstructor(type_name~, public~, opaque_~, fields~) => {
      let accessor = if public { "pub " } else { "" }
      let opaque_text = if public && opaque_ { "opaque " } else { "" }
      let field_lines = fields.map(field => {
        match field.label {
          Some(label) => "    \{label.name}: \{type_ast_text(field.ast)},"
          None => "    \{type_ast_text(field.ast)},"
        }
      })
      details(
        "Each custom type variant must have a constructor:\n\n\{accessor}\{opaque_text}type \{type_name} {\n  \{type_name}(\n\{field_lines.join("\n")}\n  )\n}",
        "I was not expecting this",
      )
    }
    CallInClauseGuard =>
      details(
        "Functions cannot be called in clause guards.", "Unsupported expression",
      )
    IfExpression =>
      details(
        [
          "If you want to write a conditional expression you can use a `case`:",
          "", "    case condition {", "      True -> todo", "      False -> todo",
          "    }", "", "See: https://tour.gleam.run/flow-control/case-expressions/",
        ].join("\n"),
        "Gleam doesn't have if expressions",
      )
    TypeDefinitionNoArguments =>
      details(
        "A generic type must have at least a generic parameter.",
        "I was expecting generic parameters here",
        hint="If a type is not generic you should omit the `()`.",
      )
    UnknownAttributeRecordVariant =>
      details(
        "",
        "This attribute cannot be used on a variant.",
        hint="Did you mean `@deprecated`?",
      )
    IncorrectImportModuleSeparator(module_~, item~) =>
      details(
        [
          "Perhaps you meant one of:",
          "",
          "    import \{module_}/\{item}",
          "    import \{module_}.{item}",
        ].join("\n"),
        "I was expecting either `/` or `.{` here.",
      )
    EmptyGuardBlock => details("", "A clause guard block cannot be empty")
    MissingConstantAsMessage =>
      details(
        "", "I was expecting to see a constant expression after this `as`",
      )
    ConstantInsideFunction =>
      details(
        @scanner.wrap(
          "All variables are immutable in Gleam, so constants inside functions are not necessary.",
        ),
        "Constants are not allowed inside functions",
        hint="Either move this into the global scope or use `let` binding instead.",
      )
    FunctionDefinitionAngleGenerics =>
      details(
        [
          "Generic function type variables do not need to be predeclared like they",
          "would be in some other languages, instead they are written with lowercase",
          "names.", "", "    fn example(argument: generic) -> generic", "", "See: https://tour.gleam.run/functions/generic-functions/",
        ].join("\n"),
        "I was expecting `(` here.",
      )
    TypeUsageAngleGenerics(module_~, name~, arguments~) => {
      let type_arguments = arguments.map(type_ast_text).join(", ")
      let replacement = match module_ {
        Some(m) => "\{m}.\{name}(\{type_arguments})"
        None => "\{name}(\{type_arguments})"
      }
      details(
        [
          "Type parameters use lowercase names and are surrounded by parentheses.",
          "",
          "    \{replacement}",
          "",
          "See: https://tour.gleam.run/data-types/generic-custom-types/",
        ].join("\n"),
        "I was expecting `(` here.",
      )
    }
    TypeDefinitionAngleGenerics(name~, arguments~) =>
      details(
        [
          "Type parameters use lowercase names and are surrounded by parentheses.",
          "",
          "    type \{name}(\{arguments.join(", ")}) {",
          "",
          "See: https://tour.gleam.run/data-types/generic-custom-types/",
        ].join("\n"),
        "I was expecting `(` here.",
      )
    RecordUpdateAfterFields =>
      details(
        [
          "When updating a record, the previous record comes before the fields to change",
          "", "    let record = Record(field1:, field2:)", "    let updated_record = Record(..record, field1: \"new_value\")",
          "", "See: https://tour.gleam.run/data-types/record-updates/",
        ].join("\n"),
        "I wasn't expecting a record update here",
      )
    TooMuchNesting(budget~, spent~) => {
      let stack = spent
        .map(s => "\{s.operation.name()} ×\{s.levels}")
        .join(", ")
      details(
        "The fuel budget of \{budget.units()} ran out while nesting \{stack}. gleam-parser spends one unit of fuel per nested level of syntax; the Gleam compiler has no such limit.",
        "Recursion limit exceeded",
        hint="Split the code into smaller functions or constants, or give the parser a Config with more fuel on a target with a large stack (native, js).",
      )
    }
  }
}

///|
/// The diagnostic for a parse error: `GL-PARSE-001` with the compiler's
/// title "Syntax error" and wording; `GL-PARSE-004` for `TooMuchNesting`;
/// the scanner's own diagnostic for `LexError`. `UnexpectedEof` keeps the
/// compiler's raw span `0..0`; the renderer moves it to the last byte as
/// `error.rs` does.
pub fn ParseError::to_diagnostic(self : ParseError) -> @diagnostic.Diagnostic {
  let ParseError(error~, location~) = self
  match error {
    LexError(d) => d
    _ => {
      let details = error.details()
      @diagnostic.Diagnostic(
        code=if error is TooMuchNesting(..) {
          "GL-PARSE-004"
        } else {
          "GL-PARSE-001"
        },
        kind=error.kind(),
        severity=Error,
        title="Syntax error",
        message=details.label_text,
        span=location,
        labels=details.extra_labels.to_owned(),
        text=details.text,
        hint=details.hint,
      )
    }
  }
}

///|
/// The diagnostic for a parser warning, with the compiler's title, text and
/// label (`warning.rs`): `GL-PARSE-002` for deprecated syntax,
/// `GL-PARSE-003` for a detached doc comment.
pub fn warning_diagnostic(w : @ast.Warning) -> @diagnostic.Diagnostic {
  fn deprecated(
    kind : String,
    location : @span.SrcSpan,
    title : String,
    text : String,
    label : String,
  ) -> @diagnostic.Diagnostic {
    @diagnostic.Diagnostic(
      code="GL-PARSE-002",
      kind~,
      severity=Warning,
      title~,
      message=label,
      span=location,
      text=@scanner.wrap(text),
    )
  }

  match w {
    DeprecatedListPrepend(location~) =>
      deprecated(
        "DeprecatedListPrepend", location, "Deprecated prepend syntax", "This syntax for prepending to a list is deprecated.\nWhen prepending an item to a list it should be preceded by a comma, like this: `[item, ..list]`.",
        "This spread should be preceded by a comma",
      )
    DeprecatedListPattern(location~) =>
      deprecated(
        "DeprecatedListPattern", location, "Deprecated list pattern matching syntax",
        "This syntax for pattern matching on a list is deprecated.\nWhen matching on the rest of a list it should always be preceded by a comma, like this: `[item, ..list]`.",
        "This spread should be preceded by a comma",
      )
    DeprecatedRecordSpreadPattern(location~) =>
      deprecated(
        "DeprecatedRecordSpreadPattern", location, "Deprecated record pattern matching syntax",
        "This syntax for pattern matching on a record is deprecated.", "This should be preceded by a comma",
      )
    DeprecatedListCatchAllPattern(location~) =>
      deprecated(
        "DeprecatedListCatchAllPattern", location, "Deprecated list pattern matching syntax",
        "This syntax for pattern matching on lists is deprecated.\nTo match on all possible lists, use the `_` catch-all pattern instead.",
        "Replace this with `_`",
      )
    DeprecatedListSpreadAsVariablePattern(location~, name~) =>
      deprecated(
        "DeprecatedListSpreadAsVariablePattern",
        location,
        "Deprecated list pattern matching syntax",
        "This syntax for pattern matching on lists is deprecated.\nThis spread matches the entire list, so the variable \{name} can be used as the pattern directly instead.",
        "Replace this with `\{name}`",
      )
    DeprecatedEmptyClauseGuard(location~) =>
      deprecated(
        "DeprecatedEmptyClauseGuard", location, "Deprecated empty guard syntax",
        "This syntax for an empty guard is deprecated. To have a clause without a guard, remove this.",
        "This can be removed.",
      )
    DeprecatedTargetShorthand(target~, location~) => {
      let full_name = target.name()
      deprecated(
        "DeprecatedTargetShorthand",
        location,
        "Deprecated target shorthand syntax",
        "This shorthand target name is deprecated. Use the full name: `\{full_name}` instead.",
        "This should be replaced with `\{full_name}`",
      )
    }
    DetachedDocComment(location~) =>
      @diagnostic.Diagnostic(
        code="GL-PARSE-003",
        kind="DetachedDocComment",
        severity=Warning,
        title="Detached doc comment",
        message="This is not attached to a definition",
        span=location,
        text=@scanner.wrap(
          "This doc comment is followed by a regular comment so it is not attached to any definition.",
        ),
        hint=Some("Move the comment above the doc comment"),
      )
  }
}
