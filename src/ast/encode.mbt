// Canonical JSON for the AST: the schema of docs/ast-json.md. `canonical`
// writes objects with their keys in code-unit order (MoonBit's `Map` keeps
// insertion order and its `String` compare is length-first, so neither is
// used). The Rust oracle (tools/gleam-ast-oracle) writes the same bytes.
//
// Leaves (spans, strings, numbers, payload-free enums) build their JSON
// directly. Nodes (`enc_*`) run on the step trampoline of `step.mbt`: they
// take a continuation, enter a child only through `node`, `maybe` or
// `each`, and hand their object to the continuation through `give`.

///|
/// An object; `canonical` sorts the keys when it writes.
fn obj(fields : Array[(String, Json)]) -> Json {
  Json::object(Map::from_array(fields))
}

///|
fn num(n : Int32) -> Json {
  Json::number(n.to_double())
}

///|
/// A `u64` of the compiler, written with its exact digits (a `Double`
/// alone loses precision above 2^53).
fn num64(u : UInt64) -> Json {
  Json::number(u.to_double(), repr=u.to_string())
}

///|
fn str(s : String) -> Json {
  Json::string(s)
}

///|
fn[T] opt(o : T?, f : (T) -> Json) -> Json {
  match o {
    Some(v) => f(v)
    None => Json::null()
  }
}

///|
fn[T] list(xs : ArrayView[T], f : (T) -> Json) -> Json {
  Json::array(xs.iter().map(f).collect())
}

///|
fn arr(xs : ArrayView[Json]) -> Json {
  Json::array(xs.to_owned())
}

///|
/// The canonical text of an encoded value: keys in sorted (byte) order at
/// every level, no whitespace, serde_json's string escaping (`\"`, `\\`,
/// `\b`, `\f`, `\n`, `\r`, `\t`, other controls as `\u00xx`, everything
/// else raw). Map order is not relied on. Writes through the step
/// trampoline, so a value of any depth is written without recursion; the
/// builder is local to this call.
pub fn canonical(json : Json) -> String {
  let sb = StringBuilder()
  run(write_canonical(sb, json, () => Done(())))
  sb.to_string()
}

///|
/// Write one value, then continue with `k`. A continuation is never
/// called here: it is returned as `More(k)` for `run` to execute.
fn write_canonical(
  sb : StringBuilder,
  json : Json,
  k : () -> Step[Unit],
) -> Step[Unit] {
  match json {
    Null => {
      sb.write_string("null")
      More(k)
    }
    True => {
      sb.write_string("true")
      More(k)
    }
    False => {
      sb.write_string("false")
      More(k)
    }
    Number(d, repr~) => {
      // Byte offsets and small values fit a Double; a `u64` carries its
      // exact digits in `repr`.
      if repr is Some(digits) {
        sb.write_string(digits)
      } else if d == d.floor() && d.abs() < 9007199254740992.0 {
        sb.write_string(d.to_int64().to_string())
      } else {
        sb.write_string(d.to_string())
      }
      More(k)
    }
    String(s) => {
      write_json_string(sb, s)
      More(k)
    }
    Array(items) => {
      sb.write_char('[')
      write_items(sb, items[:], 0, () => {
        sb.write_char(']')
        More(k)
      })
    }
    Object(m) => {
      let keys = m.keys().collect()
      keys.sort_by(byte_order)
      sb.write_char('{')
      write_fields(sb, m, keys[:], 0, () => {
        sb.write_char('}')
        More(k)
      })
    }
  }
}

///|
fn write_items(
  sb : StringBuilder,
  items : ArrayView[Json],
  i : Int32,
  k : () -> Step[Unit],
) -> Step[Unit] {
  if i == items.length() {
    More(k)
  } else {
    if i > 0 {
      sb.write_char(',')
    }
    More(() => {
      write_canonical(sb, items[i], () => write_items(sb, items, i + 1, k))
    })
  }
}

///|
fn write_fields(
  sb : StringBuilder,
  m : Map[String, Json],
  keys : ArrayView[String],
  i : Int32,
  k : () -> Step[Unit],
) -> Step[Unit] {
  if i == keys.length() {
    More(k)
  } else {
    if i > 0 {
      sb.write_char(',')
    }
    write_json_string(sb, keys[i])
    sb.write_char(':')
    More(() => {
      write_canonical(sb, m.get(keys[i]).unwrap(), () => {
        write_fields(sb, m, keys, i + 1, k)
      })
    })
  }
}

///|
/// Keys compared code unit by code unit, as serde_json's `BTreeMap<String>`
/// compares bytes (the keys are ASCII). MoonBit's `String` `Compare`
/// orders by length first, so it is not used.
fn byte_order(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i = 0; i < n; i = i + 1 {
    let d = a.code_unit_at(i).to_int() - b.code_unit_at(i).to_int()
    if d != 0 {
      return d
    }
  }
  a.length() - b.length()
}

///|
fn write_json_string(sb : StringBuilder, s : String) -> Unit {
  let hex = "0123456789abcdef"
  sb.write_char('"')
  for i = 0; i < s.length(); i = i + 1 {
    let c = s.code_unit_at(i).to_int()
    if c == '"'.to_int() {
      sb.write_string("\\\"")
    } else if c == '\\'.to_int() {
      sb.write_string("\\\\")
    } else if c == 0x08 {
      sb.write_string("\\b")
    } else if c == 0x0C {
      sb.write_string("\\f")
    } else if c == 0x0A {
      sb.write_string("\\n")
    } else if c == 0x0D {
      sb.write_string("\\r")
    } else if c == 0x09 {
      sb.write_string("\\t")
    } else if c < 0x20 {
      sb.write_string("\\u00")
      sb.write_char(hex.code_unit_at(c / 16).to_int().unsafe_to_char())
      sb.write_char(hex.code_unit_at(c % 16).to_int().unsafe_to_char())
    } else {
      sb.write_char(c.unsafe_to_char())
    }
  }
  sb.write_char('"')
}

