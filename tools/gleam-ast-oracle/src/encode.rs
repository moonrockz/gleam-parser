//! Canonical JSON for the compiler's untyped AST: the schema of
//! docs/ast-json.md, key for key the same as src/ast/encode.mbt.

use gleam_core::ast::{
    Arg, ArgNames, AssignName, AssignmentKind, BinOp, BitArrayOption, BitArraySegment,
    BitArraySize, CallArg, Clause, ClauseGuard, Constant, CustomType, Definition, Function,
    FunctionLiteralKind, Import, ImplicitCallArgOrigin, IntOperator, ModuleConstant, Pattern,
    Publicity, RecordBeingUpdated, RecordConstructor, RecordConstructorArg, RecordUpdateArg,
    Statement, TailPattern, TargetedDefinition, TodoKind, TypeAlias, TypeAst,
    TypeAstConstructorName, UnqualifiedImport, UntypedExpr, UntypedModule,
};
use gleam_core::build::Target;
use gleam_core::parse::Parsed;
use gleam_core::parse::error::{InvalidUnicodeEscapeError, LexicalErrorType, ParseError, ParseErrorType};
use gleam_core::parse::extra::ModuleExtra;
use gleam_core::type_::Deprecation;
use gleam_core::warning::{DeprecatedSyntaxWarning, Warning};
use serde_json::{Value, json};
use src_span::SrcSpan;

pub fn parsed(p: &Parsed, warnings: &[Warning]) -> Value {
    json!({
        "module": module(&p.module),
        "extra": extra(&p.extra),
        "warnings": warnings.iter().filter_map(warning).collect::<Vec<_>>(),
    })
}

pub fn parse_error(e: &ParseError) -> Value {
    let debug = format!("{:?}", e.error);
    let kind: String = debug
        .chars()
        .take_while(|c| c.is_ascii_alphanumeric())
        .collect();
    let lexical_kind = match &e.error {
        ParseErrorType::LexError { error, .. } => Value::String(lexical_kind(&error.error)),
        _ => Value::Null,
    };
    json!({ "error": { "kind": kind, "lexical_kind": lexical_kind, "location": span(&e.location) } })
}

/// The names `@scanner.LexicalErrorType::kind()` gives.
fn lexical_kind(e: &LexicalErrorType) -> String {
    match e {
        LexicalErrorType::BadStringEscape => "BadStringEscape",
        LexicalErrorType::InvalidUnicodeEscape(InvalidUnicodeEscapeError::MissingOpeningBrace) => {
            "InvalidUnicodeEscape.MissingOpeningBrace"
        }
        LexicalErrorType::InvalidUnicodeEscape(InvalidUnicodeEscapeError::ExpectedHexDigitOrCloseBrace) => {
            "InvalidUnicodeEscape.ExpectedHexDigitOrCloseBrace"
        }
        LexicalErrorType::InvalidUnicodeEscape(InvalidUnicodeEscapeError::InvalidNumberOfHexDigits) => {
            "InvalidUnicodeEscape.InvalidNumberOfHexDigits"
        }
        LexicalErrorType::InvalidUnicodeEscape(InvalidUnicodeEscapeError::InvalidCodepoint) => {
            "InvalidUnicodeEscape.InvalidCodepoint"
        }
        LexicalErrorType::DigitOutOfRadix => "DigitOutOfRadix",
        LexicalErrorType::NumTrailingUnderscore => "NumTrailingUnderscore",
        LexicalErrorType::RadixIntNoValue => "RadixIntNoValue",
        LexicalErrorType::MissingExponent => "MissingExponent",
        LexicalErrorType::UnexpectedStringEnd => "UnexpectedStringEnd",
        LexicalErrorType::UnrecognizedToken { .. } => "UnrecognizedToken",
        LexicalErrorType::InvalidTripleEqual => "InvalidTripleEqual",
        LexicalErrorType::MergeConflictIndicator => "MergeConflictIndicator",
        LexicalErrorType::UnsupportedProceduralOperator => "UnsupportedProceduralOperator",
        LexicalErrorType::VisuallySimilarInvalidCharacter { .. } => "VisuallySimilarInvalidCharacter",
    }
    .to_string()
}

