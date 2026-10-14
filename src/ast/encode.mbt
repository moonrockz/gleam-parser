// Canonical JSON for the AST: the schema of docs/ast-json.md. `canonical`
// writes objects with their keys in code-unit order (MoonBit's `Map` keeps
// insertion order and its `String` compare is length-first, so neither is
// used). The Rust oracle (tools/gleam-ast-oracle) writes the same bytes.

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
/// The canonical text of an encoded value: keys in sorted (byte) order at
/// every level, no whitespace, serde_json's string escaping (`\"`, `\\`,
/// `\b`, `\f`, `\n`, `\r`, `\t`, other controls as `\u00xx`, everything
/// else raw). Map order is not relied on.
pub fn canonical(json : Json) -> String {
  let sb = StringBuilder()
  write_canonical(sb, json)
  sb.to_string()
}

///|
fn write_canonical(sb : StringBuilder, json : Json) -> Unit {
  match json {
    Null => sb.write_string("null")
    True => sb.write_string("true")
    False => sb.write_string("false")
    Number(d, repr~) =>
      // Byte offsets and small values fit a Double; a `u64` carries its
      // exact digits in `repr`.
      if repr is Some(digits) {
        sb.write_string(digits)
      } else if d == d.floor() && d.abs() < 9007199254740992.0 {
        sb.write_string(d.to_int64().to_string())
      } else {
        sb.write_string(d.to_string())
      }
    String(s) => write_json_string(sb, s)
    Array(items) => {
      sb.write_char('[')
      for i, item in items {
        if i > 0 {
          sb.write_char(',')
        }
        write_canonical(sb, item)
      }
      sb.write_char(']')
    }
    Object(m) => {
      let keys = m.keys().collect()
      keys.sort_by(byte_order)
      sb.write_char('{')
      for i, key in keys {
        if i > 0 {
          sb.write_char(',')
        }
        write_json_string(sb, key)
        sb.write_char(':')
        write_canonical(sb, m.get(key).unwrap())
      }
      sb.write_char('}')
    }
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
pub fn encode_parsed(p : Parsed) -> Json {
  obj([
    ("module", encode_module(p.module_)),
    ("extra", encode_extra(p.extra)),
    ("warnings", list(p.warnings, encode_warning)),
  ])
}

///|
pub fn encode_module(m : Module) -> Json {
  obj([("definitions", list(m.definitions, encode_targeted_definition))])
}

///|
pub fn encode_targeted_definition(d : TargetedDefinition) -> Json {
  obj([
    ("definition", encode_definition(d.definition)),
    ("target", opt(d.target, t => str(t.name()))),
  ])
}

///|
pub fn encode_definition(d : Definition) -> Json {
  match d {
    Function(f) => encode_function(f, "function")
    TypeAlias(t) =>
      obj([
        ("kind", str("type_alias")),
        ("location", encode_span(t.location)),
        ("alias", str(t.alias_)),
        ("name_location", encode_span(t.name_location)),
        ("parameters", list(t.parameters, spanned_string)),
        ("type_ast", encode_type_ast(t.type_ast)),
        ("publicity", encode_publicity(t.publicity)),
        ("documentation", opt(t.documentation, documentation)),
        ("deprecation", deprecation(t.deprecation)),
      ])
    CustomType(c) =>
      obj([
        ("kind", str("custom_type")),
        ("location", encode_span(c.location)),
        ("end_position", num(c.end_position)),
        ("name", str(c.name)),
        ("name_location", encode_span(c.name_location)),
        ("publicity", encode_publicity(c.publicity)),
        ("constructors", list(c.constructors, record_constructor)),
        ("documentation", opt(c.documentation, documentation)),
        ("deprecation", deprecation(c.deprecation)),
        ("opaque", Json::boolean(c.opaque_)),
        ("parameters", list(c.parameters, spanned_string)),
        ("external_erlang", opt(c.external_erlang, external)),
        ("external_javascript", opt(c.external_javascript, external)),
      ])
    Import(i) =>
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
      ])
    ModuleConstant(c) =>
      obj([
        ("kind", str("module_constant")),
        ("documentation", opt(c.documentation, documentation)),
        ("location", encode_span(c.location)),
        ("publicity", encode_publicity(c.publicity)),
        ("name", str(c.name)),
        ("name_location", encode_span(c.name_location)),
        ("annotation", opt(c.annotation, encode_type_ast)),
        ("value", encode_constant(c.value)),
        ("deprecation", deprecation(c.deprecation)),
      ])
  }
}