///|
/// Encode a source span as `start` and `end` byte offsets.
/// The offsets are written as given, including the compiler's `start..0` EOF spans.
pub fn encode_span(s : @span.SrcSpan) -> Json {
  obj([("start", num(s.start)), ("end", num(s.end))])
}

///|
fn spanned_string(s : SpannedString) -> Json {
  obj([("location", encode_span(s.location)), ("name", str(s.name))])
}

///|
fn documentation(d : Documentation) -> Json {
  obj([("start", num(d.start)), ("text", str(d.text))])
}

///|
fn external(e : External) -> Json {
  obj([
    ("module", str(e.module_)),
    ("function", str(e.function)),
    ("location", encode_span(e.location)),
  ])
}

///|
/// Encode public, private or internal visibility as a tagged JSON object.
pub fn encode_publicity(p : Publicity) -> Json {
  match p {
    Public => obj([("kind", str("public"))])
    Private => obj([("kind", str("private"))])
    Internal(attribute_location~) =>
      obj([
        ("kind", str("internal")),
        ("attribute_location", opt(attribute_location, encode_span)),
      ])
  }
}

///|
fn deprecation(d : Deprecation) -> Json {
  match d {
    NotDeprecated => obj([("kind", str("not_deprecated"))])
    Deprecated(message~) =>
      obj([("kind", str("deprecated")), ("message", str(message))])
  }
}

///|
fn assign_name(a : AssignName) -> Json {
  match a {
    Variable(name) => obj([("kind", str("variable")), ("name", str(name))])
    Discard(name) => obj([("kind", str("discard")), ("name", str(name))])
  }
}

///|
/// Encode a module with its trivia positions and parse-time warnings.
/// Use `canonical` to write the JSON in the oracle's key order.
/// Encoding uses no recursive calls and has no depth limit.
///
/// ```mbt check
/// test {
///   let p = @ast.Parsed::{
///     module_: { definitions: [][:], },
///     extra: @ast.ModuleExtra::empty(),
///     warnings: [][:],
///   }
///   assert_eq(@ast.decode_parsed(@ast.encode_parsed(p)), p)
/// }
/// ```
pub fn encode_parsed(p : Parsed) -> Json {
  run(enc_parsed(p, j => Done(j)))
}

///|
fn[R] enc_parsed(p : Parsed, k : (Json) -> Step[R]) -> Step[R] {
  node(p.module_, enc_module, module_ => {
    give(
      k,
      obj([
        ("module", module_),
        ("extra", encode_extra(p.extra)),
        ("warnings", list(p.warnings, encode_warning)),
      ]),
    )
  })
}

///|
/// Encode a module as a JSON object with its definitions in source order.
pub fn encode_module(m : Module) -> Json {
  run(enc_module(m, j => Done(j)))
}

///|
fn[R] enc_module(m : Module, k : (Json) -> Step[R]) -> Step[R] {
  each(m.definitions, enc_targeted_definition, definitions => {
    give(k, obj([("definitions", arr(definitions))]))
  })
}

///|
/// Encode a definition with its optional target.
/// An absent target is written as `null`.
pub fn encode_targeted_definition(d : TargetedDefinition) -> Json {
  run(enc_targeted_definition(d, j => Done(j)))
}

///|
fn[R] enc_targeted_definition(
  d : TargetedDefinition,
  k : (Json) -> Step[R],
) -> Step[R] {
  node(d.definition, enc_definition, definition => {
    give(
      k,
      obj([
        ("definition", definition),
        ("target", opt(d.target, t => str(t.name()))),
      ]),
    )
  })
}

///|
/// Encode a definition as a tagged JSON object.
pub fn encode_definition(d : Definition) -> Json {
  run(enc_definition(d, j => Done(j)))
}

///|
fn[R] enc_definition(d : Definition, k : (Json) -> Step[R]) -> Step[R] {
  match d {
    Function(f) => enc_function(f, "function", k)
    TypeAlias(t) =>
      node(t.type_ast, enc_type_ast, type_ast => {
        give(
          k,
          obj([
            ("kind", str("type_alias")),
            ("location", encode_span(t.location)),
            ("alias", str(t.alias_)),
            ("name_location", encode_span(t.name_location)),
            ("parameters", list(t.parameters, spanned_string)),
            ("type_ast", type_ast),
            ("publicity", encode_publicity(t.publicity)),
            ("documentation", opt(t.documentation, documentation)),
            ("deprecation", deprecation(t.deprecation)),
          ]),
        )
      })
    CustomType(c) =>
      each(c.constructors, enc_record_constructor, constructors => {
        give(
          k,
          obj([
            ("kind", str("custom_type")),
            ("location", encode_span(c.location)),
            ("end_position", num(c.end_position)),
            ("name", str(c.name)),
            ("name_location", encode_span(c.name_location)),
            ("publicity", encode_publicity(c.publicity)),
            ("constructors", arr(constructors)),
            ("documentation", opt(c.documentation, documentation)),
            ("deprecation", deprecation(c.deprecation)),
            ("opaque", Json::boolean(c.opaque_)),
            ("parameters", list(c.parameters, spanned_string)),
            ("external_erlang", opt(c.external_erlang, external)),
            ("external_javascript", opt(c.external_javascript, external)),
          ]),
        )
      })
    Import(i) =>
      give(
        k,
        obj([
          ("kind", str("import")),
          ("documentation", opt(i.documentation, str)),
          ("location", encode_span(i.location)),
          ("module_location", encode_span(i.module_location)),
          ("module", str(i.module_)),
          (
            "as_name",
            opt(i.as_name, a => {
              obj([
                ("name", assign_name(a.name)),
                ("location", encode_span(a.location)),
              ])
            }),
          ),
          ("unqualified_values", list(i.unqualified_values, unqualified_import)),
          ("unqualified_types", list(i.unqualified_types, unqualified_import)),
        ]),
      )
    ModuleConstant(c) =>
      maybe(c.annotation, enc_type_ast, annotation => {
        node(c.value, enc_constant, value => {
          give(
            k,
            obj([
              ("kind", str("module_constant")),
              ("documentation", opt(c.documentation, documentation)),
              ("location", encode_span(c.location)),
              ("publicity", encode_publicity(c.publicity)),
              ("name", str(c.name)),
              ("name_location", encode_span(c.name_location)),
              ("annotation", annotation),
              ("value", value),
              ("deprecation", deprecation(c.deprecation)),
            ]),
          )
        })
      })
  }
}