fn span(s: &SrcSpan) -> Value {
    json!({ "start": s.start, "end": s.end })
}

fn opt<T>(o: &Option<T>, f: impl Fn(&T) -> Value) -> Value {
    match o {
        Some(v) => f(v),
        None => Value::Null,
    }
}

fn list<T>(xs: &[T], f: impl Fn(&T) -> Value) -> Value {
    Value::Array(xs.iter().map(f).collect())
}

fn spanned_string((location, name): &(SrcSpan, ecow::EcoString)) -> Value {
    json!({ "location": span(location), "name": name })
}

fn module_ref((name, location): &(ecow::EcoString, SrcSpan)) -> Value {
    json!({ "location": span(location), "name": name })
}

fn documentation((start, text): &(u32, ecow::EcoString)) -> Value {
    json!({ "start": start, "text": text })
}

fn external((module, function, location): &(ecow::EcoString, ecow::EcoString, SrcSpan)) -> Value {
    json!({ "module": module, "function": function, "location": span(location) })
}

fn publicity(p: &Publicity) -> Value {
    match p {
        Publicity::Public => json!({ "kind": "public" }),
        Publicity::Private => json!({ "kind": "private" }),
        Publicity::Internal { attribute_location } => {
            json!({ "kind": "internal", "attribute_location": opt(attribute_location, span) })
        }
    }
}

fn deprecation(d: &Deprecation) -> Value {
    match d {
        Deprecation::NotDeprecated => json!({ "kind": "not_deprecated" }),
        Deprecation::Deprecated { message } => json!({ "kind": "deprecated", "message": message }),
    }
}

fn assign_name(a: &AssignName) -> Value {
    match a {
        AssignName::Variable(name) => json!({ "kind": "variable", "name": name }),
        AssignName::Discard(name) => json!({ "kind": "discard", "name": name }),
    }
}

fn target(t: &Target) -> Value {
    match t {
        Target::Erlang => json!("erlang"),
        Target::JavaScript => json!("javascript"),
    }
}

fn bin_op(op: &BinOp) -> Value {
    json!(match op {
        BinOp::And => "and",
        BinOp::Or => "or",
        BinOp::Eq => "eq",
        BinOp::NotEq => "not_eq",
        BinOp::LtInt => "lt_int",
        BinOp::LtEqInt => "lt_eq_int",
        BinOp::LtFloat => "lt_float",
        BinOp::LtEqFloat => "lt_eq_float",
        BinOp::GtEqInt => "gt_eq_int",
        BinOp::GtInt => "gt_int",
        BinOp::GtEqFloat => "gt_eq_float",
        BinOp::GtFloat => "gt_float",
        BinOp::AddInt => "add_int",
        BinOp::AddFloat => "add_float",
        BinOp::SubInt => "sub_int",
        BinOp::SubFloat => "sub_float",
        BinOp::MultInt => "mult_int",
        BinOp::MultFloat => "mult_float",
        BinOp::DivInt => "div_int",
        BinOp::DivFloat => "div_float",
        BinOp::RemainderInt => "remainder_int",
        BinOp::Concatenate => "concatenate",
    })
}

fn int_operator(op: &IntOperator) -> Value {
    json!(match op {
        IntOperator::Add => "add",
        IntOperator::Subtract => "subtract",
        IntOperator::Multiply => "multiply",
        IntOperator::Divide => "divide",
        IntOperator::Remainder => "remainder",
    })
}

fn implicit(i: &ImplicitCallArgOrigin) -> Value {
    json!(match i {
        ImplicitCallArgOrigin::Use => "use",
        ImplicitCallArgOrigin::Pipe => "pipe",
        ImplicitCallArgOrigin::PatternFieldSpread => "pattern_field_spread",
        ImplicitCallArgOrigin::IncorrectArityUse => "incorrect_arity_use",
        ImplicitCallArgOrigin::RecordUpdate => "record_update",
    })
}

fn module(m: &UntypedModule) -> Value {
    json!({ "definitions": list(&m.definitions, targeted_definition) })
}

fn targeted_definition(d: &TargetedDefinition) -> Value {
    json!({ "definition": definition(&d.definition), "target": opt(&d.target, target) })
}

