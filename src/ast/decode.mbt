// Decoders for the canonical JSON of docs/ast-json.md. Every decoder takes
// the JSON path of its input, so an error names the exact location
// (`$.module.definitions[3].definition.body[0].value`).

///|
/// Raised on malformed input. `path` is a JSONPath-like location (`$` is
/// the value given to the public decoder).
pub(all) suberror DecodeError {
  DecodeError(path~ : String, message~ : String)
} derive(Eq, Debug)

///|
/// The deepest JSON nesting the decoder reads: deeper input raises a
/// `DecodeError` instead of overflowing the stack (wasm has a small one).
/// Each AST level is at least one JSON level, so this bounds the AST depth
/// a decoded module can have; the parser keeps generated ASTs within it.
pub let max_depth : Int32 = 150

///|
priv enum Path {
  Root
  Key(Path, String)
  Index(Path, Int32)
}

///|
/// The number of steps from the root.
fn Path::depth(self : Path) -> Int32 {
  let mut n = 0
  let mut p = self
  while true {
    match p {
      Root => break
      Key(parent, _) | Index(parent, _) => {
        n += 1
        p = parent
      }
    }
  }
  n
}

///|
fn check_depth(path : Path) -> Unit raise DecodeError {
  if path.depth() > max_depth {
    fail(path, "nesting deeper than \{max_depth} levels")
  }
}

///|
fn Path::render(self : Path) -> String {
  let sb = StringBuilder()
  self.write_to(sb)
  sb.to_string()
}

///|
fn Path::write_to(self : Path, sb : StringBuilder) -> Unit {
  match self {
    Root => sb.write_string("$")
    Key(parent, key) => {
      parent.write_to(sb)
      sb.write_string(".")
      sb.write_string(key)
    }
    Index(parent, i) => {
      parent.write_to(sb)
      sb.write_string("[")
      sb.write_string(i.to_string())
      sb.write_string("]")
    }
  }
}

///|
fn[T] fail(path : Path, message : String) -> T raise DecodeError {
  raise DecodeError(path=path.render(), message~)
}

///|
fn json_kind(j : Json) -> String {
  match j {
    Null => "null"
    True | False => "a BOOL"
    Number(_, ..) => "a NUMBER"
    String(_) => "a STRING"
    Array(_) => "an ARRAY"
    Object(_) => "an OBJECT"
  }
}

///|
fn dec_object(j : Json, path : Path) -> Map[String, Json] raise DecodeError {
  match j {
    Object(m) => m
    other => fail(path, "expected an OBJECT, found \{json_kind(other)}")
  }
}

///|
/// The dec_field `key`; it must be present.
fn[T] dec_field(
  j : Json,
  path : Path,
  key : String,
  f : (Json, Path) -> T raise DecodeError,
) -> T raise DecodeError {
  let m = dec_object(j, path)
  match m.get(key) {
    Some(v) => {
      let child = Key(path, key)
      check_depth(child)
      f(v, child)
    }
    None => fail(Key(path, key), "missing field")
  }
}

///|
fn dec_string(j : Json, path : Path) -> String raise DecodeError {
  match j {
    String(s) => s
    other => fail(path, "expected a STRING, found \{json_kind(other)}")
  }
}

///|
fn dec_int(j : Json, path : Path) -> Int32 raise DecodeError {
  match j {
    Number(d, ..) => {
      let i = d.to_int()
      if i.to_double() != d {
        fail(path, "expected an integer, found \{d}")
      }
      i
    }
    other => fail(path, "expected a number, found \{json_kind(other)}")
  }
}

///|
/// A `u64` of the compiler: exact digits from `repr` when the number is
/// too big for a `Double`, else the `Double` itself.
fn dec_uint64(j : Json, path : Path) -> UInt64 raise DecodeError {
  match j {
    Number(d, repr~) =>
      match repr {
        Some(digits) =>
          @string.parse_uint64(digits) catch {
            _ =>
              fail(path, "expected an unsigned 64-bit integer, found \{digits}")
          }
        None => {
          if d < 0.0 || d != d.floor() || d >= 18446744073709551616.0 {
            fail(path, "expected an unsigned 64-bit integer, found \{d}")
          }
          d.to_uint64()
        }
      }
    other => fail(path, "expected a number, found \{json_kind(other)}")
  }
}

///|
fn dec_bool(j : Json, path : Path) -> Bool raise DecodeError {
  match j {
    True => true
    False => false
    other => fail(path, "expected a BOOL, found \{json_kind(other)}")
  }
}

///|
fn[T] dec_nullable(
  j : Json,
  path : Path,
  f : (Json, Path) -> T raise DecodeError,
) -> T? raise DecodeError {
  match j {
    Null => None
    other => Some(f(other, path))
  }
}

///|
fn[T] dec_array(
  j : Json,
  path : Path,
  f : (Json, Path) -> T raise DecodeError,
) -> ArrayView[T] raise DecodeError {
  match j {
    Array(items) => {
      let out : Array[T] = []
      for i, item in items {
        let child = Index(path, i)
        check_depth(child)
        out.push(f(item, child))
      }
      out[:]
    }
    other => fail(path, "expected an ARRAY, found \{json_kind(other)}")
  }
}

///|
fn dec_kind_of(j : Json, path : Path) -> String raise DecodeError {
  dec_field(j, path, "kind", dec_string)
}

///|
fn dec_big_int(j : Json, path : Path) -> BigInt raise DecodeError {
  let s = dec_string(j, path)
  let digits = if s.has_prefix("-") { s[1:] } else { s[:] }
  if digits.length() == 0 {
    fail(path, "not a decimal integer")
  }
  for i = 0; i < digits.length(); i = i + 1 {
    let c = digits.code_unit_at(i).to_int()
    if c < '0'.to_int() || c > '9'.to_int() {
      fail(path, "not a decimal integer")
    }
  }
  BigInt::from_string(s)
}