///|
fn[R] enc_function(
  f : Function,
  kind : String,
  k : (Json) -> Step[R],
) -> Step[R] {
  each(f.arguments, enc_arg, arguments => {
    each(f.body, enc_statement, body => {
      maybe(f.return_annotation, enc_type_ast, return_annotation => {
        give(
          k,
          obj([
            ("kind", str(kind)),
            ("location", encode_span(f.location)),
            ("body_start", opt(f.body_start, num)),
            ("end_position", num(f.end_position)),
            ("name", opt(f.name, spanned_string)),
            ("arguments", arr(arguments)),
            ("body", arr(body)),
            ("publicity", encode_publicity(f.publicity)),
            ("deprecation", deprecation(f.deprecation)),
            ("return_annotation", return_annotation),
            ("documentation", opt(f.documentation, documentation)),
            ("external_erlang", opt(f.external_erlang, external)),
            ("external_javascript", opt(f.external_javascript, external)),
          ]),
        )
      })
    })
  })
}

///|
fn unqualified_import(u : UnqualifiedImport) -> Json {
  obj([
    ("location", encode_span(u.location)),
    ("name", str(u.name)),
    ("name_position", num(u.name_position)),
    ("as_name", opt(u.as_name, str)),
  ])
}

///|
fn[R] enc_record_constructor(
  r : RecordConstructor,
  k : (Json) -> Step[R],
) -> Step[R] {
  each(r.arguments, enc_record_constructor_arg, arguments => {
    give(
      k,
      obj([
        ("location", encode_span(r.location)),
        ("name_location", encode_span(r.name_location)),
        ("name", str(r.name)),
        ("arguments", arr(arguments)),
        ("documentation", opt(r.documentation, documentation)),
        ("deprecation", deprecation(r.deprecation)),
      ]),
    )
  })
}

///|
fn[R] enc_record_constructor_arg(
  a : RecordConstructorArg,
  k : (Json) -> Step[R],
) -> Step[R] {
  node(a.ast, enc_type_ast, ast => {
    give(
      k,
      obj([
        ("label", opt(a.label, spanned_string)),
        ("ast", ast),
        ("location", encode_span(a.location)),
        ("doc", opt(a.doc, documentation)),
      ]),
    )
  })
}

///|
fn[R] enc_arg(a : Arg, k : (Json) -> Step[R]) -> Step[R] {
  maybe(a.annotation, enc_type_ast, annotation => {
    give(
      k,
      obj([
        ("names", arg_names(a.names)),
        ("location", encode_span(a.location)),
        ("annotation", annotation),
      ]),
    )
  })
}

///|
fn arg_names(n : ArgNames) -> Json {
  match n {
    Discard(name~, location~) =>
      obj([
        ("kind", str("discard")),
        ("name", str(name)),
        ("location", encode_span(location)),
      ])
    LabelledDiscard(label~, label_location~, name~, name_location~) =>
      obj([
        ("kind", str("labelled_discard")),
        ("label", str(label)),
        ("label_location", encode_span(label_location)),
        ("name", str(name)),
        ("name_location", encode_span(name_location)),
      ])
    Named(name~, location~) =>
      obj([
        ("kind", str("named")),
        ("name", str(name)),
        ("location", encode_span(location)),
      ])
    NamedLabelled(label~, label_location~, name~, name_location~) =>
      obj([
        ("kind", str("named_labelled")),
        ("label", str(label)),
        ("label_location", encode_span(label_location)),
        ("name", str(name)),
        ("name_location", encode_span(name_location)),
      ])
  }
}

///|
/// Encode a type annotation as a tagged JSON object.
pub fn encode_type_ast(t : TypeAst) -> Json {
  run(enc_type_ast(t, j => Done(j)))
}

///|
fn[R] enc_type_ast(t : TypeAst, k : (Json) -> Step[R]) -> Step[R] {
  match t {
    Constructor(c) =>
      each(c.arguments, enc_type_ast, arguments => {
        give(
          k,
          obj([
            ("kind", str("constructor")),
            ("location", encode_span(c.location)),
            ("name", type_ast_constructor_name(c.name)),
            ("arguments", arr(arguments)),
            ("start_parentheses", opt(c.start_parentheses, num)),
          ]),
        )
      })
    Fn(f) =>
      each(f.arguments, enc_type_ast, arguments => {
        node(f.return_, enc_type_ast, return_ => {
          give(
            k,
            obj([
              ("kind", str("fn")),
              ("location", encode_span(f.location)),
              ("arguments", arr(arguments)),
              ("return_", return_),
            ]),
          )
        })
      })
    Var(v) =>
      give(
        k,
        obj([
          ("kind", str("var")),
          ("location", encode_span(v.location)),
          ("name", str(v.name)),
        ]),
      )
    Tuple(t) =>
      each(t.elements, enc_type_ast, elements => {
        give(
          k,
          obj([
            ("kind", str("tuple")),
            ("location", encode_span(t.location)),
            ("elements", arr(elements)),
          ]),
        )
      })
    Hole(h) =>
      give(
        k,
        obj([
          ("kind", str("hole")),
          ("location", encode_span(h.location)),
          ("name", str(h.name)),
        ]),
      )
  }
}