fn definition(d: &Definition<(), UntypedExpr, ()>) -> Value {
    match d {
        Definition::Function(f) => function(f),
        Definition::TypeAlias(t) => type_alias(t),
        Definition::CustomType(c) => custom_type(c),
        Definition::Import(i) => import(i),
        Definition::ModuleConstant(c) => module_constant(c),
    }
}

fn function(f: &Function<(), UntypedExpr>) -> Value {
    json!({
        "kind": "function",
        "location": span(&f.location),
        "body_start": opt(&f.body_start, |b| json!(b)),
        "end_position": f.end_position,
        "name": opt(&f.name, spanned_string),
        "arguments": list(&f.arguments, arg),
        "body": list(&f.body, statement),
        "publicity": publicity(&f.publicity),
        "deprecation": deprecation(&f.deprecation),
        "return_annotation": opt(&f.return_annotation, type_ast),
        "documentation": opt(&f.documentation, documentation),
        "external_erlang": opt(&f.external_erlang, external),
        "external_javascript": opt(&f.external_javascript, external),
    })
}

fn type_alias(t: &TypeAlias<()>) -> Value {
    json!({
        "kind": "type_alias",
        "location": span(&t.location),
        "alias": t.alias,
        "name_location": span(&t.name_location),
        "parameters": list(&t.parameters, spanned_string),
        "type_ast": type_ast(&t.type_ast),
        "publicity": publicity(&t.publicity),
        "documentation": opt(&t.documentation, documentation),
        "deprecation": deprecation(&t.deprecation),
    })
}

fn custom_type(c: &CustomType<()>) -> Value {
    json!({
        "kind": "custom_type",
        "location": span(&c.location),
        "end_position": c.end_position,
        "name": c.name,
        "name_location": span(&c.name_location),
        "publicity": publicity(&c.publicity),
        "constructors": list(&c.constructors, record_constructor),
        "documentation": opt(&c.documentation, documentation),
        "deprecation": deprecation(&c.deprecation),
        "opaque": c.opaque,
        "parameters": list(&c.parameters, spanned_string),
        "external_erlang": opt(&c.external_erlang, external),
        "external_javascript": opt(&c.external_javascript, external),
    })
}

fn record_constructor(r: &RecordConstructor<()>) -> Value {
    json!({
        "location": span(&r.location),
        "name_location": span(&r.name_location),
        "name": r.name,
        "arguments": list(&r.arguments, record_constructor_arg),
        "documentation": opt(&r.documentation, documentation),
        "deprecation": deprecation(&r.deprecation),
    })
}

fn record_constructor_arg(a: &RecordConstructorArg<()>) -> Value {
    json!({
        "label": opt(&a.label, spanned_string),
        "ast": type_ast(&a.ast),
        "location": span(&a.location),
        "doc": opt(&a.doc, documentation),
    })
}

fn import(i: &Import<()>) -> Value {
    json!({
        "kind": "import",
        "documentation": opt(&i.documentation, |d| json!(d)),
        "location": span(&i.location),
        "module_location": span(&i.module_location),
        "module": i.module,
        "as_name": opt(&i.as_name, |(name, location)| json!({ "name": assign_name(name), "location": span(location) })),
        "unqualified_values": list(&i.unqualified_values, unqualified_import),
        "unqualified_types": list(&i.unqualified_types, unqualified_import),
    })
}

fn unqualified_import(u: &UnqualifiedImport) -> Value {
    json!({
        "location": span(&u.location),
        "name": u.name,
        "name_position": u.name_position,
        "as_name": opt(&u.as_name, |n| json!(n)),
    })
}

fn module_constant(c: &ModuleConstant<()>) -> Value {
    json!({
        "kind": "module_constant",
        "documentation": opt(&c.documentation, documentation),
        "location": span(&c.location),
        "publicity": publicity(&c.publicity),
        "name": c.name,
        "name_location": span(&c.name_location),
        "annotation": opt(&c.annotation, type_ast),
        "value": constant(&c.value),
        "deprecation": deprecation(&c.deprecation),
    })
}

fn arg(a: &Arg<()>) -> Value {
    json!({
        "names": arg_names(&a.names),
        "location": span(&a.location),
        "annotation": opt(&a.annotation, type_ast),
    })
}