///|
fn dec_span(j : Json, path : Path) -> @span.SrcSpan raise DecodeError {
  @span.SrcSpan::new(
    dec_field(j, path, "start", dec_int),
    dec_field(j, path, "end", dec_int),
  )
}

///|
fn dec_spanned_string(j : Json, path : Path) -> SpannedString raise DecodeError {
  {
    location: dec_field(j, path, "location", dec_span),
    name: dec_field(j, path, "name", dec_string),
  }
}

///|
fn dec_documentation(j : Json, path : Path) -> Documentation raise DecodeError {
  {
    start: dec_field(j, path, "start", dec_int),
    text: dec_field(j, path, "text", dec_string),
  }
}

///|
fn dec_external(j : Json, path : Path) -> External raise DecodeError {
  {
    module_: dec_field(j, path, "module", dec_string),
    function: dec_field(j, path, "function", dec_string),
    location: dec_field(j, path, "location", dec_span),
  }
}

///|
fn dec_publicity(j : Json, path : Path) -> Publicity raise DecodeError {
  match dec_kind_of(j, path) {
    "public" => Public
    "private" => Private
    "internal" =>
      Internal(
        attribute_location=dec_field(j, path, "attribute_location", (v, p) => {
          dec_nullable(v, p, dec_span)
        }),
      )
    other => fail(Key(path, "kind"), "unknown publicity \"\{other}\"")
  }
}

///|
fn dec_deprecation(j : Json, path : Path) -> Deprecation raise DecodeError {
  match dec_kind_of(j, path) {
    "not_deprecated" => NotDeprecated
    "deprecated" =>
      Deprecated(message=dec_field(j, path, "message", dec_string))
    other => fail(Key(path, "kind"), "unknown deprecation \"\{other}\"")
  }
}

///|
fn dec_assign_name(j : Json, path : Path) -> AssignName raise DecodeError {
  match dec_kind_of(j, path) {
    "variable" => Variable(dec_field(j, path, "name", dec_string))
    "discard" => Discard(dec_field(j, path, "name", dec_string))
    other => fail(Key(path, "kind"), "unknown assign name \"\{other}\"")
  }
}

///|
fn dec_target(j : Json, path : Path) -> Target raise DecodeError {
  let s = dec_string(j, path)
  match Target::of(s) {
    Some(t) => t
    None => fail(path, "unknown target \"\{s}\"")
  }
}

///|
fn dec_bin_op(j : Json, path : Path) -> BinOp raise DecodeError {
  let s = dec_string(j, path)
  match BinOp::of(s) {
    Some(op) => op
    None => fail(path, "unknown operator \"\{s}\"")
  }
}

///|
fn dec_int_operator(j : Json, path : Path) -> IntOperator raise DecodeError {
  let s = dec_string(j, path)
  match IntOperator::of(s) {
    Some(op) => op
    None => fail(path, "unknown int operator \"\{s}\"")
  }
}

///|
fn dec_implicit(
  j : Json,
  path : Path,
) -> ImplicitCallArgOrigin raise DecodeError {
  let s = dec_string(j, path)
  match ImplicitCallArgOrigin::of(s) {
    Some(i) => i
    None => fail(path, "unknown implicit call arg origin \"\{s}\"")
  }
}

///|
/// A `Float` node's double, derived from its lexeme.
fn dec_float_value(value : String, path : Path) -> Double raise DecodeError {
  match @scanner.parse_float_value(value) {
    Some(d) => d
    None => fail(Key(path, "value"), "not a float literal")
  }
}

///|
pub fn decode_parsed(json : Json) -> Parsed raise DecodeError {
  dec_parsed(json, Root)
}

///|
fn dec_parsed(j : Json, path : Path) -> Parsed raise DecodeError {
  {
    module_: dec_field(j, path, "module", dec_module),
    extra: dec_field(j, path, "extra", dec_extra),
    warnings: dec_field(j, path, "warnings", (v, p) => {
      dec_array(v, p, dec_warning)
    }),
  }
}

///|
pub fn decode_module(json : Json) -> Module raise DecodeError {
  dec_module(json, Root)
}

///|
fn dec_module(j : Json, path : Path) -> Module raise DecodeError {
  {
    definitions: dec_field(j, path, "definitions", (v, p) => {
      dec_array(v, p, dec_targeted_definition)
    }),
  }
}

///|
fn dec_targeted_definition(
  j : Json,
  path : Path,
) -> TargetedDefinition raise DecodeError {
  {
    definition: dec_field(j, path, "definition", dec_definition),
    target: dec_field(j, path, "target", (v, p) => {
      dec_nullable(v, p, dec_target)
    }),
  }
}

///|
pub fn decode_definition(json : Json) -> Definition raise DecodeError {
  dec_definition(json, Root)
}