///|
fn type_ast_constructor_name(n : TypeAstConstructorName) -> Json {
  match n {
    Qualified(module_~, module_location~, dot_location~, name~) =>
      obj([
        ("kind", str("qualified")),
        ("module", str(module_)),
        ("module_location", encode_span(module_location)),
        ("dot_location", num(dot_location)),
        ("name", opt(name, spanned_string)),
      ])
    Unqualified(name~, location~) =>
      obj([
        ("kind", str("unqualified")),
        ("name", str(name)),
        ("location", encode_span(location)),
      ])
  }
}

///|
/// Encode a statement as a tagged JSON object.
pub fn encode_statement(s : Statement) -> Json {
  run(enc_statement(s, j => Done(j)))
}

///|
fn[R] enc_statement(s : Statement, k : (Json) -> Step[R]) -> Step[R] {
  match s {
    Expression(e) =>
      node(e, enc_expr, expression => {
        give(k, obj([("kind", str("expression")), ("expression", expression)]))
      })
    Assignment(a) =>
      node(a.value, enc_expr, value => {
        node(a.pattern, enc_pattern, pattern => {
          node(a.kind, enc_assignment_kind, assignment_kind => {
            maybe(a.annotation, enc_type_ast, annotation => {
              give(
                k,
                obj([
                  ("kind", str("assignment")),
                  ("location", encode_span(a.location)),
                  ("value", value),
                  ("pattern", pattern),
                  ("assignment_kind", assignment_kind),
                  ("annotation", annotation),
                ]),
              )
            })
          })
        })
      })
    Use(u) =>
      node(u.call, enc_expr, call => {
        each(u.assignments, enc_use_assignment, assignments => {
          give(
            k,
            obj([
              ("kind", str("use")),
              ("call", call),
              ("location", encode_span(u.location)),
              (
                "right_hand_side_location",
                encode_span(u.right_hand_side_location),
              ),
              ("assignments_location", encode_span(u.assignments_location)),
              ("assignments", arr(assignments)),
            ]),
          )
        })
      })
    Assert(a) =>
      node(a.value, enc_expr, value => {
        maybe(a.message, enc_expr, message => {
          give(
            k,
            obj([
              ("kind", str("assert")),
              ("location", encode_span(a.location)),
              ("value", value),
              ("message", message),
            ]),
          )
        })
      })
  }
}

///|
/// `Assignment.kind` is written under `assignment_kind`, because `kind`
/// names the statement. The `Assert` arm's message is an expression, so
/// this is a node: the statement encoder enters it through `node`.
fn[R] enc_assignment_kind(a : AssignmentKind, k : (Json) -> Step[R]) -> Step[R] {
  match a {
    Let => give(k, obj([("kind", str("let"))]))
    Generated => give(k, obj([("kind", str("generated"))]))
    Assert(location~, assert_keyword_start~, message~) =>
      maybe(message, enc_expr, message => {
        give(
          k,
          obj([
            ("kind", str("assert")),
            ("location", encode_span(location)),
            ("assert_keyword_start", num(assert_keyword_start)),
            ("message", message),
          ]),
        )
      })
  }
}

///|
fn[R] enc_use_assignment(u : UseAssignment, k : (Json) -> Step[R]) -> Step[R] {
  node(u.pattern, enc_pattern, pattern => {
    maybe(u.annotation, enc_type_ast, annotation => {
      give(
        k,
        obj([
          ("location", encode_span(u.location)),
          ("pattern", pattern),
          ("annotation", annotation),
        ]),
      )
    })
  })
}

///|
fn[A, R] enc_call_arg(
  a : CallArg[A],
  f : (A, (Json) -> Step[R]) -> Step[R],
  k : (Json) -> Step[R],
) -> Step[R] {
  node(a.value, f, value => {
    give(
      k,
      obj([
        ("label", opt(a.label, str)),
        ("location", encode_span(a.location)),
        ("value", value),
        ("implicit", opt(a.implicit, i => str(i.name()))),
      ]),
    )
  })
}

///|
fn[A, R] enc_record_being_updated(
  r : RecordBeingUpdated[A],
  f : (A, (Json) -> Step[R]) -> Step[R],
  k : (Json) -> Step[R],
) -> Step[R] {
  node(r.base, f, base => {
    give(k, obj([("base", base), ("location", encode_span(r.location))]))
  })
}

///|
fn[A, R] enc_record_update_arg(
  a : RecordUpdateArg[A],
  f : (A, (Json) -> Step[R]) -> Step[R],
  k : (Json) -> Step[R],
) -> Step[R] {
  node(a.value, f, value => {
    give(
      k,
      obj([
        ("label", str(a.label)),
        ("location", encode_span(a.location)),
        ("value", value),
      ]),
    )
  })
}

///|
fn[V, R] enc_bit_array_segment(
  s : BitArraySegment[V],
  f : (V, (Json) -> Step[R]) -> Step[R],
  k : (Json) -> Step[R],
) -> Step[R] {
  node(s.value, f, value => {
    each(s.options, (o, k2) => enc_bit_array_option(o, f, k2), options => {
      give(
        k,
        obj([
          ("location", encode_span(s.location)),
          ("value", value),
          ("options", arr(options)),
        ]),
      )
    })
  })
}