fn arg_names(n: &ArgNames) -> Value {
    match n {
        ArgNames::Discard { name, location } => json!({ "kind": "discard", "name": name, "location": span(location) }),
        ArgNames::LabelledDiscard { label, label_location, name, name_location } => json!({
            "kind": "labelled_discard", "label": label, "label_location": span(label_location),
            "name": name, "name_location": span(name_location),
        }),
        ArgNames::Named { name, location } => json!({ "kind": "named", "name": name, "location": span(location) }),
        ArgNames::NamedLabelled { label, label_location, name, name_location } => json!({
            "kind": "named_labelled", "label": label, "label_location": span(label_location),
            "name": name, "name_location": span(name_location),
        }),
    }
}

fn type_ast(t: &TypeAst) -> Value {
    match t {
        TypeAst::Constructor(c) => json!({
            "kind": "constructor",
            "location": span(&c.location),
            "name": type_ast_constructor_name(&c.name),
            "arguments": list(&c.arguments, type_ast),
            "start_parentheses": opt(&c.start_parentheses, |p| json!(p)),
        }),
        TypeAst::Fn(f) => json!({
            "kind": "fn",
            "location": span(&f.location),
            "arguments": list(&f.arguments, type_ast),
            "return_": type_ast(&f.return_),
        }),
        TypeAst::Var(v) => json!({ "kind": "var", "location": span(&v.location), "name": v.name }),
        TypeAst::Tuple(t) => json!({ "kind": "tuple", "location": span(&t.location), "elements": list(&t.elements, type_ast) }),
        TypeAst::Hole(h) => json!({ "kind": "hole", "location": span(&h.location), "name": h.name }),
    }
}

fn type_ast_constructor_name(n: &TypeAstConstructorName) -> Value {
    match n {
        TypeAstConstructorName::Qualified { module, module_location, dot_location, name } => json!({
            "kind": "qualified",
            "module": module,
            "module_location": span(module_location),
            "dot_location": dot_location,
            "name": opt(name, |(name, location)| json!({ "location": span(location), "name": name })),
        }),
        TypeAstConstructorName::Unqualified { name, location } => json!({ "kind": "unqualified", "name": name, "location": span(location) }),
    }
}

fn statement(s: &Statement<(), UntypedExpr>) -> Value {
    match s {
        Statement::Expression(e) => json!({ "kind": "expression", "expression": expr(e) }),
        Statement::Assignment(a) => json!({
            "kind": "assignment",
            "location": span(&a.location),
            "value": expr(&a.value),
            "pattern": pattern(&a.pattern),
            "assignment_kind": assignment_kind(&a.kind),
            "annotation": opt(&a.annotation, type_ast),
        }),
        Statement::Use(u) => json!({
            "kind": "use",
            "call": expr(&u.call),
            "location": span(&u.location),
            "right_hand_side_location": span(&u.right_hand_side_location),
            "assignments_location": span(&u.assignments_location),
            "assignments": list(&u.assignments, |a| json!({
                "location": span(&a.location),
                "pattern": pattern(&a.pattern),
                "annotation": opt(&a.annotation, type_ast),
            })),
        }),
        Statement::Assert(a) => json!({
            "kind": "assert",
            "location": span(&a.location),
            "value": expr(&a.value),
            "message": opt(&a.message, expr),
        }),
    }
}

fn assignment_kind(k: &AssignmentKind<UntypedExpr>) -> Value {
    match k {
        AssignmentKind::Let => json!({ "kind": "let" }),
        AssignmentKind::Generated => json!({ "kind": "generated" }),
        AssignmentKind::Assert { location, assert_keyword_start, message } => json!({
            "kind": "assert",
            "location": span(location),
            "assert_keyword_start": assert_keyword_start,
            "message": opt(message, expr),
        }),
    }
}

fn call_arg<A>(a: &CallArg<A>, f: impl Fn(&A) -> Value) -> Value {
    json!({
        "label": opt(&a.label, |l| json!(l)),
        "location": span(&a.location),
        "value": f(&a.value),
        "implicit": opt(&a.implicit, implicit),
    })
}