///|
fn encode_function(f : Function, kind : String) -> Json {
  obj([
    ("kind", str(kind)),
    ("location", encode_span(f.location)),
    ("body_start", opt(f.body_start, num)),
    ("end_position", num(f.end_position)),
    ("name", opt(f.name, spanned_string)),
    ("arguments", list(f.arguments, arg)),
    ("body", list(f.body, encode_statement)),
    ("publicity", encode_publicity(f.publicity)),
    ("deprecation", deprecation(f.deprecation)),
    ("return_annotation", opt(f.return_annotation, encode_type_ast)),
    ("documentation", opt(f.documentation, documentation)),
    ("external_erlang", opt(f.external_erlang, external)),
    ("external_javascript", opt(f.external_javascript, external)),
  ])
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
fn record_constructor(r : RecordConstructor) -> Json {
  obj([
    ("location", encode_span(r.location)),
    ("name_location", encode_span(r.name_location)),
    ("name", str(r.name)),
    ("arguments", list(r.arguments, record_constructor_arg)),
    ("documentation", opt(r.documentation, documentation)),
    ("deprecation", deprecation(r.deprecation)),
  ])
}

///|
fn record_constructor_arg(a : RecordConstructorArg) -> Json {
  obj([
    ("label", opt(a.label, spanned_string)),
    ("ast", encode_type_ast(a.ast)),
    ("location", encode_span(a.location)),
    ("doc", opt(a.doc, documentation)),
  ])
}

///|
fn arg(a : Arg) -> Json {
  obj([
    ("names", arg_names(a.names)),
    ("location", encode_span(a.location)),
    ("annotation", opt(a.annotation, encode_type_ast)),
  ])
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
pub fn encode_type_ast(t : TypeAst) -> Json {
  match t {
    Constructor(c) =>
      obj([
        ("kind", str("constructor")),
        ("location", encode_span(c.location)),
        ("name", type_ast_constructor_name(c.name)),
        ("arguments", list(c.arguments, encode_type_ast)),
        ("start_parentheses", opt(c.start_parentheses, num)),
      ])
    Fn(f) =>
      obj([
        ("kind", str("fn")),
        ("location", encode_span(f.location)),
        ("arguments", list(f.arguments, encode_type_ast)),
        ("return_", encode_type_ast(f.return_)),
      ])
    Var(v) =>
      obj([
        ("kind", str("var")),
        ("location", encode_span(v.location)),
        ("name", str(v.name)),
      ])
    Tuple(t) =>
      obj([
        ("kind", str("tuple")),
        ("location", encode_span(t.location)),
        ("elements", list(t.elements, encode_type_ast)),
      ])
    Hole(h) =>
      obj([
        ("kind", str("hole")),
        ("location", encode_span(h.location)),
        ("name", str(h.name)),
      ])
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
pub fn encode_statement(s : Statement) -> Json {
  match s {
    Expression(e) =>
      obj([("kind", str("expression")), ("expression", encode_expr(e))])
    Assignment(a) =>
      obj([
        ("kind", str("assignment")),
        ("location", encode_span(a.location)),
        ("value", encode_expr(a.value)),
        ("pattern", encode_pattern(a.pattern)),
        ("assignment_kind", assignment_kind(a.kind)),
        ("annotation", opt(a.annotation, encode_type_ast)),
      ])
    Use(u) =>
      obj([
        ("kind", str("use")),
        ("call", encode_expr(u.call)),
        ("location", encode_span(u.location)),
        ("right_hand_side_location", encode_span(u.right_hand_side_location)),
        ("assignments_location", encode_span(u.assignments_location)),
        ("assignments", list(u.assignments, use_assignment)),
      ])
    Assert(a) =>
      obj([
        ("kind", str("assert")),
        ("location", encode_span(a.location)),
        ("value", encode_expr(a.value)),
        ("message", opt(a.message, encode_expr)),
      ])
  }
}

///|
/// `Assignment.kind` is written under `assignment_kind`, because `kind`
/// names the statement.
fn assignment_kind(k : AssignmentKind) -> Json {
  match k {
    Let => obj([("kind", str("let"))])
    Generated => obj([("kind", str("generated"))])
    Assert(location~, assert_keyword_start~, message~) =>
      obj([
        ("kind", str("assert")),
        ("location", encode_span(location)),
        ("assert_keyword_start", num(assert_keyword_start)),
        ("message", opt(message, encode_expr)),
      ])
  }
}

///|
fn use_assignment(u : UseAssignment) -> Json {
  obj([
    ("location", encode_span(u.location)),
    ("pattern", encode_pattern(u.pattern)),
    ("annotation", opt(u.annotation, encode_type_ast)),
  ])
}

///|
fn[A] call_arg(a : CallArg[A], f : (A) -> Json) -> Json {
  obj([
    ("label", opt(a.label, str)),
    ("location", encode_span(a.location)),
    ("value", f(a.value)),
    ("implicit", opt(a.implicit, i => str(i.name()))),
  ])
}

///|
fn[A] record_being_updated(r : RecordBeingUpdated[A], f : (A) -> Json) -> Json {
  obj([("base", f(r.base)), ("location", encode_span(r.location))])
}

///|
fn[A] record_update_arg(a : RecordUpdateArg[A], f : (A) -> Json) -> Json {
  obj([
    ("label", str(a.label)),
    ("location", encode_span(a.location)),
    ("value", f(a.value)),
  ])
}

///|
fn[V] bit_array_segment(s : BitArraySegment[V], f : (V) -> Json) -> Json {
  obj([
    ("location", encode_span(s.location)),
    ("value", f(s.value)),
    ("options", list(s.options, o => bit_array_option(o, f))),
  ])
}

///|
fn[V] bit_array_option(o : BitArrayOption[V], f : (V) -> Json) -> Json {
  let simple = (kind : String, location : @span.SrcSpan) => {
    obj([("kind", str(kind)), ("location", encode_span(location))])
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
      obj([
        ("kind", str("size")),
        ("location", encode_span(location)),
        ("value", f(value)),
        ("short_form", Json::boolean(short_form)),
      ])
    Unit(location~, value~) =>
      obj([
        ("kind", str("unit")),
        ("location", encode_span(location)),
        ("value", num(value)),
      ])
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
pub fn encode_expr(e : Expr) -> Json {
  match e {
    Int(location~, value~, int_value~) =>
      obj([
        ("kind", str("int")),
        ("location", encode_span(location)),
        ("value", str(value)),
        ("int_value", str(int_value.to_string())),
      ])
    Float(location~, value~, ..) =>
      obj([
        ("kind", str("float")),
        ("location", encode_span(location)),
        ("value", str(value)),
      ])
    String(location~, value~) =>
      obj([
        ("kind", str("string")),
        ("location", encode_span(location)),
        ("value", str(value)),
      ])
    Block(location~, statements~) =>
      obj([
        ("kind", str("block")),
        ("location", encode_span(location)),
        ("statements", list(statements, encode_statement)),
      ])
    Var(location~, name~) =>
      obj([
        ("kind", str("var")),
        ("location", encode_span(location)),
        ("name", str(name)),
      ])
    Fn(
      location~,
      kind~,
      end_of_head_byte_index~,
      arguments~,
      body~,
      return_annotation~
    ) =>
      obj([
        ("kind", str("fn")),
        ("location", encode_span(location)),
        ("fn_kind", function_literal_kind(kind)),
        ("end_of_head_byte_index", num(end_of_head_byte_index)),
        ("arguments", list(arguments, arg)),
        ("body", list(body, encode_statement)),
        ("return_annotation", opt(return_annotation, encode_type_ast)),
      ])
    List(location~, elements~, tail~) =>
      obj([
        ("kind", str("list")),
        ("location", encode_span(location)),
        ("elements", list(elements, encode_expr)),
        ("tail", opt(tail, encode_expr)),
      ])
    Call(location~, fun~, arguments~, open_parenthesis~) =>
      obj([
        ("kind", str("call")),
        ("location", encode_span(location)),
        ("fun", encode_expr(fun)),
        ("arguments", list(arguments, a => call_arg(a, encode_expr))),
        ("open_parenthesis", num(open_parenthesis)),
      ])
    BinOp(location~, operator~, operator_start~, left~, right~) =>
      obj([
        ("kind", str("bin_op")),
        ("location", encode_span(location)),
        ("operator", str(operator.name())),
        ("operator_start", num(operator_start)),
        ("left", encode_expr(left)),
        ("right", encode_expr(right)),
      ])
    Pipeline(expressions~) =>
      obj([
        ("kind", str("pipeline")),
        ("expressions", list(expressions, encode_expr)),
      ])
    Case(location~, subjects~, clauses~) =>
      obj([
        ("kind", str("case")),
        ("location", encode_span(location)),
        ("subjects", list(subjects, encode_expr)),
        ("clauses", opt(clauses, cs => list(cs, clause))),
      ])
    FieldAccess(location~, label_location~, label~, container~) =>
      obj([
        ("kind", str("field_access")),
        ("location", encode_span(location)),
        ("label_location", encode_span(label_location)),
        ("label", str(label)),
        ("container", encode_expr(container)),
      ])
    Tuple(location~, elements~) =>
      obj([
        ("kind", str("tuple")),
        ("location", encode_span(location)),
        ("elements", list(elements, encode_expr)),
      ])
    TupleIndex(location~, index~, tuple~) =>
      obj([
        ("kind", str("tuple_index")),
        ("location", encode_span(location)),
        ("index", num64(index)),
        ("tuple", encode_expr(tuple)),
      ])
    Todo(kind~, location~, message~) =>
      obj([
        ("kind", str("todo")),
        ("todo_kind", todo_kind(kind)),
        ("location", encode_span(location)),
        ("message", opt(message, encode_expr)),
      ])
    Panic(location~, message~) =>
      obj([
        ("kind", str("panic")),
        ("location", encode_span(location)),
        ("message", opt(message, encode_expr)),
      ])
    Echo(location~, keyword_end~, expression~, message~) =>
      obj([
        ("kind", str("echo")),
        ("location", encode_span(location)),
        ("keyword_end", num(keyword_end)),
        ("expression", opt(expression, encode_expr)),
        ("message", opt(message, encode_expr)),
      ])
    BitArray(location~, segments~) =>
      obj([
        ("kind", str("bit_array")),
        ("location", encode_span(location)),
        ("segments", list(segments, s => bit_array_segment(s, encode_expr))),
      ])
    RecordUpdate(location~, spread_start~, constructor_~, record~, arguments~) =>
      obj([
        ("kind", str("record_update")),
        ("location", encode_span(location)),
        ("spread_start", num(spread_start)),
        ("constructor", encode_expr(constructor_)),
        ("record", record_being_updated(record, encode_expr)),
        ("arguments", list(arguments, a => record_update_arg(a, encode_expr))),
      ])
    NegateBool(location~, value~) =>
      obj([
        ("kind", str("negate_bool")),
        ("location", encode_span(location)),
        ("value", encode_expr(value)),
      ])
    NegateInt(location~, value~) =>
      obj([
        ("kind", str("negate_int")),
        ("location", encode_span(location)),
        ("value", encode_expr(value)),
      ])
  }
}

///|
fn clause(c : Clause) -> Json {
  obj([
    ("location", encode_span(c.location)),
    ("pattern", list(c.pattern, encode_pattern)),
    (
      "alternative_patterns",
      list(c.alternative_patterns, ps => list(ps, encode_pattern)),
    ),
    ("guard", opt(c.guard_, encode_clause_guard)),
    ("then", encode_expr(c.then)),
  ])
}

///|
pub fn encode_clause_guard(g : ClauseGuard) -> Json {
  match g {
    Block(location~, value~) =>
      obj([
        ("kind", str("block")),
        ("location", encode_span(location)),
        ("value", encode_clause_guard(value)),
      ])
    BinaryOperator(location~, operator~, operator_start~, left~, right~) =>
      obj([
        ("kind", str("binary_operator")),
        ("location", encode_span(location)),
        ("operator", str(operator.name())),
        ("operator_start", num(operator_start)),
        ("left", encode_clause_guard(left)),
        ("right", encode_clause_guard(right)),
      ])
    Not(location~, expression~) =>
      obj([
        ("kind", str("not")),
        ("location", encode_span(location)),
        ("expression", encode_clause_guard(expression)),
      ])
    Var(location~, name~) =>
      obj([
        ("kind", str("var")),
        ("location", encode_span(location)),
        ("name", str(name)),
      ])
    TupleIndex(location~, index~, tuple~) =>
      obj([
        ("kind", str("tuple_index")),
        ("location", encode_span(location)),
        ("index", num64(index)),
        ("tuple", encode_clause_guard(tuple)),
      ])
    FieldAccess(label_location~, index~, label~, container~) =>
      obj([
        ("kind", str("field_access")),
        ("label_location", encode_span(label_location)),
        ("index", opt(index, num64)),
        ("label", str(label)),
        ("container", encode_clause_guard(container)),
      ])
    Constant(c) =>
      obj([("kind", str("constant")), ("constant", encode_constant(c))])
  }
}

///|
pub fn encode_pattern(p : Pattern) -> Json {
  match p {
    Int(location~, value~, int_value~) =>
      obj([
        ("kind", str("int")),
        ("location", encode_span(location)),
        ("value", str(value)),
        ("int_value", str(int_value.to_string())),
      ])
    Float(location~, value~, ..) =>
      obj([
        ("kind", str("float")),
        ("location", encode_span(location)),
        ("value", str(value)),
      ])
    String(location~, value~) =>
      obj([
        ("kind", str("string")),
        ("location", encode_span(location)),
        ("value", str(value)),
      ])
    Variable(location~, name~) =>
      obj([
        ("kind", str("variable")),
        ("location", encode_span(location)),
        ("name", str(name)),
      ])
    BitArraySize(s) =>
      obj([("kind", str("bit_array_size")), ("size", bit_array_size(s))])
    Assign(name~, location~, pattern~) =>
      obj([
        ("kind", str("assign")),
        ("name", str(name)),
        ("location", encode_span(location)),
        ("pattern", encode_pattern(pattern)),
      ])
    Discard(name~, location~) =>
      obj([
        ("kind", str("discard")),
        ("name", str(name)),
        ("location", encode_span(location)),
      ])
    List(location~, elements~, tail~) =>
      obj([
        ("kind", str("list")),
        ("location", encode_span(location)),
        ("elements", list(elements, encode_pattern)),
        (
          "tail",
          opt(tail, t => {
            obj([
              ("location", encode_span(t.location)),
              ("pattern", encode_pattern(t.pattern)),
            ])
          }),
        ),
      ])
    Constructor(location~, name_location~, name~, arguments~, module_~, spread~) =>
      obj([
        ("kind", str("constructor")),
        ("location", encode_span(location)),
        ("name_location", encode_span(name_location)),
        ("name", str(name)),
        ("arguments", list(arguments, a => call_arg(a, encode_pattern))),
        ("module", opt(module_, spanned_string)),
        ("spread", opt(spread, encode_span)),
      ])
    Tuple(location~, elements~) =>
      obj([
        ("kind", str("tuple")),
        ("location", encode_span(location)),
        ("elements", list(elements, encode_pattern)),
      ])
    BitArray(location~, segments~) =>
      obj([
        ("kind", str("bit_array")),
        ("location", encode_span(location)),
        ("segments", list(segments, s => bit_array_segment(s, encode_pattern))),
      ])
    StringPrefix(
      location~,
      left_location~,
      left_side_assignment~,
      right_location~,
      left_side_string~,
      right_side_assignment~
    ) =>
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
      ])
  }
}

///|
fn bit_array_size(s : BitArraySize) -> Json {
  match s {
    Int(location~, value~, int_value~) =>
      obj([
        ("kind", str("int")),
        ("location", encode_span(location)),
        ("value", str(value)),
        ("int_value", str(int_value.to_string())),
      ])
    Variable(location~, name~) =>
      obj([
        ("kind", str("variable")),
        ("location", encode_span(location)),
        ("name", str(name)),
      ])
    BinaryOperator(location~, operator~, left~, right~) =>
      obj([
        ("kind", str("binary_operator")),
        ("location", encode_span(location)),
        ("operator", str(operator.name())),
        ("left", bit_array_size(left)),
        ("right", bit_array_size(right)),
      ])
    Block(location~, inner~) =>
      obj([
        ("kind", str("block")),
        ("location", encode_span(location)),
        ("inner", bit_array_size(inner)),
      ])
  }
}

///|
pub fn encode_constant(c : Constant) -> Json {
  match c {
    Int(location~, value~, int_value~) =>
      obj([
        ("kind", str("int")),
        ("location", encode_span(location)),
        ("value", str(value)),
        ("int_value", str(int_value.to_string())),
      ])
    Float(location~, value~, ..) =>
      obj([
        ("kind", str("float")),
        ("location", encode_span(location)),
        ("value", str(value)),
      ])
    String(location~, value~) =>
      obj([
        ("kind", str("string")),
        ("location", encode_span(location)),
        ("value", str(value)),
      ])
    Tuple(location~, elements~) =>
      obj([
        ("kind", str("tuple")),
        ("location", encode_span(location)),
        ("elements", list(elements, encode_constant)),
      ])
    List(location~, elements~, tail~) =>
      obj([
        ("kind", str("list")),
        ("location", encode_span(location)),
        ("elements", list(elements, encode_constant)),
        ("tail", opt(tail, encode_constant)),
      ])
    Record(location~, arguments_start_position~, module_~, name~, arguments~) =>
      obj([
        ("kind", str("record")),
        ("location", encode_span(location)),
        ("arguments_start_position", num(arguments_start_position)),
        ("module", opt(module_, spanned_string)),
        ("name", str(name)),
        (
          "arguments",
          opt(arguments, xs => list(xs, a => call_arg(a, encode_constant))),
        ),
      ])
    RecordUpdate(
      location~,
      constructor_location~,
      module_~,
      name~,
      record~,
      arguments~
    ) =>
      obj([
        ("kind", str("record_update")),
        ("location", encode_span(location)),
        ("constructor_location", encode_span(constructor_location)),
        ("module", opt(module_, spanned_string)),
        ("name", str(name)),
        ("record", record_being_updated(record, encode_constant)),
        (
          "arguments",
          list(arguments, a => record_update_arg(a, encode_constant)),
        ),
      ])
    BitArray(location~, segments~) =>
      obj([
        ("kind", str("bit_array")),
        ("location", encode_span(location)),
        ("segments", list(segments, s => bit_array_segment(s, encode_constant))),
      ])
    Var(location~, module_~, name~) =>
      obj([
        ("kind", str("var")),
        ("location", encode_span(location)),
        ("module", opt(module_, spanned_string)),
        ("name", str(name)),
      ])
    BinaryOperator(location~, operator_start~, operator~, left~, right~) =>
      obj([
        ("kind", str("binary_operator")),
        ("location", encode_span(location)),
        ("operator_start", num(operator_start)),
        ("operator", str(operator.name())),
        ("left", encode_constant(left)),
        ("right", encode_constant(right)),
      ])
    Todo(location~, message~) =>
      obj([
        ("kind", str("todo")),
        ("location", encode_span(location)),
        ("message", opt(message, encode_constant)),
      ])
  }
}

///|
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