///|
fn[V, R] enc_bit_array_option(
  o : BitArrayOption[V],
  f : (V, (Json) -> Step[R]) -> Step[R],
  k : (Json) -> Step[R],
) -> Step[R] {
  let simple = (kind : String, location : @span.SrcSpan) => {
    give(k, obj([("kind", str(kind)), ("location", encode_span(location))]))
  }
  match o {
    Bytes(location~) => simple("bytes", location)
    Int(location~) => simple("int", location)
    Float(location~) => simple("float", location)
    Bits(location~) => simple("bits", location)
    Utf8(location~) => simple("utf8", location)
    Utf16(location~) => simple("utf16", location)
    Utf32(location~) => simple("utf32", location)
    Utf8Codepoint(location~) => simple("utf8_codepoint", location)
    Utf16Codepoint(location~) => simple("utf16_codepoint", location)
    Utf32Codepoint(location~) => simple("utf32_codepoint", location)
    Signed(location~) => simple("signed", location)
    Unsigned(location~) => simple("unsigned", location)
    Big(location~) => simple("big", location)
    Little(location~) => simple("little", location)
    Native(location~) => simple("native", location)
    Size(location~, value~, short_form~) =>
      node(value, f, value => {
        give(
          k,
          obj([
            ("kind", str("size")),
            ("location", encode_span(location)),
            ("value", value),
            ("short_form", Json::boolean(short_form)),
          ]),
        )
      })
    Unit(location~, value~) =>
      give(
        k,
        obj([
          ("kind", str("unit")),
          ("location", encode_span(location)),
          ("value", num(value)),
        ]),
      )
  }
}

///|
fn todo_kind(k : TodoKind) -> Json {
  match k {
    Keyword => obj([("kind", str("keyword"))])
    EmptyFunction(function_location~) =>
      obj([
        ("kind", str("empty_function")),
        ("function_location", encode_span(function_location)),
      ])
    IncompleteUse => obj([("kind", str("incomplete_use"))])
    EmptyBlock => obj([("kind", str("empty_block"))])
  }
}

///|
fn function_literal_kind(k : FunctionLiteralKind) -> Json {
  match k {
    Capture(hole~) =>
      obj([("kind", str("capture")), ("hole", encode_span(hole))])
    Anonymous(head~) =>
      obj([("kind", str("anonymous")), ("head", encode_span(head))])
    Use(location~) =>
      obj([("kind", str("use")), ("location", encode_span(location))])
  }
}

///|
/// Encode an expression as a tagged JSON object.
/// Write only a float's lexeme; the decoder derives its numeric value.
///
/// ```mbt check
/// test {
///   let value : @ast.Expr = Var(location=@span.SrcSpan::new(0, 1), name="x")
///   assert_eq(@ast.decode_expr(@ast.encode_expr(value)), value)
/// }
/// ```
pub fn encode_expr(e : Expr) -> Json {
  run(enc_expr(e, j => Done(j)))
}