fn record_being_updated<A>(r: &RecordBeingUpdated<A>, f: impl Fn(&A) -> Value) -> Value {
    json!({ "base": f(&r.base), "location": span(&r.location) })
}

fn record_update_arg<A>(a: &RecordUpdateArg<A>, f: impl Fn(&A) -> Value) -> Value {
    json!({ "label": a.label, "location": span(&a.location), "value": f(&a.value) })
}

fn bit_array_segment<V, T>(s: &BitArraySegment<V, T>, f: &impl Fn(&V) -> Value) -> Value {
    json!({
        "location": span(&s.location),
        "value": f(&s.value),
        "options": Value::Array(s.options.iter().map(|o| bit_array_option(o, f)).collect()),
    })
}

fn bit_array_option<V>(o: &BitArrayOption<V>, f: &impl Fn(&V) -> Value) -> Value {
    let simple = |kind: &str, location: &SrcSpan| json!({ "kind": kind, "location": span(location) });
    match o {
        BitArrayOption::Bytes { location } => simple("bytes", location),
        BitArrayOption::Int { location } => simple("int", location),
        BitArrayOption::Float { location } => simple("float", location),
        BitArrayOption::Bits { location } => simple("bits", location),
        BitArrayOption::Utf8 { location } => simple("utf8", location),
        BitArrayOption::Utf16 { location } => simple("utf16", location),
        BitArrayOption::Utf32 { location } => simple("utf32", location),
        BitArrayOption::Utf8Codepoint { location } => simple("utf8_codepoint", location),
        BitArrayOption::Utf16Codepoint { location } => simple("utf16_codepoint", location),
        BitArrayOption::Utf32Codepoint { location } => simple("utf32_codepoint", location),
        BitArrayOption::Signed { location } => simple("signed", location),
        BitArrayOption::Unsigned { location } => simple("unsigned", location),
        BitArrayOption::Big { location } => simple("big", location),
        BitArrayOption::Little { location } => simple("little", location),
        BitArrayOption::Native { location } => simple("native", location),
        BitArrayOption::Size { location, value, short_form } => json!({
            "kind": "size", "location": span(location), "value": f(value), "short_form": short_form,
        }),
        BitArrayOption::Unit { location, value } => json!({ "kind": "unit", "location": span(location), "value": value }),
    }
}

fn todo_kind(k: &TodoKind) -> Value {
    match k {
        TodoKind::Keyword => json!({ "kind": "keyword" }),
        TodoKind::EmptyFunction { function_location } => json!({ "kind": "empty_function", "function_location": span(function_location) }),
        TodoKind::IncompleteUse => json!({ "kind": "incomplete_use" }),
        TodoKind::EmptyBlock => json!({ "kind": "empty_block" }),
    }
}

fn function_literal_kind(k: &FunctionLiteralKind) -> Value {
    match k {
        FunctionLiteralKind::Capture { hole } => json!({ "kind": "capture", "hole": span(hole) }),
        FunctionLiteralKind::Anonymous { head } => json!({ "kind": "anonymous", "head": span(head) }),
        FunctionLiteralKind::Use { location } => json!({ "kind": "use", "location": span(location) }),
    }
}

