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
priv enum Path {
  Root
  Key(Path, String)
  Index(Path, Int32)
}

///|
/// The path as text (`$.module.definitions[3].definition`). A loop over the
/// parents, so a path of any depth renders.
fn Path::render(self : Path) -> String {
  let segments = for p = self, acc = @list.List([]) {
    match p {
      Root => break acc
      Key(parent, key) => continue parent, acc.prepend(".\{key}")
      Index(parent, i) => continue parent, acc.prepend("[\{i}]")
    }
  }
  let sb = StringBuilder()
  sb.write_string("$")
  for segment in segments {
    sb.write_string(segment)
  }
  sb.to_string()
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
    Some(v) => f(v, Key(path, key))
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
        out.push(f(item, Index(path, i)))
      }
      out[:]
    }
    other => fail(path, "expected an ARRAY, found \{json_kind(other)}")
  }
}

///|
/// Decode the child node under `key` with `f` as a new step and hand the
/// value to `k`. The field must be present.
fn[T, R] child(
  j : Json,
  path : Path,
  key : String,
  f : (Json, Path, (T) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (T) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_object(j, path).get(key) {
    Some(v) => Decoding(() => f(v, Key(path, key), k))
    None => fail(Key(path, key), "missing field")
  }
}

///|
/// Decode an optional child node under `key`: `null` gives `None`.
fn[T, R] child_opt(
  j : Json,
  path : Path,
  key : String,
  f : (Json, Path, (T) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (T?) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_object(j, path).get(key) {
    Some(Null) => yield_(k, None)
    Some(v) => Decoding(() => f(v, Key(path, key), v2 => yield_(k, Some(v2))))
    None => fail(Key(path, key), "missing field")
  }
}

///|
/// Decode the array of child nodes under `key`, element by element.
fn[T, R] child_list(
  j : Json,
  path : Path,
  key : String,
  f : (Json, Path, (T) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (ArrayView[T]) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_object(j, path).get(key) {
    Some(v) => Decoding(() => children(v, Key(path, key), f, k))
    None => fail(Key(path, key), "missing field")
  }
}

///|
/// Decode every element of an array of child nodes; element `i` gets the
/// path `path[i]`.
fn[T, R] children(
  j : Json,
  path : Path,
  f : (Json, Path, (T) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (ArrayView[T]) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match j {
    Array(items) =>
      each_decode(items[:], (v, i, k2) => f(v, Index(path, i), k2), k)
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
  run_decode(dec_parsed(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_parsed(
  j : Json,
  path : Path,
  k : (Parsed) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let extra = dec_field(j, path, "extra", dec_extra)
  let warnings = dec_field(j, path, "warnings", (v, p) => {
    dec_array(v, p, dec_warning)
  })
  child(j, path, "module", dec_module, module_ => {
    yield_(k, { module_, extra, warnings, })
  })
}

///|
pub fn decode_module(json : Json) -> Module raise DecodeError {
  run_decode(dec_module(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_module(
  j : Json,
  path : Path,
  k : (Module) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  child_list(j, path, "definitions", dec_targeted_definition, definitions => {
    yield_(k, { definitions, })
  })
}

///|
fn[R] dec_targeted_definition(
  j : Json,
  path : Path,
  k : (TargetedDefinition) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let target = dec_field(j, path, "target", (v, p) => {
    dec_nullable(v, p, dec_target)
  })
  child(j, path, "definition", dec_definition, definition => {
    yield_(k, { definition, target, })
  })
}

///|
pub fn decode_definition(json : Json) -> Definition raise DecodeError {
  run_decode(dec_definition(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_definition(
  j : Json,
  path : Path,
  k : (Definition) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "function" => dec_function(j, path, f => yield_(k, Function(f)))
    "type_alias" => {
      let location = dec_field(j, path, "location", dec_span)
      let alias_ = dec_field(j, path, "alias", dec_string)
      let name_location = dec_field(j, path, "name_location", dec_span)
      let parameters = dec_field(j, path, "parameters", (v, p) => {
        dec_array(v, p, dec_spanned_string)
      })
      let publicity = dec_field(j, path, "publicity", dec_publicity)
      let documentation = dec_field(j, path, "documentation", (v, p) => {
        dec_nullable(v, p, dec_documentation)
      })
      let deprecation = dec_field(j, path, "deprecation", dec_deprecation)
      child(j, path, "type_ast", dec_type_ast, type_ast => {
        yield_(
          k,
          TypeAlias({
            location,
            alias_,
            name_location,
            parameters,
            type_ast,
            publicity,
            documentation,
            deprecation,
          }),
        )
      })
    }
    "custom_type" => {
      let location = dec_field(j, path, "location", dec_span)
      let end_position = dec_field(j, path, "end_position", dec_int)
      let name = dec_field(j, path, "name", dec_string)
      let name_location = dec_field(j, path, "name_location", dec_span)
      let publicity = dec_field(j, path, "publicity", dec_publicity)
      let documentation = dec_field(j, path, "documentation", (v, p) => {
        dec_nullable(v, p, dec_documentation)
      })
      let deprecation = dec_field(j, path, "deprecation", dec_deprecation)
      let opaque_ = dec_field(j, path, "opaque", dec_bool)
      let parameters = dec_field(j, path, "parameters", (v, p) => {
        dec_array(v, p, dec_spanned_string)
      })
      let external_erlang = dec_field(j, path, "external_erlang", (v, p) => {
        dec_nullable(v, p, dec_external)
      })
      let external_javascript = dec_field(j, path, "external_javascript", (v, p) => {
        dec_nullable(v, p, dec_external)
      })
      child_list(j, path, "constructors", dec_record_constructor, constructors => {
        yield_(
          k,
          CustomType({
            location,
            end_position,
            name,
            name_location,
            publicity,
            constructors,
            documentation,
            deprecation,
            opaque_,
            parameters,
            external_erlang,
            external_javascript,
          }),
        )
      })
    }
    "import" =>
      yield_(
        k,
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
        }),
      )
    "module_constant" => {
      let documentation = dec_field(j, path, "documentation", (v, p) => {
        dec_nullable(v, p, dec_documentation)
      })
      let location = dec_field(j, path, "location", dec_span)
      let publicity = dec_field(j, path, "publicity", dec_publicity)
      let name = dec_field(j, path, "name", dec_string)
      let name_location = dec_field(j, path, "name_location", dec_span)
      let deprecation = dec_field(j, path, "deprecation", dec_deprecation)
      child_opt(j, path, "annotation", dec_type_ast, annotation => {
        child(j, path, "value", dec_constant, value => {
          yield_(
            k,
            ModuleConstant({
              documentation,
              location,
              publicity,
              name,
              name_location,
              annotation,
              value,
              deprecation,
            }),
          )
        })
      })
    }
    other => fail(Key(path, "kind"), "unknown definition kind \"\{other}\"")
  }
}

///|
fn[R] dec_function(
  j : Json,
  path : Path,
  k : (Function) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  let body_start = dec_field(j, path, "body_start", (v, p) => {
    dec_nullable(v, p, dec_int)
  })
  let end_position = dec_field(j, path, "end_position", dec_int)
  let name = dec_field(j, path, "name", (v, p) => {
    dec_nullable(v, p, dec_spanned_string)
  })
  let publicity = dec_field(j, path, "publicity", dec_publicity)
  let deprecation = dec_field(j, path, "deprecation", dec_deprecation)
  let documentation = dec_field(j, path, "documentation", (v, p) => {
    dec_nullable(v, p, dec_documentation)
  })
  let external_erlang = dec_field(j, path, "external_erlang", (v, p) => {
    dec_nullable(v, p, dec_external)
  })
  let external_javascript = dec_field(j, path, "external_javascript", (v, p) => {
    dec_nullable(v, p, dec_external)
  })
  child_list(j, path, "arguments", dec_arg, arguments => {
    child_list(j, path, "body", dec_statement, body => {
      child_opt(j, path, "return_annotation", dec_type_ast, return_annotation => {
        yield_(k, {
          location,
          body_start,
          end_position,
          name,
          arguments,
          body,
          publicity,
          deprecation,
          return_annotation,
          documentation,
          external_erlang,
          external_javascript,
        })
      })
    })
  })
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
fn[R] dec_record_constructor(
  j : Json,
  path : Path,
  k : (RecordConstructor) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  let name_location = dec_field(j, path, "name_location", dec_span)
  let name = dec_field(j, path, "name", dec_string)
  let documentation = dec_field(j, path, "documentation", (v, p) => {
    dec_nullable(v, p, dec_documentation)
  })
  let deprecation = dec_field(j, path, "deprecation", dec_deprecation)
  child_list(j, path, "arguments", dec_record_constructor_arg, arguments => {
    yield_(k, {
      location,
      name_location,
      name,
      arguments,
      documentation,
      deprecation,
    })
  })
}

///|
fn[R] dec_record_constructor_arg(
  j : Json,
  path : Path,
  k : (RecordConstructorArg) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let label = dec_field(j, path, "label", (v, p) => {
    dec_nullable(v, p, dec_spanned_string)
  })
  let location = dec_field(j, path, "location", dec_span)
  let doc = dec_field(j, path, "doc", (v, p) => {
    dec_nullable(v, p, dec_documentation)
  })
  child(j, path, "ast", dec_type_ast, ast => {
    yield_(k, { label, ast, location, doc, })
  })
}

///|
fn[R] dec_arg(
  j : Json,
  path : Path,
  k : (Arg) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let names = dec_field(j, path, "names", dec_arg_names)
  let location = dec_field(j, path, "location", dec_span)
  child_opt(j, path, "annotation", dec_type_ast, annotation => {
    yield_(k, { names, location, annotation, })
  })
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
  run_decode(dec_type_ast(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_type_ast(
  j : Json,
  path : Path,
  k : (TypeAst) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "constructor" => {
      let location = dec_field(j, path, "location", dec_span)
      let name = dec_field(j, path, "name", dec_type_ast_constructor_name)
      let start_parentheses = dec_field(j, path, "start_parentheses", (v, p) => {
        dec_nullable(v, p, dec_int)
      })
      child_list(j, path, "arguments", dec_type_ast, arguments => {
        yield_(
          k,
          Constructor({ location, name, arguments, start_parentheses, }),
        )
      })
    }
    "fn" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "arguments", dec_type_ast, arguments => {
        child(j, path, "return_", dec_type_ast, return_ => {
          yield_(k, Fn({ location, arguments, return_, }))
        })
      })
    }
    "var" =>
      yield_(
        k,
        Var({
          location: dec_field(j, path, "location", dec_span),
          name: dec_field(j, path, "name", dec_string),
        }),
      )
    "tuple" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "elements", dec_type_ast, elements => {
        yield_(k, Tuple({ location, elements, }))
      })
    }
    "hole" =>
      yield_(
        k,
        Hole({
          location: dec_field(j, path, "location", dec_span),
          name: dec_field(j, path, "name", dec_string),
        }),
      )
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
  run_decode(dec_statement(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_statement(
  j : Json,
  path : Path,
  k : (Statement) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "expression" =>
      child(j, path, "expression", dec_expr, e => yield_(k, Expression(e)))
    "assignment" => {
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "value", dec_expr, value => {
        child(j, path, "pattern", dec_pattern, pattern => {
          child(j, path, "assignment_kind", dec_assignment_kind, kind => {
            child_opt(j, path, "annotation", dec_type_ast, annotation => {
              yield_(
                k,
                Assignment({ location, value, pattern, kind, annotation, }),
              )
            })
          })
        })
      })
    }
    "use" => {
      let location = dec_field(j, path, "location", dec_span)
      let right_hand_side_location = dec_field(
        j, path, "right_hand_side_location", dec_span,
      )
      let assignments_location = dec_field(
        j, path, "assignments_location", dec_span,
      )
      child(j, path, "call", dec_expr, call => {
        child_list(j, path, "assignments", dec_use_assignment, assignments => {
          yield_(
            k,
            Use({
              call,
              location,
              right_hand_side_location,
              assignments_location,
              assignments,
            }),
          )
        })
      })
    }
    "assert" => {
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "value", dec_expr, value => {
        child_opt(j, path, "message", dec_expr, message => {
          yield_(k, Assert({ location, value, message, }))
        })
      })
    }
    other => fail(Key(path, "kind"), "unknown statement kind \"\{other}\"")
  }
}

///|
fn[R] dec_assignment_kind(
  j : Json,
  path : Path,
  k : (AssignmentKind) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "let" => yield_(k, Let)
    "generated" => yield_(k, Generated)
    "assert" => {
      let location = dec_field(j, path, "location", dec_span)
      let assert_keyword_start = dec_field(
        j, path, "assert_keyword_start", dec_int,
      )
      child_opt(j, path, "message", dec_expr, message => {
        yield_(k, Assert(location~, assert_keyword_start~, message~))
      })
    }
    other => fail(Key(path, "kind"), "unknown assignment kind \"\{other}\"")
  }
}

///|
fn[R] dec_use_assignment(
  j : Json,
  path : Path,
  k : (UseAssignment) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  child(j, path, "pattern", dec_pattern, pattern => {
    child_opt(j, path, "annotation", dec_type_ast, annotation => {
      yield_(k, { location, pattern, annotation, })
    })
  })
}

///|
fn[A, R] dec_call_arg(
  j : Json,
  path : Path,
  f : (Json, Path, (A) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (CallArg[A]) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let label = dec_field(j, path, "label", (v, p) => {
    dec_nullable(v, p, dec_string)
  })
  let location = dec_field(j, path, "location", dec_span)
  let implicit = dec_field(j, path, "implicit", (v, p) => {
    dec_nullable(v, p, dec_implicit)
  })
  child(j, path, "value", f, value => {
    yield_(k, { label, location, value, implicit, })
  })
}

///|
fn[A, R] dec_record_being_updated(
  j : Json,
  path : Path,
  f : (Json, Path, (A) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (RecordBeingUpdated[A]) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  child(j, path, "base", f, base => yield_(k, { base, location, }))
}

///|
fn[A, R] dec_record_update_arg(
  j : Json,
  path : Path,
  f : (Json, Path, (A) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (RecordUpdateArg[A]) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let label = dec_field(j, path, "label", dec_string)
  let location = dec_field(j, path, "location", dec_span)
  child(j, path, "value", f, value => yield_(k, { label, location, value, }))
}

///|
fn[V, R] dec_bit_array_segment(
  j : Json,
  path : Path,
  f : (Json, Path, (V) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (BitArraySegment[V]) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  child(j, path, "value", f, value => {
    child_list(
      j,
      path,
      "options",
      (v, p, k2) => dec_bit_array_option(v, p, f, k2),
      options => yield_(k, { location, value, options, }),
    )
  })
}

///|
fn[V, R] dec_bit_array_option(
  j : Json,
  path : Path,
  f : (Json, Path, (V) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (BitArrayOption[V]) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  match dec_kind_of(j, path) {
    "bytes" => yield_(k, Bytes(location~))
    "int" => yield_(k, Int(location~))
    "float" => yield_(k, Float(location~))
    "bits" => yield_(k, Bits(location~))
    "utf8" => yield_(k, Utf8(location~))
    "utf16" => yield_(k, Utf16(location~))
    "utf32" => yield_(k, Utf32(location~))
    "utf8_codepoint" => yield_(k, Utf8Codepoint(location~))
    "utf16_codepoint" => yield_(k, Utf16Codepoint(location~))
    "utf32_codepoint" => yield_(k, Utf32Codepoint(location~))
    "signed" => yield_(k, Signed(location~))
    "unsigned" => yield_(k, Unsigned(location~))
    "big" => yield_(k, Big(location~))
    "little" => yield_(k, Little(location~))
    "native" => yield_(k, Native(location~))
    "size" => {
      let short_form = dec_field(j, path, "short_form", dec_bool)
      child(j, path, "value", f, value => {
        yield_(k, Size(location~, value~, short_form~))
      })
    }
    "unit" =>
      yield_(k, Unit(location~, value=dec_field(j, path, "value", dec_int)))
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
  run_decode(dec_expr(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_expr(
  j : Json,
  path : Path,
  k : (Expr) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      yield_(
        k,
        Int(
          location=dec_field(j, path, "location", dec_span),
          value=dec_field(j, path, "value", dec_string),
          int_value=dec_field(j, path, "int_value", dec_big_int),
        ),
      )
    "float" => {
      let value = dec_field(j, path, "value", dec_string)
      yield_(
        k,
        Float(
          location=dec_field(j, path, "location", dec_span),
          value~,
          float_value=dec_float_value(value, path),
        ),
      )
    }
    "string" =>
      yield_(
        k,
        String(
          location=dec_field(j, path, "location", dec_span),
          value=dec_field(j, path, "value", dec_string),
        ),
      )
    "block" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "statements", dec_statement, statements => {
        yield_(k, Block(location~, statements~))
      })
    }
    "var" =>
      yield_(
        k,
        Var(
          location=dec_field(j, path, "location", dec_span),
          name=dec_field(j, path, "name", dec_string),
        ),
      )
    "fn" => {
      let location = dec_field(j, path, "location", dec_span)
      let kind = dec_field(j, path, "fn_kind", dec_function_literal_kind)
      let end_of_head_byte_index = dec_field(
        j, path, "end_of_head_byte_index", dec_int,
      )
      child_list(j, path, "arguments", dec_arg, arguments => {
        child_list(j, path, "body", dec_statement, body => {
          child_opt(j, path, "return_annotation", dec_type_ast, return_annotation => {
            yield_(
              k,
              Fn(
                location~,
                kind~,
                end_of_head_byte_index~,
                arguments~,
                body~,
                return_annotation~,
              ),
            )
          })
        })
      })
    }
    "list" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "elements", dec_expr, elements => {
        child_opt(j, path, "tail", dec_expr, tail => {
          yield_(k, List(location~, elements~, tail~))
        })
      })
    }
    "call" => {
      let location = dec_field(j, path, "location", dec_span)
      let open_parenthesis = dec_field(j, path, "open_parenthesis", dec_int)
      child(j, path, "fun", dec_expr, fun => {
        child_list(
          j,
          path,
          "arguments",
          (v, p, k2) => dec_call_arg(v, p, dec_expr, k2),
          arguments => {
            yield_(k, Call(location~, fun~, arguments~, open_parenthesis~))
          },
        )
      })
    }
    "bin_op" => {
      let location = dec_field(j, path, "location", dec_span)
      let operator = dec_field(j, path, "operator", dec_bin_op)
      let operator_start = dec_field(j, path, "operator_start", dec_int)
      child(j, path, "left", dec_expr, left => {
        child(j, path, "right", dec_expr, right => {
          yield_(k, BinOp(location~, operator~, operator_start~, left~, right~))
        })
      })
    }
    "pipeline" =>
      child_list(j, path, "expressions", dec_expr, expressions => {
        yield_(k, Pipeline(expressions~))
      })
    "case" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "subjects", dec_expr, subjects => {
        child_opt(
          j,
          path,
          "clauses",
          (v, p, k2) => children(v, p, dec_clause, k2),
          clauses => yield_(k, Case(location~, subjects~, clauses~)),
        )
      })
    }
    "field_access" => {
      let location = dec_field(j, path, "location", dec_span)
      let label_location = dec_field(j, path, "label_location", dec_span)
      let label = dec_field(j, path, "label", dec_string)
      child(j, path, "container", dec_expr, container => {
        yield_(k, FieldAccess(location~, label_location~, label~, container~))
      })
    }
    "tuple" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "elements", dec_expr, elements => {
        yield_(k, Tuple(location~, elements~))
      })
    }
    "tuple_index" => {
      let location = dec_field(j, path, "location", dec_span)
      let index = dec_field(j, path, "index", dec_uint64)
      child(j, path, "tuple", dec_expr, tuple => {
        yield_(k, TupleIndex(location~, index~, tuple~))
      })
    }
    "todo" => {
      let kind = dec_field(j, path, "todo_kind", dec_todo_kind)
      let location = dec_field(j, path, "location", dec_span)
      child_opt(j, path, "message", dec_expr, message => {
        yield_(k, Todo(kind~, location~, message~))
      })
    }
    "panic" => {
      let location = dec_field(j, path, "location", dec_span)
      child_opt(j, path, "message", dec_expr, message => {
        yield_(k, Panic(location~, message~))
      })
    }
    "echo" => {
      let location = dec_field(j, path, "location", dec_span)
      let keyword_end = dec_field(j, path, "keyword_end", dec_int)
      child_opt(j, path, "expression", dec_expr, expression => {
        child_opt(j, path, "message", dec_expr, message => {
          yield_(k, Echo(location~, keyword_end~, expression~, message~))
        })
      })
    }
    "bit_array" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(
        j,
        path,
        "segments",
        (v, p, k2) => dec_bit_array_segment(v, p, dec_expr, k2),
        segments => yield_(k, BitArray(location~, segments~)),
      )
    }
    "record_update" => {
      let location = dec_field(j, path, "location", dec_span)
      let spread_start = dec_field(j, path, "spread_start", dec_int)
      child(j, path, "constructor", dec_expr, constructor_ => {
        child(
          j,
          path,
          "record",
          (v, p, k2) => dec_record_being_updated(v, p, dec_expr, k2),
          record => {
            child_list(
              j,
              path,
              "arguments",
              (v, p, k2) => dec_record_update_arg(v, p, dec_expr, k2),
              arguments => {
                yield_(
                  k,
                  RecordUpdate(
                    location~,
                    spread_start~,
                    constructor_~,
                    record~,
                    arguments~,
                  ),
                )
              },
            )
          },
        )
      })
    }
    "negate_bool" => {
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "value", dec_expr, value => {
        yield_(k, NegateBool(location~, value~))
      })
    }
    "negate_int" => {
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "value", dec_expr, value => {
        yield_(k, NegateInt(location~, value~))
      })
    }
    other => fail(Key(path, "kind"), "unknown expression kind \"\{other}\"")
  }
}

///|
fn[R] dec_clause(
  j : Json,
  path : Path,
  k : (Clause) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  let location = dec_field(j, path, "location", dec_span)
  child_list(j, path, "pattern", dec_pattern, pattern => {
    child_list(
      j,
      path,
      "alternative_patterns",
      (v, p, k2) => children(v, p, dec_pattern, k2),
      alternative_patterns => {
        child_opt(j, path, "guard", dec_clause_guard, guard_ => {
          child(j, path, "then", dec_expr, then => {
            yield_(k, { location, pattern, alternative_patterns, guard_, then, })
          })
        })
      },
    )
  })
}

///|
pub fn decode_clause_guard(json : Json) -> ClauseGuard raise DecodeError {
  run_decode(dec_clause_guard(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_clause_guard(
  j : Json,
  path : Path,
  k : (ClauseGuard) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "block" => {
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "value", dec_clause_guard, value => {
        yield_(k, Block(location~, value~))
      })
    }
    "binary_operator" => {
      let location = dec_field(j, path, "location", dec_span)
      let operator = dec_field(j, path, "operator", dec_bin_op)
      let operator_start = dec_field(j, path, "operator_start", dec_int)
      child(j, path, "left", dec_clause_guard, left => {
        child(j, path, "right", dec_clause_guard, right => {
          yield_(
            k,
            BinaryOperator(location~, operator~, operator_start~, left~, right~),
          )
        })
      })
    }
    "not" => {
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "expression", dec_clause_guard, expression => {
        yield_(k, Not(location~, expression~))
      })
    }
    "var" =>
      yield_(
        k,
        Var(
          location=dec_field(j, path, "location", dec_span),
          name=dec_field(j, path, "name", dec_string),
        ),
      )
    "tuple_index" => {
      let location = dec_field(j, path, "location", dec_span)
      let index = dec_field(j, path, "index", dec_uint64)
      child(j, path, "tuple", dec_clause_guard, tuple => {
        yield_(k, TupleIndex(location~, index~, tuple~))
      })
    }
    "field_access" => {
      let label_location = dec_field(j, path, "label_location", dec_span)
      let index = dec_field(j, path, "index", (v, p) => {
        dec_nullable(v, p, dec_uint64)
      })
      let label = dec_field(j, path, "label", dec_string)
      child(j, path, "container", dec_clause_guard, container => {
        yield_(k, FieldAccess(label_location~, index~, label~, container~))
      })
    }
    "constant" =>
      child(j, path, "constant", dec_constant, c => yield_(k, Constant(c)))
    other => fail(Key(path, "kind"), "unknown clause guard kind \"\{other}\"")
  }
}

///|
pub fn decode_pattern(json : Json) -> Pattern raise DecodeError {
  run_decode(dec_pattern(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_pattern(
  j : Json,
  path : Path,
  k : (Pattern) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      yield_(
        k,
        Int(
          location=dec_field(j, path, "location", dec_span),
          value=dec_field(j, path, "value", dec_string),
          int_value=dec_field(j, path, "int_value", dec_big_int),
        ),
      )
    "float" => {
      let value = dec_field(j, path, "value", dec_string)
      yield_(
        k,
        Float(
          location=dec_field(j, path, "location", dec_span),
          value~,
          float_value=dec_float_value(value, path),
        ),
      )
    }
    "string" =>
      yield_(
        k,
        String(
          location=dec_field(j, path, "location", dec_span),
          value=dec_field(j, path, "value", dec_string),
        ),
      )
    "variable" =>
      yield_(
        k,
        Variable(
          location=dec_field(j, path, "location", dec_span),
          name=dec_field(j, path, "name", dec_string),
        ),
      )
    "bit_array_size" =>
      child(j, path, "size", dec_bit_array_size, s => yield_(k, BitArraySize(s)))
    "assign" => {
      let name = dec_field(j, path, "name", dec_string)
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "pattern", dec_pattern, pattern => {
        yield_(k, Assign(name~, location~, pattern~))
      })
    }
    "discard" =>
      yield_(
        k,
        Discard(
          name=dec_field(j, path, "name", dec_string),
          location=dec_field(j, path, "location", dec_span),
        ),
      )
    "list" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "elements", dec_pattern, elements => {
        child_opt(
          j,
          path,
          "tail",
          (v, p, k2) => {
            let location = dec_field(v, p, "location", dec_span)
            child(v, p, "pattern", dec_pattern, pattern => {
              yield_(k2, { location, pattern, })
            })
          },
          tail => yield_(k, List(location~, elements~, tail~)),
        )
      })
    }
    "constructor" => {
      let location = dec_field(j, path, "location", dec_span)
      let name_location = dec_field(j, path, "name_location", dec_span)
      let name = dec_field(j, path, "name", dec_string)
      let module_ = dec_field(j, path, "module", (v, p) => {
        dec_nullable(v, p, dec_spanned_string)
      })
      let spread = dec_field(j, path, "spread", (v, p) => {
        dec_nullable(v, p, dec_span)
      })
      child_list(
        j,
        path,
        "arguments",
        (v, p, k2) => dec_call_arg(v, p, dec_pattern, k2),
        arguments => {
          yield_(
            k,
            Constructor(
              location~,
              name_location~,
              name~,
              arguments~,
              module_~,
              spread~,
            ),
          )
        },
      )
    }
    "tuple" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "elements", dec_pattern, elements => {
        yield_(k, Tuple(location~, elements~))
      })
    }
    "bit_array" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(
        j,
        path,
        "segments",
        (v, p, k2) => dec_bit_array_segment(v, p, dec_pattern, k2),
        segments => yield_(k, BitArray(location~, segments~)),
      )
    }
    "string_prefix" =>
      yield_(
        k,
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
        ),
      )
    other => fail(Key(path, "kind"), "unknown pattern kind \"\{other}\"")
  }
}

///|
fn[R] dec_bit_array_size(
  j : Json,
  path : Path,
  k : (BitArraySize) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      yield_(
        k,
        Int(
          location=dec_field(j, path, "location", dec_span),
          value=dec_field(j, path, "value", dec_string),
          int_value=dec_field(j, path, "int_value", dec_big_int),
        ),
      )
    "variable" =>
      yield_(
        k,
        Variable(
          location=dec_field(j, path, "location", dec_span),
          name=dec_field(j, path, "name", dec_string),
        ),
      )
    "binary_operator" => {
      let location = dec_field(j, path, "location", dec_span)
      let operator = dec_field(j, path, "operator", dec_int_operator)
      child(j, path, "left", dec_bit_array_size, left => {
        child(j, path, "right", dec_bit_array_size, right => {
          yield_(k, BinaryOperator(location~, operator~, left~, right~))
        })
      })
    }
    "block" => {
      let location = dec_field(j, path, "location", dec_span)
      child(j, path, "inner", dec_bit_array_size, inner => {
        yield_(k, Block(location~, inner~))
      })
    }
    other => fail(Key(path, "kind"), "unknown bit array size kind \"\{other}\"")
  }
}

///|
pub fn decode_constant(json : Json) -> Constant raise DecodeError {
  run_decode(dec_constant(json, Root, v => Decoded(v)))
}

///|
fn[R] dec_constant(
  j : Json,
  path : Path,
  k : (Constant) -> Decode[R] raise DecodeError,
) -> Decode[R] raise DecodeError {
  match dec_kind_of(j, path) {
    "int" =>
      yield_(
        k,
        Int(
          location=dec_field(j, path, "location", dec_span),
          value=dec_field(j, path, "value", dec_string),
          int_value=dec_field(j, path, "int_value", dec_big_int),
        ),
      )
    "float" => {
      let value = dec_field(j, path, "value", dec_string)
      yield_(
        k,
        Float(
          location=dec_field(j, path, "location", dec_span),
          value~,
          float_value=dec_float_value(value, path),
        ),
      )
    }
    "string" =>
      yield_(
        k,
        String(
          location=dec_field(j, path, "location", dec_span),
          value=dec_field(j, path, "value", dec_string),
        ),
      )
    "tuple" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "elements", dec_constant, elements => {
        yield_(k, Tuple(location~, elements~))
      })
    }
    "list" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(j, path, "elements", dec_constant, elements => {
        child_opt(j, path, "tail", dec_constant, tail => {
          yield_(k, List(location~, elements~, tail~))
        })
      })
    }
    "record" => {
      let location = dec_field(j, path, "location", dec_span)
      let arguments_start_position = dec_field(
        j, path, "arguments_start_position", dec_int,
      )
      let module_ = dec_field(j, path, "module", (v, p) => {
        dec_nullable(v, p, dec_spanned_string)
      })
      let name = dec_field(j, path, "name", dec_string)
      child_opt(
        j,
        path,
        "arguments",
        (v, p, k2) => {
          children(
            v,
            p,
            (v2, p2, k3) => dec_call_arg(v2, p2, dec_constant, k3),
            k2,
          )
        },
        arguments => {
          yield_(
            k,
            Record(
              location~,
              arguments_start_position~,
              module_~,
              name~,
              arguments~,
            ),
          )
        },
      )
    }
    "record_update" => {
      let location = dec_field(j, path, "location", dec_span)
      let constructor_location = dec_field(
        j, path, "constructor_location", dec_span,
      )
      let module_ = dec_field(j, path, "module", (v, p) => {
        dec_nullable(v, p, dec_spanned_string)
      })
      let name = dec_field(j, path, "name", dec_string)
      child(
        j,
        path,
        "record",
        (v, p, k2) => dec_record_being_updated(v, p, dec_constant, k2),
        record => {
          child_list(
            j,
            path,
            "arguments",
            (v, p, k2) => dec_record_update_arg(v, p, dec_constant, k2),
            arguments => {
              yield_(
                k,
                RecordUpdate(
                  location~,
                  constructor_location~,
                  module_~,
                  name~,
                  record~,
                  arguments~,
                ),
              )
            },
          )
        },
      )
    }
    "bit_array" => {
      let location = dec_field(j, path, "location", dec_span)
      child_list(
        j,
        path,
        "segments",
        (v, p, k2) => dec_bit_array_segment(v, p, dec_constant, k2),
        segments => yield_(k, BitArray(location~, segments~)),
      )
    }
    "var" =>
      yield_(
        k,
        Var(
          location=dec_field(j, path, "location", dec_span),
          module_=dec_field(j, path, "module", (v, p) => {
            dec_nullable(v, p, dec_spanned_string)
          }),
          name=dec_field(j, path, "name", dec_string),
        ),
      )
    "binary_operator" => {
      let location = dec_field(j, path, "location", dec_span)
      let operator_start = dec_field(j, path, "operator_start", dec_int)
      let operator = dec_field(j, path, "operator", dec_bin_op)
      child(j, path, "left", dec_constant, left => {
        child(j, path, "right", dec_constant, right => {
          yield_(
            k,
            BinaryOperator(location~, operator_start~, operator~, left~, right~),
          )
        })
      })
    }
    "todo" => {
      let location = dec_field(j, path, "location", dec_span)
      child_opt(j, path, "message", dec_constant, message => {
        yield_(k, Todo(location~, message~))
      })
    }
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