///|
fn dec_definition(j : Json, path : Path) -> Definition raise DecodeError {
  match dec_kind_of(j, path) {
    "function" => Function(dec_function(j, path))
    "type_alias" =>
      TypeAlias({
        location: dec_field(j, path, "location", dec_span),
        alias_: dec_field(j, path, "alias", dec_string),
        name_location: dec_field(j, path, "name_location", dec_span),
        parameters: dec_field(j, path, "parameters", (v, p) => {
          dec_array(v, p, dec_spanned_string)
        }),
        type_ast: dec_field(j, path, "type_ast", dec_type_ast),
        publicity: dec_field(j, path, "publicity", dec_publicity),
        documentation: dec_field(j, path, "documentation", (v, p) => {
          dec_nullable(v, p, dec_documentation)
        }),
        deprecation: dec_field(j, path, "deprecation", dec_deprecation),
      })
    "custom_type" =>
      CustomType({
        location: dec_field(j, path, "location", dec_span),
        end_position: dec_field(j, path, "end_position", dec_int),
        name: dec_field(j, path, "name", dec_string),
        name_location: dec_field(j, path, "name_location", dec_span),
        publicity: dec_field(j, path, "publicity", dec_publicity),
        constructors: dec_field(j, path, "constructors", (v, p) => {
          dec_array(v, p, dec_record_constructor)
        }),
        documentation: dec_field(j, path, "documentation", (v, p) => {
          dec_nullable(v, p, dec_documentation)
        }),
        deprecation: dec_field(j, path, "deprecation", dec_deprecation),
        opaque_: dec_field(j, path, "opaque", dec_bool),
        parameters: dec_field(j, path, "parameters", (v, p) => {
          dec_array(v, p, dec_spanned_string)
        }),
        external_erlang: dec_field(j, path, "external_erlang", (v, p) => {
          dec_nullable(v, p, dec_external)
        }),
        external_javascript: dec_field(j, path, "external_javascript", (v, p) => {
          dec_nullable(v, p, dec_external)
        }),
      })
    "import" =>
      Import({
        documentation: dec_field(j, path, "documentation", (v, p) => {
          dec_nullable(v, p, dec_string)
        }),
        location: dec_field(j, path, "location", dec_span),
        module_location: dec_field(j, path, "module_location", dec_span),
        module_: dec_field(j, path, "module", dec_string),
        as_name: dec_field(j, path, "as_name", (v, p) => {
          dec_nullable(v, p, (v2, p2) => {
            name: dec_field(v2, p2, "name", dec_assign_name),
            location: dec_field(v2, p2, "location", dec_span),
          })
        }),
        unqualified_values: dec_field(j, path, "unqualified_values", (v, p) => {
          dec_array(v, p, dec_unqualified_import)
        }),
        unqualified_types: dec_field(j, path, "unqualified_types", (v, p) => {
          dec_array(v, p, dec_unqualified_import)
        }),
      })
    "module_constant" =>
      ModuleConstant({
        documentation: dec_field(j, path, "documentation", (v, p) => {
          dec_nullable(v, p, dec_documentation)
        }),
        location: dec_field(j, path, "location", dec_span),
        publicity: dec_field(j, path, "publicity", dec_publicity),
        name: dec_field(j, path, "name", dec_string),
        name_location: dec_field(j, path, "name_location", dec_span),
        annotation: dec_field(j, path, "annotation", (v, p) => {
          dec_nullable(v, p, dec_type_ast)
        }),
        value: dec_field(j, path, "value", dec_constant),
        deprecation: dec_field(j, path, "deprecation", dec_deprecation),
      })
    other => fail(Key(path, "kind"), "unknown definition kind \"\{other}\"")
  }
}

///|
fn dec_function(j : Json, path : Path) -> Function raise DecodeError {
  {
    location: dec_field(j, path, "location", dec_span),
    body_start: dec_field(j, path, "body_start", (v, p) => {
      dec_nullable(v, p, dec_int)
    }),
    end_position: dec_field(j, path, "end_position", dec_int),
    name: dec_field(j, path, "name", (v, p) => {
      dec_nullable(v, p, dec_spanned_string)
    }),
    arguments: dec_field(j, path, "arguments", (v, p) => {
      dec_array(v, p, dec_arg)
    }),
    body: dec_field(j, path, "body", (v, p) => dec_array(v, p, dec_statement)),
    publicity: dec_field(j, path, "publicity", dec_publicity),
    deprecation: dec_field(j, path, "deprecation", dec_deprecation),
    return_annotation: dec_field(j, path, "return_annotation", (v, p) => {
      dec_nullable(v, p, dec_type_ast)
    }),
    documentation: dec_field(j, path, "documentation", (v, p) => {
      dec_nullable(v, p, dec_documentation)
    }),
    external_erlang: dec_field(j, path, "external_erlang", (v, p) => {
      dec_nullable(v, p, dec_external)
    }),
    external_javascript: dec_field(j, path, "external_javascript", (v, p) => {
      dec_nullable(v, p, dec_external)
    }),
  }
}

///|
fn dec_unqualified_import(
  j : Json,
  path : Path,
) -> UnqualifiedImport raise DecodeError {
  {
    location: dec_field(j, path, "location", dec_span),
    name: dec_field(j, path, "name", dec_string),
    name_position: dec_field(j, path, "name_position", dec_int),
    as_name: dec_field(j, path, "as_name", (v, p) => {
      dec_nullable(v, p, dec_string)
    }),
  }
}

///|
fn dec_record_constructor(
  j : Json,
  path : Path,
) -> RecordConstructor raise DecodeError {
  {
    location: dec_field(j, path, "location", dec_span),
    name_location: dec_field(j, path, "name_location", dec_span),
    name: dec_field(j, path, "name", dec_string),
    arguments: dec_field(j, path, "arguments", (v, p) => {
      dec_array(v, p, dec_record_constructor_arg)
    }),
    documentation: dec_field(j, path, "documentation", (v, p) => {
      dec_nullable(v, p, dec_documentation)
    }),
    deprecation: dec_field(j, path, "deprecation", dec_deprecation),
  }
}

///|
fn dec_record_constructor_arg(
  j : Json,
  path : Path,
) -> RecordConstructorArg raise DecodeError {
  {
    label: dec_field(j, path, "label", (v, p) => {
      dec_nullable(v, p, dec_spanned_string)
    }),
    ast: dec_field(j, path, "ast", dec_type_ast),
    location: dec_field(j, path, "location", dec_span),
    doc: dec_field(j, path, "doc", (v, p) => {
      dec_nullable(v, p, dec_documentation)
    }),
  }
}