fn expr(e: &UntypedExpr) -> Value {
    match e {
        UntypedExpr::Int { location, value, int_value } => json!({
            "kind": "int", "location": span(location), "value": value, "int_value": int_value.to_string(),
        }),
        UntypedExpr::Float { location, value, .. } => json!({ "kind": "float", "location": span(location), "value": value }),
        UntypedExpr::String { location, value } => json!({ "kind": "string", "location": span(location), "value": value }),
        UntypedExpr::Block { location, statements } => json!({
            "kind": "block", "location": span(location), "statements": list(statements, statement),
        }),
        UntypedExpr::Var { location, name } => json!({ "kind": "var", "location": span(location), "name": name }),
        UntypedExpr::Fn { location, kind, end_of_head_byte_index, arguments, body, return_annotation } => json!({
            "kind": "fn",
            "location": span(location),
            "fn_kind": function_literal_kind(kind),
            "end_of_head_byte_index": end_of_head_byte_index,
            "arguments": list(arguments, arg),
            "body": list(body, statement),
            "return_annotation": opt(return_annotation, type_ast),
        }),
        UntypedExpr::List { location, elements, tail } => json!({
            "kind": "list", "location": span(location), "elements": list(elements, expr), "tail": opt(tail, |t| expr(t)),
        }),
        UntypedExpr::Call { location, fun, arguments, open_parenthesis } => json!({
            "kind": "call",
            "location": span(location),
            "fun": expr(fun),
            "arguments": list(arguments, |a| call_arg(a, expr)),
            "open_parenthesis": open_parenthesis,
        }),
        UntypedExpr::BinOp { location, operator, operator_start, left, right } => json!({
            "kind": "bin_op",
            "location": span(location),
            "operator": bin_op(operator),
            "operator_start": operator_start,
            "left": expr(left),
            "right": expr(right),
        }),
        UntypedExpr::Pipeline { expressions } => json!({ "kind": "pipeline", "expressions": list(expressions, expr) }),
        UntypedExpr::Case { location, subjects, clauses } => json!({
            "kind": "case",
            "location": span(location),
            "subjects": list(subjects, expr),
            "clauses": opt(clauses, |cs| list(cs, clause)),
        }),
        UntypedExpr::FieldAccess { location, label_location, label, container } => json!({
            "kind": "field_access",
            "location": span(location),
            "label_location": span(label_location),
            "label": label,
            "container": expr(container),
        }),
        UntypedExpr::Tuple { location, elements } => json!({ "kind": "tuple", "location": span(location), "elements": list(elements, expr) }),
        UntypedExpr::TupleIndex { location, index, tuple } => json!({
            "kind": "tuple_index", "location": span(location), "index": index, "tuple": expr(tuple),
        }),
        UntypedExpr::Todo { kind, location, message } => json!({
            "kind": "todo", "todo_kind": todo_kind(kind), "location": span(location), "message": opt(message, |m| expr(m)),
        }),
        UntypedExpr::Panic { location, message } => json!({ "kind": "panic", "location": span(location), "message": opt(message, |m| expr(m)) }),
        UntypedExpr::Echo { location, keyword_end, expression, message } => json!({
            "kind": "echo",
            "location": span(location),
            "keyword_end": keyword_end,
            "expression": opt(expression, |x| expr(x)),
            "message": opt(message, |m| expr(m)),
        }),
        UntypedExpr::BitArray { location, segments } => json!({
            "kind": "bit_array", "location": span(location), "segments": list(segments, |s| bit_array_segment(s, &expr)),
        }),
        UntypedExpr::RecordUpdate { location, spread_start, constructor, record, arguments } => json!({
            "kind": "record_update",
            "location": span(location),
            "spread_start": spread_start,
            "constructor": expr(constructor),
            "record": record_being_updated(record, |b| expr(b)),
            "arguments": list(arguments, |a| record_update_arg(a, expr)),
        }),
        UntypedExpr::NegateBool { location, value } => json!({ "kind": "negate_bool", "location": span(location), "value": expr(value) }),
        UntypedExpr::NegateInt { location, value } => json!({ "kind": "negate_int", "location": span(location), "value": expr(value) }),
    }
}

fn clause(c: &Clause<UntypedExpr, ()>) -> Value {
    json!({
        "location": span(&c.location),
        "pattern": list(&c.pattern, pattern),
        "alternative_patterns": list(&c.alternative_patterns, |ps| list(ps, pattern)),
        "guard": opt(&c.guard, clause_guard),
        "then": expr(&c.then),
    })
}