///|
fn[R] enc_expr(e : Expr, k : (Json) -> Step[R]) -> Step[R] {
  match e {
    Int(location~, value~, int_value~) =>
      give(
        k,
        obj([
          ("kind", str("int")),
          ("location", encode_span(location)),
          ("value", str(value)),
          ("int_value", str(int_value.to_string())),
        ]),
      )
    Float(location~, value~, ..) =>
      give(
        k,
        obj([
          ("kind", str("float")),
          ("location", encode_span(location)),
          ("value", str(value)),
        ]),
      )
    String(location~, value~) =>
      give(
        k,
        obj([
          ("kind", str("string")),
          ("location", encode_span(location)),
          ("value", str(value)),
        ]),
      )
    Block(location~, statements~) =>
      each(statements, enc_statement, statements => {
        give(
          k,
          obj([
            ("kind", str("block")),
            ("location", encode_span(location)),
            ("statements", arr(statements)),
          ]),
        )
      })
    Var(location~, name~) =>
      give(
        k,
        obj([
          ("kind", str("var")),
          ("location", encode_span(location)),
          ("name", str(name)),
        ]),
      )
    Fn(
      location~,
      kind~,
      end_of_head_byte_index~,
      arguments~,
      body~,
      return_annotation~
    ) =>
      each(arguments, enc_arg, arguments => {
        each(body, enc_statement, body => {
          maybe(return_annotation, enc_type_ast, return_annotation => {
            give(
              k,
              obj([
                ("kind", str("fn")),
                ("location", encode_span(location)),
                ("fn_kind", function_literal_kind(kind)),
                ("end_of_head_byte_index", num(end_of_head_byte_index)),
                ("arguments", arr(arguments)),
                ("body", arr(body)),
                ("return_annotation", return_annotation),
              ]),
            )
          })
        })
      })
    List(location~, elements~, tail~) =>
      each(elements, enc_expr, elements => {
        maybe(tail, enc_expr, tail => {
          give(
            k,
            obj([
              ("kind", str("list")),
              ("location", encode_span(location)),
              ("elements", arr(elements)),
              ("tail", tail),
            ]),
          )
        })
      })
    Call(location~, fun~, arguments~, open_parenthesis~) =>
      node(fun, enc_expr, fun => {
        each(arguments, (a, k2) => enc_call_arg(a, enc_expr, k2), arguments => {
          give(
            k,
            obj([
              ("kind", str("call")),
              ("location", encode_span(location)),
              ("fun", fun),
              ("arguments", arr(arguments)),
              ("open_parenthesis", num(open_parenthesis)),
            ]),
          )
        })
      })
    BinOp(location~, operator~, operator_start~, left~, right~) =>
      node(left, enc_expr, left => {
        node(right, enc_expr, right => {
          give(
            k,
            obj([
              ("kind", str("bin_op")),
              ("location", encode_span(location)),
              ("operator", str(operator.name())),
              ("operator_start", num(operator_start)),
              ("left", left),
              ("right", right),
            ]),
          )
        })
      })
    Pipeline(expressions~) =>
      each(expressions, enc_expr, expressions => {
        give(
          k,
          obj([("kind", str("pipeline")), ("expressions", arr(expressions))]),
        )
      })
    Case(location~, subjects~, clauses~) =>
      each(subjects, enc_expr, subjects => {
        maybe(
          clauses,
          (cs, k2) => each(cs, enc_clause, js => give(k2, arr(js))),
          clauses => {
            give(
              k,
              obj([
                ("kind", str("case")),
                ("location", encode_span(location)),
                ("subjects", arr(subjects)),
                ("clauses", clauses),
              ]),
            )
          },
        )
      })
    FieldAccess(location~, label_location~, label~, container~) =>
      node(container, enc_expr, container => {
        give(
          k,
          obj([
            ("kind", str("field_access")),
            ("location", encode_span(location)),
            ("label_location", encode_span(label_location)),
            ("label", str(label)),
            ("container", container),
          ]),
        )
      })
    Tuple(location~, elements~) =>
      each(elements, enc_expr, elements => {
        give(
          k,
          obj([
            ("kind", str("tuple")),
            ("location", encode_span(location)),
            ("elements", arr(elements)),
          ]),
        )
      })
    TupleIndex(location~, index~, tuple~) =>
      node(tuple, enc_expr, tuple => {
        give(
          k,
          obj([
            ("kind", str("tuple_index")),
            ("location", encode_span(location)),
            ("index", num64(index)),
            ("tuple", tuple),
          ]),
        )
      })
    Todo(kind~, location~, message~) =>
      maybe(message, enc_expr, message => {
        give(
          k,
          obj([
            ("kind", str("todo")),
            ("todo_kind", todo_kind(kind)),
            ("location", encode_span(location)),
            ("message", message),
          ]),
        )
      })
    Panic(location~, message~) =>
      maybe(message, enc_expr, message => {
        give(
          k,
          obj([
            ("kind", str("panic")),
            ("location", encode_span(location)),
            ("message", message),
          ]),
        )
      })
    Echo(location~, keyword_end~, expression~, message~) =>
      maybe(expression, enc_expr, expression => {
        maybe(message, enc_expr, message => {
          give(
            k,
            obj([
              ("kind", str("echo")),
              ("location", encode_span(location)),
              ("keyword_end", num(keyword_end)),
              ("expression", expression),
              ("message", message),
            ]),
          )
        })
      })
    BitArray(location~, segments~) =>
      each(segments, (s, k2) => enc_bit_array_segment(s, enc_expr, k2), segments => {
        give(
          k,
          obj([
            ("kind", str("bit_array")),
            ("location", encode_span(location)),
            ("segments", arr(segments)),
          ]),
        )
      })
    RecordUpdate(location~, spread_start~, constructor_~, record~, arguments~) =>
      node(constructor_, enc_expr, constructor_ => {
        enc_record_being_updated(record, enc_expr, record => {
          each(arguments, (a, k2) => enc_record_update_arg(a, enc_expr, k2), arguments => {
            give(
              k,
              obj([
                ("kind", str("record_update")),
                ("location", encode_span(location)),
                ("spread_start", num(spread_start)),
                ("constructor", constructor_),
                ("record", record),
                ("arguments", arr(arguments)),
              ]),
            )
          })
        })
      })
    NegateBool(location~, value~) =>
      node(value, enc_expr, value => {
        give(
          k,
          obj([
            ("kind", str("negate_bool")),
            ("location", encode_span(location)),
            ("value", value),
          ]),
        )
      })
    NegateInt(location~, value~) =>
      node(value, enc_expr, value => {
        give(
          k,
          obj([
            ("kind", str("negate_int")),
            ("location", encode_span(location)),
            ("value", value),
          ]),
        )
      })
  }
}

///|
fn[R] enc_clause(c : Clause, k : (Json) -> Step[R]) -> Step[R] {
  each(c.pattern, enc_pattern, pattern => {
    each(
      c.alternative_patterns,
      (ps, k2) => each(ps, enc_pattern, js => give(k2, arr(js))),
      alternative_patterns => {
        maybe(c.guard_, enc_clause_guard, guard_ => {
          node(c.then, enc_expr, then => {
            give(
              k,
              obj([
                ("location", encode_span(c.location)),
                ("pattern", arr(pattern)),
                ("alternative_patterns", arr(alternative_patterns)),
                ("guard", guard_),
                ("then", then),
              ]),
            )
          })
        })
      },
    )
  })
}

///|
/// Encode a clause guard as a tagged JSON object.
/// Tuple and field indexes keep all unsigned 64-bit digits.
pub fn encode_clause_guard(g : ClauseGuard) -> Json {
  run(enc_clause_guard(g, j => Done(j)))
}

///|
fn[R] enc_clause_guard(g : ClauseGuard, k : (Json) -> Step[R]) -> Step[R] {
  match g {
    Block(location~, value~) =>
      node(value, enc_clause_guard, value => {
        give(
          k,
          obj([
            ("kind", str("block")),
            ("location", encode_span(location)),
            ("value", value),
          ]),
        )
      })
    BinaryOperator(location~, operator~, operator_start~, left~, right~) =>
      node(left, enc_clause_guard, left => {
        node(right, enc_clause_guard, right => {
          give(
            k,
            obj([
              ("kind", str("binary_operator")),
              ("location", encode_span(location)),
              ("operator", str(operator.name())),
              ("operator_start", num(operator_start)),
              ("left", left),
              ("right", right),
            ]),
          )
        })
      })
    Not(location~, expression~) =>
      node(expression, enc_clause_guard, expression => {
        give(
          k,
          obj([
            ("kind", str("not")),
            ("location", encode_span(location)),
            ("expression", expression),
          ]),
        )
      })
    Var(location~, name~) =>
      give(
        k,
        obj([
          ("kind", str("var")),
          ("location", encode_span(location)),
          ("name", str(name)),
        ]),
      )
    TupleIndex(location~, index~, tuple~) =>
      node(tuple, enc_clause_guard, tuple => {
        give(
          k,
          obj([
            ("kind", str("tuple_index")),
            ("location", encode_span(location)),
            ("index", num64(index)),
            ("tuple", tuple),
          ]),
        )
      })
    FieldAccess(label_location~, index~, label~, container~) =>
      node(container, enc_clause_guard, container => {
        give(
          k,
          obj([
            ("kind", str("field_access")),
            ("label_location", encode_span(label_location)),
            ("index", opt(index, num64)),
            ("label", str(label)),
            ("container", container),
          ]),
        )
      })
    Constant(c) =>
      node(c, enc_constant, constant => {
        give(k, obj([("kind", str("constant")), ("constant", constant)]))
      })
  }
}