///|
fn dec_arg(j : Json, path : Path) -> Arg raise DecodeError {
  {
    names: dec_field(j, path, "names", dec_arg_names),
    location: dec_field(j, path, "location", dec_span),
    annotation: dec_field(j, path, "annotation", (v, p) => {
      dec_nullable(v, p, dec_type_ast)
    }),
  }
}

///|
fn dec_arg_names(j : Json, path : Path) -> ArgNames raise DecodeError {
  match dec_kind_of(j, path) {
    "discard" =>
      Discard(
        name=dec_field(j, path, "name", dec_string),
        location=dec_field(j, path, "location", dec_span),
      )
    "labelled_discard" =>
      LabelledDiscard(
        label=dec_field(j, path, "label", dec_string),
        label_location=dec_field(j, path, "label_location", dec_span),
        name=dec_field(j, path, "name", dec_string),
        name_location=dec_field(j, path, "name_location", dec_span),
      )
    "named" =>
      Named(
        name=dec_field(j, path, "name", dec_string),
        location=dec_field(j, path, "location", dec_span),
      )
    "named_labelled" =>
      NamedLabelled(
        label=dec_field(j, path, "label", dec_string),
        label_location=dec_field(j, path, "label_location", dec_span),
        name=dec_field(j, path, "name", dec_string),
        name_location=dec_field(j, path, "name_location", dec_span),
      )
    other => fail(Key(path, "kind"), "unknown arg names kind \"\{other}\"")
  }
}

///|
pub fn decode_type_ast(json : Json) -> TypeAst raise DecodeError {
  dec_type_ast(json, Root)
}

///|
fn dec_type_ast(j : Json, path : Path) -> TypeAst raise DecodeError {
  match dec_kind_of(j, path) {
    "constructor" =>
      Constructor({
        location: dec_field(j, path, "location", dec_span),
        name: dec_field(j, path, "name", dec_type_ast_constructor_name),
        arguments: dec_field(j, path, "arguments", (v, p) => {
          dec_array(v, p, dec_type_ast)
        }),
        start_parentheses: dec_field(j, path, "start_parentheses", (v, p) => {
          dec_nullable(v, p, dec_int)
        }),
      })
    "fn" =>
      Fn({
        location: dec_field(j, path, "location", dec_span),
        arguments: dec_field(j, path, "arguments", (v, p) => {
          dec_array(v, p, dec_type_ast)
        }),
        return_: dec_field(j, path, "return_", dec_type_ast),
      })
    "var" =>
      Var({
        location: dec_field(j, path, "location", dec_span),
        name: dec_field(j, path, "name", dec_string),
      })
    "tuple" =>
      Tuple({
        location: dec_field(j, path, "location", dec_span),
        elements: dec_field(j, path, "elements", (v, p) => {
          dec_array(v, p, dec_type_ast)
        }),
      })
    "hole" =>
      Hole({
        location: dec_field(j, path, "location", dec_span),
        name: dec_field(j, path, "name", dec_string),
      })
    other => fail(Key(path, "kind"), "unknown type kind \"\{other}\"")
  }
}

///|
fn dec_type_ast_constructor_name(
  j : Json,
  path : Path,
) -> TypeAstConstructorName raise DecodeError {
  match dec_kind_of(j, path) {
    "qualified" =>
      Qualified(
        module_=dec_field(j, path, "module", dec_string),
        module_location=dec_field(j, path, "module_location", dec_span),
        dot_location=dec_field(j, path, "dot_location", dec_int),
        name=dec_field(j, path, "name", (v, p) => {
          dec_nullable(v, p, dec_spanned_string)
        }),
      )
    "unqualified" =>
      Unqualified(
        name=dec_field(j, path, "name", dec_string),
        location=dec_field(j, path, "location", dec_span),
      )
    other =>
      fail(Key(path, "kind"), "unknown type constructor name kind \"\{other}\"")
  }
}

///|
pub fn decode_statement(json : Json) -> Statement raise DecodeError {
  dec_statement(json, Root)
}

///|
fn dec_statement(j : Json, path : Path) -> Statement raise DecodeError {
  match dec_kind_of(j, path) {
    "expression" => Expression(dec_field(j, path, "expression", dec_expr))
    "assignment" =>
      Assignment({
        location: dec_field(j, path, "location", dec_span),
        value: dec_field(j, path, "value", dec_expr),
        pattern: dec_field(j, path, "pattern", dec_pattern),
        kind: dec_field(j, path, "assignment_kind", dec_assignment_kind),
        annotation: dec_field(j, path, "annotation", (v, p) => {
          dec_nullable(v, p, dec_type_ast)
        }),
      })
    "use" =>
      Use({
        call: dec_field(j, path, "call", dec_expr),
        location: dec_field(j, path, "location", dec_span),
        right_hand_side_location: dec_field(
          j, path, "right_hand_side_location", dec_span,
        ),
        assignments_location: dec_field(
          j, path, "assignments_location", dec_span,
        ),
        assignments: dec_field(j, path, "assignments", (v, p) => {
          dec_array(v, p, dec_use_assignment)
        }),
      })
    "assert" =>
      Assert({
        location: dec_field(j, path, "location", dec_span),
        value: dec_field(j, path, "value", dec_expr),
        message: dec_field(j, path, "message", (v, p) => {
          dec_nullable(v, p, dec_expr)
        }),
      })
    other => fail(Key(path, "kind"), "unknown statement kind \"\{other}\"")
  }
}

///|
fn dec_assignment_kind(
  j : Json,
  path : Path,
) -> AssignmentKind raise DecodeError {
  match dec_kind_of(j, path) {
    "let" => Let
    "generated" => Generated
    "assert" =>
      Assert(
        location=dec_field(j, path, "location", dec_span),
        assert_keyword_start=dec_field(j, path, "assert_keyword_start", dec_int),
        message=dec_field(j, path, "message", (v, p) => {
          dec_nullable(v, p, dec_expr)
        }),
      )
    other => fail(Key(path, "kind"), "unknown assignment kind \"\{other}\"")
  }
}