fn clause_guard(g: &ClauseGuard<()>) -> Value {
    match g {
        ClauseGuard::Block { location, value } => json!({ "kind": "block", "location": span(location), "value": clause_guard(value) }),
        ClauseGuard::BinaryOperator { location, operator, operator_start, left, right } => json!({
            "kind": "binary_operator",
            "location": span(location),
            "operator": bin_op(operator),
            "operator_start": operator_start,
            "left": clause_guard(left),
            "right": clause_guard(right),
        }),
        ClauseGuard::Not { location, expression } => json!({ "kind": "not", "location": span(location), "expression": clause_guard(expression) }),
        ClauseGuard::Var { location, name, .. } => json!({ "kind": "var", "location": span(location), "name": name }),
        ClauseGuard::TupleIndex { location, index, tuple, .. } => json!({
            "kind": "tuple_index", "location": span(location), "index": index, "tuple": clause_guard(tuple),
        }),
        ClauseGuard::FieldAccess { label_location, index, label, container, .. } => json!({
            "kind": "field_access",
            "label_location": span(label_location),
            "index": opt(index, |i| json!(i)),
            "label": label,
            "container": clause_guard(container),
        }),
        ClauseGuard::Constant(c) => json!({ "kind": "constant", "constant": constant(c) }),
        ClauseGuard::ModuleSelect { .. } | ClauseGuard::Invalid { .. } => {
            panic!("the parser does not build this clause guard: {g:?}")
        }
    }
}

fn pattern(p: &Pattern<()>) -> Value {
    match p {
        Pattern::Int { location, value, int_value } => json!({
            "kind": "int", "location": span(location), "value": value, "int_value": int_value.to_string(),
        }),
        Pattern::Float { location, value, .. } => json!({ "kind": "float", "location": span(location), "value": value }),
        Pattern::String { location, value } => json!({ "kind": "string", "location": span(location), "value": value }),
        Pattern::Variable { location, name, .. } => json!({ "kind": "variable", "location": span(location), "name": name }),
        Pattern::BitArraySize(s) => json!({ "kind": "bit_array_size", "size": bit_array_size(s) }),
        Pattern::Assign { name, location, pattern: inner } => json!({
            "kind": "assign", "name": name, "location": span(location), "pattern": pattern(inner),
        }),
        Pattern::Discard { name, location, .. } => json!({ "kind": "discard", "name": name, "location": span(location) }),
        Pattern::List { location, elements, tail, .. } => json!({
            "kind": "list",
            "location": span(location),
            "elements": list(elements, pattern),
            "tail": opt(tail, |t: &Box<TailPattern<()>>| json!({ "location": span(&t.location), "pattern": pattern(&t.pattern) })),
        }),
        Pattern::Constructor { location, name_location, name, arguments, module, spread, .. } => json!({
            "kind": "constructor",
            "location": span(location),
            "name_location": span(name_location),
            "name": name,
            "arguments": list(arguments, |a| call_arg(a, pattern)),
            "module": opt(module, module_ref),
            "spread": opt(spread, span),
        }),
        Pattern::Tuple { location, elements } => json!({ "kind": "tuple", "location": span(location), "elements": list(elements, pattern) }),
        Pattern::BitArray { location, segments } => json!({
            "kind": "bit_array", "location": span(location), "segments": list(segments, |s| bit_array_segment(s, &pattern)),
        }),
        Pattern::StringPrefix { location, left_location, left_side_assignment, right_location, left_side_string, right_side_assignment } => json!({
            "kind": "string_prefix",
            "location": span(location),
            "left_location": span(left_location),
            "left_side_assignment": opt(left_side_assignment, |a| json!({
                "name": a.name, "name_start_position": a.name_start_position, "location": span(&a.location),
            })),
            "right_location": span(right_location),
            "left_side_string": left_side_string,
            "right_side_assignment": assign_name(right_side_assignment),
        }),
        Pattern::Invalid { .. } => panic!("the parser does not build Pattern::Invalid"),
    }
}

fn bit_array_size(s: &BitArraySize<()>) -> Value {
    match s {
        BitArraySize::Int { location, value, int_value } => json!({
            "kind": "int", "location": span(location), "value": value, "int_value": int_value.to_string(),
        }),
        BitArraySize::Variable { location, name, .. } => json!({ "kind": "variable", "location": span(location), "name": name }),
        BitArraySize::BinaryOperator { location, operator, left, right } => json!({
            "kind": "binary_operator",
            "location": span(location),
            "operator": int_operator(operator),
            "left": bit_array_size(left),
            "right": bit_array_size(right),
        }),
        BitArraySize::Block { location, inner } => json!({ "kind": "block", "location": span(location), "inner": bit_array_size(inner) }),
    }
}