///|
/// Encode a pattern as a tagged JSON object.
pub fn encode_pattern(p : Pattern) -> Json {
  run(enc_pattern(p, j => Done(j)))
}

///|
fn[R] enc_pattern(p : Pattern, k : (Json) -> Step[R]) -> Step[R] {
  match p {
    Int(location~, value~, int_value~) =>
      give(
        k,
        obj([
          ("kind", str("int")),
          ("location", encode_span(location)),
          ("value", str(value)),
          ("int_value", str(int_value.to_string())),
        ]),
      )
    Float(location~, value~, ..) =>
      give(
        k,
        obj([
          ("kind", str("float")),
          ("location", encode_span(location)),
          ("value", str(value)),
        ]),
      )
    String(location~, value~) =>
      give(
        k,
        obj([
          ("kind", str("string")),
          ("location", encode_span(location)),
          ("value", str(value)),
        ]),
      )
    Variable(location~, name~) =>
      give(
        k,
        obj([
          ("kind", str("variable")),
          ("location", encode_span(location)),
          ("name", str(name)),
        ]),
      )
    BitArraySize(s) =>
      node(s, enc_bit_array_size, size => {
        give(k, obj([("kind", str("bit_array_size")), ("size", size)]))
      })
    Assign(name~, location~, pattern~) =>
      node(pattern, enc_pattern, pattern => {
        give(
          k,
          obj([
            ("kind", str("assign")),
            ("name", str(name)),
            ("location", encode_span(location)),
            ("pattern", pattern),
          ]),
        )
      })
    Discard(name~, location~) =>
      give(
        k,
        obj([
          ("kind", str("discard")),
          ("name", str(name)),
          ("location", encode_span(location)),
        ]),
      )
    List(location~, elements~, tail~) =>
      each(elements, enc_pattern, elements => {
        maybe(
          tail,
          (t, k2) => {
            node(t.pattern, enc_pattern, pattern => {
              give(
                k2,
                obj([
                  ("location", encode_span(t.location)),
                  ("pattern", pattern),
                ]),
              )
            })
          },
          tail => {
            give(
              k,
              obj([
                ("kind", str("list")),
                ("location", encode_span(location)),
                ("elements", arr(elements)),
                ("tail", tail),
              ]),
            )
          },
        )
      })
    Constructor(location~, name_location~, name~, arguments~, module_~, spread~) =>
      each(arguments, (a, k2) => enc_call_arg(a, enc_pattern, k2), arguments => {
        give(
          k,
          obj([
            ("kind", str("constructor")),
            ("location", encode_span(location)),
            ("name_location", encode_span(name_location)),
            ("name", str(name)),
            ("arguments", arr(arguments)),
            ("module", opt(module_, spanned_string)),
            ("spread", opt(spread, encode_span)),
          ]),
        )
      })
    Tuple(location~, elements~) =>
      each(elements, enc_pattern, elements => {
        give(
          k,
          obj([
            ("kind", str("tuple")),
            ("location", encode_span(location)),
            ("elements", arr(elements)),
          ]),
        )
      })
    BitArray(location~, segments~) =>
      each(segments, (s, k2) => enc_bit_array_segment(s, enc_pattern, k2), segments => {
        give(
          k,
          obj([
            ("kind", str("bit_array")),
            ("location", encode_span(location)),
            ("segments", arr(segments)),
          ]),
        )
      })
    StringPrefix(
      location~,
      left_location~,
      left_side_assignment~,
      right_location~,
      left_side_string~,
      right_side_assignment~
    ) =>
      give(
        k,
        obj([
          ("kind", str("string_prefix")),
          ("location", encode_span(location)),
          ("left_location", encode_span(left_location)),
          (
            "left_side_assignment",
            opt(left_side_assignment, a => {
              obj([
                ("name", str(a.name)),
                ("name_start_position", num(a.name_start_position)),
                ("location", encode_span(a.location)),
              ])
            }),
          ),
          ("right_location", encode_span(right_location)),
          ("left_side_string", str(left_side_string)),
          ("right_side_assignment", assign_name(right_side_assignment)),
        ]),
      )
  }
}

///|
fn[R] enc_bit_array_size(s : BitArraySize, k : (Json) -> Step[R]) -> Step[R] {
  match s {
    Int(location~, value~, int_value~) =>
      give(
        k,
        obj([
          ("kind", str("int")),
          ("location", encode_span(location)),
          ("value", str(value)),
          ("int_value", str(int_value.to_string())),
        ]),
      )
    Variable(location~, name~) =>
      give(
        k,
        obj([
          ("kind", str("variable")),
          ("location", encode_span(location)),
          ("name", str(name)),
        ]),
      )
    BinaryOperator(location~, operator~, left~, right~) =>
      node(left, enc_bit_array_size, left => {
        node(right, enc_bit_array_size, right => {
          give(
            k,
            obj([
              ("kind", str("binary_operator")),
              ("location", encode_span(location)),
              ("operator", str(operator.name())),
              ("left", left),
              ("right", right),
            ]),
          )
        })
      })
    Block(location~, inner~) =>
      node(inner, enc_bit_array_size, inner => {
        give(
          k,
          obj([
            ("kind", str("block")),
            ("location", encode_span(location)),
            ("inner", inner),
          ]),
        )
      })
  }
}