///|
fn dec_use_assignment(j : Json, path : Path) -> UseAssignment raise DecodeError {
  {
    location: dec_field(j, path, "location", dec_span),
    pattern: dec_field(j, path, "pattern", dec_pattern),
    annotation: dec_field(j, path, "annotation", (v, p) => {
      dec_nullable(v, p, dec_type_ast)
    }),
  }
}

///|
fn[A] dec_call_arg(
  j : Json,
  path : Path,
  f : (Json, Path) -> A raise DecodeError,
) -> CallArg[A] raise DecodeError {
  {
    label: dec_field(j, path, "label", (v, p) => dec_nullable(v, p, dec_string)),
    location: dec_field(j, path, "location", dec_span),
    value: dec_field(j, path, "value", f),
    implicit: dec_field(j, path, "implicit", (v, p) => {
      dec_nullable(v, p, dec_implicit)
    }),
  }
}

///|
fn[A] dec_record_being_updated(
  j : Json,
  path : Path,
  f : (Json, Path) -> A raise DecodeError,
) -> RecordBeingUpdated[A] raise DecodeError {
  {
    base: dec_field(j, path, "base", f),
    location: dec_field(j, path, "location", dec_span),
  }
}

///|
fn[A] dec_record_update_arg(
  j : Json,
  path : Path,
  f : (Json, Path) -> A raise DecodeError,
) -> RecordUpdateArg[A] raise DecodeError {
  {
    label: dec_field(j, path, "label", dec_string),
    location: dec_field(j, path, "location", dec_span),
    value: dec_field(j, path, "value", f),
  }
}

///|
fn[V] dec_bit_array_segment(
  j : Json,
  path : Path,
  f : (Json, Path) -> V raise DecodeError,
) -> BitArraySegment[V] raise DecodeError {
  {
    location: dec_field(j, path, "location", dec_span),
    value: dec_field(j, path, "value", f),
    options: dec_field(j, path, "options", (v, p) => {
      dec_array(v, p, (v2, p2) => dec_bit_array_option(v2, p2, f))
    }),
  }
}

///|
fn[V] dec_bit_array_option(
  j : Json,
  path : Path,
  f : (Json, Path) -> V raise DecodeError,
) -> BitArrayOption[V] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  match dec_kind_of(j, path) {
    "bytes" => Bytes(location~)
    "int" => Int(location~)
    "float" => Float(location~)
    "bits" => Bits(location~)
    "utf8" => Utf8(location~)
    "utf16" => Utf16(location~)
    "utf32" => Utf32(location~)
    "utf8_codepoint" => Utf8Codepoint(location~)
    "utf16_codepoint" => Utf16Codepoint(location~)
    "utf32_codepoint" => Utf32Codepoint(location~)
    "signed" => Signed(location~)
    "unsigned" => Unsigned(location~)
    "big" => Big(location~)
    "little" => Little(location~)
    "native" => Native(location~)
    "size" =>
      Size(
        location~,
        value=dec_field(j, path, "value", f),
        short_form=dec_field(j, path, "short_form", dec_bool),
      )
    "unit" => Unit(location~, value=dec_field(j, path, "value", dec_int))
    other => fail(Key(path, "kind"), "unknown bit array option \"\{other}\"")
  }
}

///|
fn dec_todo_kind(j : Json, path : Path) -> TodoKind raise DecodeError {
  match dec_kind_of(j, path) {
    "keyword" => Keyword
    "empty_function" =>
      EmptyFunction(
        function_location=dec_field(j, path, "function_location", dec_span),
      )
    "incomplete_use" => IncompleteUse
    "empty_block" => EmptyBlock
    other => fail(Key(path, "kind"), "unknown todo kind \"\{other}\"")
  }
}

///|
fn dec_function_literal_kind(
  j : Json,
  path : Path,
) -> FunctionLiteralKind raise DecodeError {
  match dec_kind_of(j, path) {
    "capture" => Capture(hole=dec_field(j, path, "hole", dec_span))
    "anonymous" => Anonymous(head=dec_field(j, path, "head", dec_span))
    "use" => Use(location=dec_field(j, path, "location", dec_span))
    other =>
      fail(Key(path, "kind"), "unknown function literal kind \"\{other}\"")
  }
}

///|
pub fn decode_expr(json : Json) -> Expr raise DecodeError {
  dec_expr(json, Root)
}