fn constant(c: &Constant<()>) -> Value {
    match c {
        Constant::Int { location, value, int_value } => json!({
            "kind": "int", "location": span(location), "value": value, "int_value": int_value.to_string(),
        }),
        Constant::Float { location, value, .. } => json!({ "kind": "float", "location": span(location), "value": value }),
        Constant::String { location, value } => json!({ "kind": "string", "location": span(location), "value": value }),
        Constant::Tuple { location, elements, .. } => json!({ "kind": "tuple", "location": span(location), "elements": list(elements, constant) }),
        Constant::List { location, elements, tail, .. } => json!({
            "kind": "list", "location": span(location), "elements": list(elements, constant), "tail": opt(tail, |t| constant(t)),
        }),
        Constant::Record { location, arguments_start_position, module, name, arguments, .. } => json!({
            "kind": "record",
            "location": span(location),
            "arguments_start_position": arguments_start_position,
            "module": opt(module, module_ref),
            "name": name,
            "arguments": opt(arguments, |xs| list(xs, |a| call_arg(a, constant))),
        }),
        Constant::RecordUpdate { location, constructor_location, module, name, record, arguments, .. } => json!({
            "kind": "record_update",
            "location": span(location),
            "constructor_location": span(constructor_location),
            "module": opt(module, module_ref),
            "name": name,
            "record": record_being_updated(record, |b| constant(b)),
            "arguments": list(arguments, |a| record_update_arg(a, constant)),
        }),
        Constant::BitArray { location, segments } => json!({
            "kind": "bit_array", "location": span(location), "segments": list(segments, |s| bit_array_segment(s, &constant)),
        }),
        Constant::Var { location, module, name, .. } => json!({
            "kind": "var", "location": span(location), "module": opt(module, module_ref), "name": name,
        }),
        Constant::BinaryOperator { location, operator_start, operator, left, right, .. } => json!({
            "kind": "binary_operator",
            "location": span(location),
            "operator_start": operator_start,
            "operator": bin_op(operator),
            "left": constant(left),
            "right": constant(right),
        }),
        Constant::Todo { location, message, .. } => json!({ "kind": "todo", "location": span(location), "message": opt(message, |m| constant(m)) }),
        Constant::Invalid { .. } => panic!("the parser does not build Constant::Invalid"),
    }
}

fn extra(x: &ModuleExtra) -> Value {
    json!({
        "module_comments": list(&x.module_comments, span),
        "doc_comments": list(&x.doc_comments, span),
        "comments": list(&x.comments, span),
        "empty_lines": x.empty_lines,
        "new_lines": x.new_lines,
        "trailing_commas": x.trailing_commas,
    })
}

/// The parse-time warnings. Other warnings do not come from `parse_module`.
fn warning(w: &Warning) -> Option<Value> {
    match w {
        Warning::DeprecatedSyntax { warning, .. } => Some(match warning {
            DeprecatedSyntaxWarning::DeprecatedListPrepend { location } => json!({ "kind": "deprecated_list_prepend", "location": span(location) }),
            DeprecatedSyntaxWarning::DeprecatedListPattern { location } => json!({ "kind": "deprecated_list_pattern", "location": span(location) }),
            DeprecatedSyntaxWarning::DeprecatedListCatchAllPattern { location } => json!({ "kind": "deprecated_list_catch_all_pattern", "location": span(location) }),
            DeprecatedSyntaxWarning::DeprecatedListSpreadAsVariablePattern { location, name } => json!({ "kind": "deprecated_list_spread_as_variable_pattern", "location": span(location), "name": name }),
            DeprecatedSyntaxWarning::DeprecatedRecordSpreadPattern { location } => json!({ "kind": "deprecated_record_spread_pattern", "location": span(location) }),
            DeprecatedSyntaxWarning::DeprecatedEmptyClauseGuard { location } => json!({ "kind": "deprecated_empty_clause_guard", "location": span(location) }),
            DeprecatedSyntaxWarning::DeprecatedTargetShorthand { target: t, location } => json!({ "kind": "deprecated_target_shorthand", "target": target(t), "location": span(location) }),
        }),
        Warning::DetachedDocComment { location, .. } => Some(json!({ "kind": "detached_doc_comment", "location": span(location) })),
        _ => None,
    }
}