///|
/// Encode a constant as a tagged JSON object.
pub fn encode_constant(c : Constant) -> Json {
  run(enc_constant(c, j => Done(j)))
}

///|
fn[R] enc_constant(c : Constant, k : (Json) -> Step[R]) -> Step[R] {
  match c {
    Int(location~, value~, int_value~) =>
      give(
        k,
        obj([
          ("kind", str("int")),
          ("location", encode_span(location)),
          ("value", str(value)),
          ("int_value", str(int_value.to_string())),
        ]),
      )
    Float(location~, value~, ..) =>
      give(
        k,
        obj([
          ("kind", str("float")),
          ("location", encode_span(location)),
          ("value", str(value)),
        ]),
      )
    String(location~, value~) =>
      give(
        k,
        obj([
          ("kind", str("string")),
          ("location", encode_span(location)),
          ("value", str(value)),
        ]),
      )
    Tuple(location~, elements~) =>
      each(elements, enc_constant, elements => {
        give(
          k,
          obj([
            ("kind", str("tuple")),
            ("location", encode_span(location)),
            ("elements", arr(elements)),
          ]),
        )
      })
    List(location~, elements~, tail~) =>
      each(elements, enc_constant, elements => {
        maybe(tail, enc_constant, tail => {
          give(
            k,
            obj([
              ("kind", str("list")),
              ("location", encode_span(location)),
              ("elements", arr(elements)),
              ("tail", tail),
            ]),
          )
        })
      })
    Record(location~, arguments_start_position~, module_~, name~, arguments~) =>
      maybe(
        arguments,
        (xs, k2) => {
          each(xs, (a, k3) => enc_call_arg(a, enc_constant, k3), js => {
            give(k2, arr(js))
          })
        },
        arguments => {
          give(
            k,
            obj([
              ("kind", str("record")),
              ("location", encode_span(location)),
              ("arguments_start_position", num(arguments_start_position)),
              ("module", opt(module_, spanned_string)),
              ("name", str(name)),
              ("arguments", arguments),
            ]),
          )
        },
      )
    RecordUpdate(
      location~,
      constructor_location~,
      module_~,
      name~,
      record~,
      arguments~
    ) =>
      enc_record_being_updated(record, enc_constant, record => {
        each(arguments, (a, k2) => enc_record_update_arg(a, enc_constant, k2), arguments => {
          give(
            k,
            obj([
              ("kind", str("record_update")),
              ("location", encode_span(location)),
              ("constructor_location", encode_span(constructor_location)),
              ("module", opt(module_, spanned_string)),
              ("name", str(name)),
              ("record", record),
              ("arguments", arr(arguments)),
            ]),
          )
        })
      })
    BitArray(location~, segments~) =>
      each(segments, (s, k2) => enc_bit_array_segment(s, enc_constant, k2), segments => {
        give(
          k,
          obj([
            ("kind", str("bit_array")),
            ("location", encode_span(location)),
            ("segments", arr(segments)),
          ]),
        )
      })
    Var(location~, module_~, name~) =>
      give(
        k,
        obj([
          ("kind", str("var")),
          ("location", encode_span(location)),
          ("module", opt(module_, spanned_string)),
          ("name", str(name)),
        ]),
      )
    BinaryOperator(location~, operator_start~, operator~, left~, right~) =>
      node(left, enc_constant, left => {
        node(right, enc_constant, right => {
          give(
            k,
            obj([
              ("kind", str("binary_operator")),
              ("location", encode_span(location)),
              ("operator_start", num(operator_start)),
              ("operator", str(operator.name())),
              ("left", left),
              ("right", right),
            ]),
          )
        })
      })
    Todo(location~, message~) =>
      maybe(message, enc_constant, message => {
        give(
          k,
          obj([
            ("kind", str("todo")),
            ("location", encode_span(location)),
            ("message", message),
          ]),
        )
      })
  }
}

///|
/// Encode comment spans, line offsets and trailing comma offsets.
pub fn encode_extra(x : ModuleExtra) -> Json {
  obj([
    ("module_comments", list(x.module_comments, encode_span)),
    ("doc_comments", list(x.doc_comments, encode_span)),
    ("comments", list(x.comments, encode_span)),
    ("empty_lines", list(x.empty_lines, num)),
    ("new_lines", list(x.new_lines, num)),
    ("trailing_commas", list(x.trailing_commas, num)),
  ])
}

///|
/// Encode a parse-time warning as a tagged JSON object.
pub fn encode_warning(w : Warning) -> Json {
  let simple = (kind : String, location : @span.SrcSpan) => {
    obj([("kind", str(kind)), ("location", encode_span(location))])
  }
  match w {
    DeprecatedListPrepend(location~) =>
      simple("deprecated_list_prepend", location)
    DeprecatedListPattern(location~) =>
      simple("deprecated_list_pattern", location)
    DeprecatedListCatchAllPattern(location~) =>
      simple("deprecated_list_catch_all_pattern", location)
    DeprecatedListSpreadAsVariablePattern(location~, name~) =>
      obj([
        ("kind", str("deprecated_list_spread_as_variable_pattern")),
        ("location", encode_span(location)),
        ("name", str(name)),
      ])
    DeprecatedRecordSpreadPattern(location~) =>
      simple("deprecated_record_spread_pattern", location)
    DeprecatedEmptyClauseGuard(location~) =>
      simple("deprecated_empty_clause_guard", location)
    DeprecatedTargetShorthand(target~, location~) =>
      obj([
        ("kind", str("deprecated_target_shorthand")),
        ("target", str(target.name())),
        ("location", encode_span(location)),
      ])
    DetachedDocComment(location~) => simple("detached_doc_comment", location)
  }
}