///|
fn dec_expr(j : Json, path : Path) -> Expr raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      Int(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_string),
        int_value=dec_field(j, path, "int_value", dec_big_int),
      )
    "float" => {
      let value = dec_field(j, path, "value", dec_string)
      Float(
        location=dec_field(j, path, "location", dec_span),
        value~,
        float_value=dec_float_value(value, path),
      )
    }
    "string" =>
      String(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_string),
      )
    "block" =>
      Block(
        location=dec_field(j, path, "location", dec_span),
        statements=dec_field(j, path, "statements", (v, p) => {
          dec_array(v, p, dec_statement)
        }),
      )
    "var" =>
      Var(
        location=dec_field(j, path, "location", dec_span),
        name=dec_field(j, path, "name", dec_string),
      )
    "fn" =>
      Fn(
        location=dec_field(j, path, "location", dec_span),
        kind=dec_field(j, path, "fn_kind", dec_function_literal_kind),
        end_of_head_byte_index=dec_field(
          j, path, "end_of_head_byte_index", dec_int,
        ),
        arguments=dec_field(j, path, "arguments", (v, p) => {
          dec_array(v, p, dec_arg)
        }),
        body=dec_field(j, path, "body", (v, p) => dec_array(v, p, dec_statement)),
        return_annotation=dec_field(j, path, "return_annotation", (v, p) => {
          dec_nullable(v, p, dec_type_ast)
        }),
      )
    "list" =>
      List(
        location=dec_field(j, path, "location", dec_span),
        elements=dec_field(j, path, "elements", (v, p) => {
          dec_array(v, p, dec_expr)
        }),
        tail=dec_field(j, path, "tail", (v, p) => dec_nullable(v, p, dec_expr)),
      )
    "call" =>
      Call(
        location=dec_field(j, path, "location", dec_span),
        fun=dec_field(j, path, "fun", dec_expr),
        arguments=dec_field(j, path, "arguments", (v, p) => {
          dec_array(v, p, (v2, p2) => dec_call_arg(v2, p2, dec_expr))
        }),
        open_parenthesis=dec_field(j, path, "open_parenthesis", dec_int),
      )
    "bin_op" =>
      BinOp(
        location=dec_field(j, path, "location", dec_span),
        operator=dec_field(j, path, "operator", dec_bin_op),
        operator_start=dec_field(j, path, "operator_start", dec_int),
        left=dec_field(j, path, "left", dec_expr),
        right=dec_field(j, path, "right", dec_expr),
      )
    "pipeline" =>
      Pipeline(
        expressions=dec_field(j, path, "expressions", (v, p) => {
          dec_array(v, p, dec_expr)
        }),
      )
    "case" =>
      Case(
        location=dec_field(j, path, "location", dec_span),
        subjects=dec_field(j, path, "subjects", (v, p) => {
          dec_array(v, p, dec_expr)
        }),
        clauses=dec_field(j, path, "clauses", (v, p) => {
          dec_nullable(v, p, (v2, p2) => dec_array(v2, p2, dec_clause))
        }),
      )
    "field_access" =>
      FieldAccess(
        location=dec_field(j, path, "location", dec_span),
        label_location=dec_field(j, path, "label_location", dec_span),
        label=dec_field(j, path, "label", dec_string),
        container=dec_field(j, path, "container", dec_expr),
      )
    "tuple" =>
      Tuple(
        location=dec_field(j, path, "location", dec_span),
        elements=dec_field(j, path, "elements", (v, p) => {
          dec_array(v, p, dec_expr)
        }),
      )
    "tuple_index" =>
      TupleIndex(
        location=dec_field(j, path, "location", dec_span),
        index=dec_field(j, path, "index", dec_uint64),
        tuple=dec_field(j, path, "tuple", dec_expr),
      )
    "todo" =>
      Todo(
        kind=dec_field(j, path, "todo_kind", dec_todo_kind),
        location=dec_field(j, path, "location", dec_span),
        message=dec_field(j, path, "message", (v, p) => {
          dec_nullable(v, p, dec_expr)
        }),
      )
    "panic" =>
      Panic(
        location=dec_field(j, path, "location", dec_span),
        message=dec_field(j, path, "message", (v, p) => {
          dec_nullable(v, p, dec_expr)
        }),
      )
    "echo" =>
      Echo(
        location=dec_field(j, path, "location", dec_span),
        keyword_end=dec_field(j, path, "keyword_end", dec_int),
        expression=dec_field(j, path, "expression", (v, p) => {
          dec_nullable(v, p, dec_expr)
        }),
        message=dec_field(j, path, "message", (v, p) => {
          dec_nullable(v, p, dec_expr)
        }),
      )
    "bit_array" =>
      BitArray(
        location=dec_field(j, path, "location", dec_span),
        segments=dec_field(j, path, "segments", (v, p) => {
          dec_array(v, p, (v2, p2) => dec_bit_array_segment(v2, p2, dec_expr))
        }),
      )
    "record_update" =>
      RecordUpdate(
        location=dec_field(j, path, "location", dec_span),
        spread_start=dec_field(j, path, "spread_start", dec_int),
        constructor_=dec_field(j, path, "constructor", dec_expr),
        record=dec_field(j, path, "record", (v, p) => {
          dec_record_being_updated(v, p, dec_expr)
        }),
        arguments=dec_field(j, path, "arguments", (v, p) => {
          dec_array(v, p, (v2, p2) => dec_record_update_arg(v2, p2, dec_expr))
        }),
      )
    "negate_bool" =>
      NegateBool(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_expr),
      )
    "negate_int" =>
      NegateInt(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_expr),
      )
    other => fail(Key(path, "kind"), "unknown expression kind \"\{other}\"")
  }
}

///|
fn dec_clause(j : Json, path : Path) -> Clause raise DecodeError {
  {
    location: dec_field(j, path, "location", dec_span),
    pattern: dec_field(j, path, "pattern", (v, p) => {
      dec_array(v, p, dec_pattern)
    }),
    alternative_patterns: dec_field(j, path, "alternative_patterns", (v, p) => {
      dec_array(v, p, (v2, p2) => dec_array(v2, p2, dec_pattern))
    }),
    guard_: dec_field(j, path, "guard", (v, p) => {
      dec_nullable(v, p, dec_clause_guard)
    }),
    then: dec_field(j, path, "then", dec_expr),
  }
}

///|
pub fn decode_clause_guard(json : Json) -> ClauseGuard raise DecodeError {
  dec_clause_guard(json, Root)
}

///|
fn dec_clause_guard(j : Json, path : Path) -> ClauseGuard raise DecodeError {
  match dec_kind_of(j, path) {
    "block" =>
      Block(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_clause_guard),
      )
    "binary_operator" =>
      BinaryOperator(
        location=dec_field(j, path, "location", dec_span),
        operator=dec_field(j, path, "operator", dec_bin_op),
        operator_start=dec_field(j, path, "operator_start", dec_int),
        left=dec_field(j, path, "left", dec_clause_guard),
        right=dec_field(j, path, "right", dec_clause_guard),
      )
    "not" =>
      Not(
        location=dec_field(j, path, "location", dec_span),
        expression=dec_field(j, path, "expression", dec_clause_guard),
      )
    "var" =>
      Var(
        location=dec_field(j, path, "location", dec_span),
        name=dec_field(j, path, "name", dec_string),
      )
    "tuple_index" =>
      TupleIndex(
        location=dec_field(j, path, "location", dec_span),
        index=dec_field(j, path, "index", dec_uint64),
        tuple=dec_field(j, path, "tuple", dec_clause_guard),
      )
    "field_access" =>
      FieldAccess(
        label_location=dec_field(j, path, "label_location", dec_span),
        index=dec_field(j, path, "index", (v, p) => {
          dec_nullable(v, p, dec_uint64)
        }),
        label=dec_field(j, path, "label", dec_string),
        container=dec_field(j, path, "container", dec_clause_guard),
      )
    "constant" => Constant(dec_field(j, path, "constant", dec_constant))
    other => fail(Key(path, "kind"), "unknown clause guard kind \"\{other}\"")
  }
}

///|
pub fn decode_pattern(json : Json) -> Pattern raise DecodeError {
  dec_pattern(json, Root)
}

///|
fn dec_pattern(j : Json, path : Path) -> Pattern raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      Int(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_string),
        int_value=dec_field(j, path, "int_value", dec_big_int),
      )
    "float" => {
      let value = dec_field(j, path, "value", dec_string)
      Float(
        location=dec_field(j, path, "location", dec_span),
        value~,
        float_value=dec_float_value(value, path),
      )
    }
    "string" =>
      String(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_string),
      )
    "variable" =>
      Variable(
        location=dec_field(j, path, "location", dec_span),
        name=dec_field(j, path, "name", dec_string),
      )
    "bit_array_size" =>
      BitArraySize(dec_field(j, path, "size", dec_bit_array_size))
    "assign" =>
      Assign(
        name=dec_field(j, path, "name", dec_string),
        location=dec_field(j, path, "location", dec_span),
        pattern=dec_field(j, path, "pattern", dec_pattern),
      )
    "discard" =>
      Discard(
        name=dec_field(j, path, "name", dec_string),
        location=dec_field(j, path, "location", dec_span),
      )
    "list" =>
      List(
        location=dec_field(j, path, "location", dec_span),
        elements=dec_field(j, path, "elements", (v, p) => {
          dec_array(v, p, dec_pattern)
        }),
        tail=dec_field(j, path, "tail", (v, p) => {
          dec_nullable(v, p, (v2, p2) => {
            location: dec_field(v2, p2, "location", dec_span),
            pattern: dec_field(v2, p2, "pattern", dec_pattern),
          })
        }),
      )
    "constructor" =>
      Constructor(
        location=dec_field(j, path, "location", dec_span),
        name_location=dec_field(j, path, "name_location", dec_span),
        name=dec_field(j, path, "name", dec_string),
        arguments=dec_field(j, path, "arguments", (v, p) => {
          dec_array(v, p, (v2, p2) => dec_call_arg(v2, p2, dec_pattern))
        }),
        module_=dec_field(j, path, "module", (v, p) => {
          dec_nullable(v, p, dec_spanned_string)
        }),
        spread=dec_field(j, path, "spread", (v, p) => {
          dec_nullable(v, p, dec_span)
        }),
      )
    "tuple" =>
      Tuple(
        location=dec_field(j, path, "location", dec_span),
        elements=dec_field(j, path, "elements", (v, p) => {
          dec_array(v, p, dec_pattern)
        }),
      )
    "bit_array" =>
      BitArray(
        location=dec_field(j, path, "location", dec_span),
        segments=dec_field(j, path, "segments", (v, p) => {
          dec_array(v, p, (v2, p2) => dec_bit_array_segment(v2, p2, dec_pattern))
        }),
      )
    "string_prefix" =>
      StringPrefix(
        location=dec_field(j, path, "location", dec_span),
        left_location=dec_field(j, path, "left_location", dec_span),
        left_side_assignment=dec_field(j, path, "left_side_assignment", (v, p) => {
          dec_nullable(v, p, (v2, p2) => {
            name: dec_field(v2, p2, "name", dec_string),
            name_start_position: dec_field(
              v2, p2, "name_start_position", dec_int,
            ),
            location: dec_field(v2, p2, "location", dec_span),
          })
        }),
        right_location=dec_field(j, path, "right_location", dec_span),
        left_side_string=dec_field(j, path, "left_side_string", dec_string),
        right_side_assignment=dec_field(
          j, path, "right_side_assignment", dec_assign_name,
        ),
      )
    other => fail(Key(path, "kind"), "unknown pattern kind \"\{other}\"")
  }
}

///|
fn dec_bit_array_size(j : Json, path : Path) -> BitArraySize raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      Int(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_string),
        int_value=dec_field(j, path, "int_value", dec_big_int),
      )
    "variable" =>
      Variable(
        location=dec_field(j, path, "location", dec_span),
        name=dec_field(j, path, "name", dec_string),
      )
    "binary_operator" =>
      BinaryOperator(
        location=dec_field(j, path, "location", dec_span),
        operator=dec_field(j, path, "operator", dec_int_operator),
        left=dec_field(j, path, "left", dec_bit_array_size),
        right=dec_field(j, path, "right", dec_bit_array_size),
      )
    "block" =>
      Block(
        location=dec_field(j, path, "location", dec_span),
        inner=dec_field(j, path, "inner", dec_bit_array_size),
      )
    other => fail(Key(path, "kind"), "unknown bit array size kind \"\{other}\"")
  }
}

///|
pub fn decode_constant(json : Json) -> Constant raise DecodeError {
  dec_constant(json, Root)
}

///|
fn dec_constant(j : Json, path : Path) -> Constant raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      Int(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_string),
        int_value=dec_field(j, path, "int_value", dec_big_int),
      )
    "float" => {
      let value = dec_field(j, path, "value", dec_string)
      Float(
        location=dec_field(j, path, "location", dec_span),
        value~,
        float_value=dec_float_value(value, path),
      )
    }
    "string" =>
      String(
        location=dec_field(j, path, "location", dec_span),
        value=dec_field(j, path, "value", dec_string),
      )
    "tuple" =>
      Tuple(
        location=dec_field(j, path, "location", dec_span),
        elements=dec_field(j, path, "elements", (v, p) => {
          dec_array(v, p, dec_constant)
        }),
      )
    "list" =>
      List(
        location=dec_field(j, path, "location", dec_span),
        elements=dec_field(j, path, "elements", (v, p) => {
          dec_array(v, p, dec_constant)
        }),
        tail=dec_field(j, path, "tail", (v, p) => {
          dec_nullable(v, p, dec_constant)
        }),
      )
    "record" =>
      Record(
        location=dec_field(j, path, "location", dec_span),
        arguments_start_position=dec_field(
          j, path, "arguments_start_position", dec_int,
        ),
        module_=dec_field(j, path, "module", (v, p) => {
          dec_nullable(v, p, dec_spanned_string)
        }),
        name=dec_field(j, path, "name", dec_string),
        arguments=dec_field(j, path, "arguments", (v, p) => {
          dec_nullable(v, p, (v2, p2) => {
            dec_array(v2, p2, (v3, p3) => dec_call_arg(v3, p3, dec_constant))
          })
        }),
      )
    "record_update" =>
      RecordUpdate(
        location=dec_field(j, path, "location", dec_span),
        constructor_location=dec_field(
          j, path, "constructor_location", dec_span,
        ),
        module_=dec_field(j, path, "module", (v, p) => {
          dec_nullable(v, p, dec_spanned_string)
        }),
        name=dec_field(j, path, "name", dec_string),
        record=dec_field(j, path, "record", (v, p) => {
          dec_record_being_updated(v, p, dec_constant)
        }),
        arguments=dec_field(j, path, "arguments", (v, p) => {
          dec_array(v, p, (v2, p2) => {
            dec_record_update_arg(v2, p2, dec_constant)
          })
        }),
      )
    "bit_array" =>
      BitArray(
        location=dec_field(j, path, "location", dec_span),
        segments=dec_field(j, path, "segments", (v, p) => {
          dec_array(v, p, (v2, p2) => {
            dec_bit_array_segment(v2, p2, dec_constant)
          })
        }),
      )
    "var" =>
      Var(
        location=dec_field(j, path, "location", dec_span),
        module_=dec_field(j, path, "module", (v, p) => {
          dec_nullable(v, p, dec_spanned_string)
        }),
        name=dec_field(j, path, "name", dec_string),
      )
    "binary_operator" =>
      BinaryOperator(
        location=dec_field(j, path, "location", dec_span),
        operator_start=dec_field(j, path, "operator_start", dec_int),
        operator=dec_field(j, path, "operator", dec_bin_op),
        left=dec_field(j, path, "left", dec_constant),
        right=dec_field(j, path, "right", dec_constant),
      )
    "todo" =>
      Todo(
        location=dec_field(j, path, "location", dec_span),
        message=dec_field(j, path, "message", (v, p) => {
          dec_nullable(v, p, dec_constant)
        }),
      )
    other => fail(Key(path, "kind"), "unknown constant kind \"\{other}\"")
  }
}

///|
pub fn decode_extra(json : Json) -> ModuleExtra raise DecodeError {
  dec_extra(json, Root)
}

///|
fn dec_extra(j : Json, path : Path) -> ModuleExtra raise DecodeError {
  {
    module_comments: dec_field(j, path, "module_comments", (v, p) => {
      dec_array(v, p, dec_span)
    }),
    doc_comments: dec_field(j, path, "doc_comments", (v, p) => {
      dec_array(v, p, dec_span)
    }),
    comments: dec_field(j, path, "comments", (v, p) => dec_array(v, p, dec_span)),
    empty_lines: dec_field(j, path, "empty_lines", (v, p) => {
      dec_array(v, p, dec_int)
    }),
    new_lines: dec_field(j, path, "new_lines", (v, p) => {
      dec_array(v, p, dec_int)
    }),
    trailing_commas: dec_field(j, path, "trailing_commas", (v, p) => {
      dec_array(v, p, dec_int)
    }),
  }
}

///|
pub fn decode_warning(json : Json) -> Warning raise DecodeError {
  dec_warning(json, Root)
}

///|
fn dec_warning(j : Json, path : Path) -> Warning raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  match dec_kind_of(j, path) {
    "deprecated_list_prepend" => DeprecatedListPrepend(location~)
    "deprecated_list_pattern" => DeprecatedListPattern(location~)
    "deprecated_list_catch_all_pattern" =>
      DeprecatedListCatchAllPattern(location~)
    "deprecated_list_spread_as_variable_pattern" =>
      DeprecatedListSpreadAsVariablePattern(
        location~,
        name=dec_field(j, path, "name", dec_string),
      )
    "deprecated_record_spread_pattern" =>
      DeprecatedRecordSpreadPattern(location~)
    "deprecated_empty_clause_guard" => DeprecatedEmptyClauseGuard(location~)
    "deprecated_target_shorthand" =>
      DeprecatedTargetShorthand(
        target=dec_field(j, path, "target", dec_target),
        location~,
      )
    "detached_doc_comment" => DetachedDocComment(location~)
    other => fail(Key(path, "kind"), "unknown warning kind \"\{other}\"")
  }
}
