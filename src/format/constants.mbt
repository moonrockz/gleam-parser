///|
fn can_have_multiple_per_line(c : @ast.Constant) -> Bool {
  match c {
    Int(..) | Float(..) | String(..) | Var(..) => true
    Tuple(..)
    | Todo(..)
    | List(..)
    | Record(..)
    | RecordUpdate(..)
    | BitArray(..)
    | BinaryOperator(..) => false
  }
}

///|
fn is_constant_breakable_argument(c : @ast.Constant) -> Bool {
  match c {
    Tuple(..) | List(..) | BitArray(..) => true
    _ => false
  }
}

///|
fn is_tuple(c : @ast.Constant) -> Bool {
  c is Tuple(..)
}

///|
fn is_binop(c : @ast.Constant) -> Bool {
  c is BinaryOperator(..)
}

///|
fn bin_op_name(c : @ast.Constant) -> @ast.BinOp? {
  match c {
    BinaryOperator(operator~, ..) => Some(operator)
    _ => None
  }
}

///|
fn bin_op_precedence(c : @ast.Constant) -> Int32 {
  match c {
    BinaryOperator(operator~, ..) => precedence(operator)
    _ => max_precedence
  }
}

///|
/// The compiler's `items_sequence_packing`.
fn[A] Formatter::items_sequence_packing(
  self : Formatter,
  items : ArrayView[A],
  tail : A?,
  location_of : (A) -> @span.SrcSpan,
  can_have_multiple_per_line : (A) -> Bool,
  list_location : @span.SrcSpan,
) -> ItemsPacking {
  let last_end = match tail {
    Some(tl) => Some(location_of(tl).end)
    None => items.last().map(l => location_of(l).end)
  }
  let ends_with_trailing_comma = match last_end {
    Some(end) => self.has_trailing_comma(end, list_location.end)
    None => false
  }
  let all = items.to_owned()
  if tail is Some(tl) {
    all.push(tl)
  }
  let has_multiple_elements_per_line = self.has_items_on_the_same_line(
    all, location_of,
  )
  let first = if items.length() > 0 { Some(items[0]) } else { None }
  let has_empty_lines_between_elements = match (first, all.last()) {
    (Some(first), Some(last)) =>
      self.empty_lines_at < self.empty_lines.length() &&
      self.empty_lines[self.empty_lines_at] >= location_of(first).end &&
      self.empty_lines[self.empty_lines_at] < location_of(last).start
    _ => false
  }
  if has_empty_lines_between_elements {
    BreakOnePerLine
  } else if !ends_with_trailing_comma {
    FitOnePerLine
  } else if tail is None &&
    items.iter().all(can_have_multiple_per_line) &&
    has_multiple_elements_per_line &&
    self.spans_multiple_lines(list_location.start, list_location.end) {
    FitMultiplePerLine
  } else {
    BreakOnePerLine
  }
}

///|
/// The compiler's `has_items_on_the_same_line`.
fn[A] Formatter::has_items_on_the_same_line(
  self : Formatter,
  items : Array[A],
  location_of : (A) -> @span.SrcSpan,
) -> Bool {
  let mut previous : @span.SrcSpan? = None
  for item in items {
    let loc = location_of(item)
    if previous is Some(p) && !self.spans_multiple_lines(p.end, loc.start) {
      return true
    }
    previous = Some(loc)
  }
  false
}

///|
/// The compiler's `format_call_arg`.
fn[A] Formatter::format_call_arg(
  self : Formatter,
  argument : @ast.CallArg[A],
  value_location : (A) -> @span.SrcSpan,
  format_value : (A) -> @pretty.Doc raise FormatError,
) -> @pretty.Doc raise FormatError {
  let shorthand = argument.implicit is None &&
    argument.location == value_location(argument.value)
  match (shorthand, argument.label) {
    (true, Some(label)) => {
      let comments = self.pop_comments(argument.location.start)
      commented(t(label) + t(":"), comments[:])
    }
    (_, Some(label)) => {
      let comments = self.pop_comments(argument.location.start)
      let value = format_value(argument.value)
      commented(t(label) + t(": "), comments[:]) + value
    }
    (_, None) => format_value(argument.value)
  }
}

///|
/// The compiler's `append_inlinable_wrapped_arguments`.
fn[A] Formatter::append_inlinable_wrapped_arguments(
  self : Formatter,
  doc : @pretty.Doc,
  values : Array[A],
  location : @span.SrcSpan,
  location_of : (A) -> @span.SrcSpan,
  is_breakable_argument : (A) -> Bool,
  to_doc : (A) -> @pretty.Doc raise FormatError,
) -> @pretty.Doc raise FormatError {
  match values.last() {
    Some(last) if is_breakable_argument(last) &&
      !self.any_comments(location_of(last).start) &&
      !self.any_comment_between(location_of(last).end, location.end) => {
      let docs = []
      for v in values[:values.length() - 1] {
        docs.push(to_doc(v))
      }
      docs.push(@pretty.next_break_fits(group(to_doc(last)), Enabled))
      group(
        @pretty.next_break_fits(
          doc + self.wrap_function_call_arguments(docs, location),
          Disabled,
        ),
      )
    }
    _ => {
      let docs = []
      for v in values {
        docs.push(to_doc(v))
      }
      group(doc + self.wrap_function_call_arguments(docs, location))
    }
  }
}

///|
/// The compiler's `constant_call_arg`.
fn Formatter::constant_call_arg(
  self : Formatter,
  argument : @ast.CallArg[@ast.Constant],
) -> @pretty.Doc raise FormatError {
  self.format_call_arg(argument, c => c.location(), c => self.const_expr(c))
}

///|
/// The compiler's `comma_separated_constant_item`.
fn Formatter::comma_separated_constant_item(
  self : Formatter,
  constant : @ast.Constant,
  siblings : Int32,
) -> @pretty.Doc raise FormatError {
  match constant {
    BinaryOperator(operator~, left~, right~, ..) if siblings > 1 => {
      let comments = self.pop_comments(constant.location().start)
      let doc = group(
        self.constant_binary_operator(operator, left, right, true),
      )
      commented(doc, comments[:])
    }
    _ => group(self.const_expr(constant))
  }
}

///|
/// The compiler's `append_as_message_constant`.
fn Formatter::append_as_message_constant(
  self : Formatter,
  doc : @pretty.Doc,
  message : @ast.Constant?,
) -> @pretty.Doc raise FormatError {
  guard message is Some(message) else { return doc }
  let comments = self.pop_comments(message.location().start)
  let doc = match printed_comments(comments[:], false) {
    Some(c) =>
      group(doc) +
      t(" as") +
      nest(line_doc + c + line_doc + group(self.const_expr(message)))
    None => group(doc) + t(" as ") + nest(group(self.const_expr(message)))
  }
  group(doc)
}

///|
/// The compiler's `constant_binary_operator`.
fn Formatter::constant_binary_operator(
  self : Formatter,
  name : @ast.BinOp,
  left : @ast.Constant,
  right : @ast.Constant,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError {
  let left_side = self.constant_binary_operator_side(name, left, nest_steps)
  let comments = self.pop_comments(right.location().start)
  let name_doc = breakable_space + commented(binop(name), comments[:])
  let right_side = self.constant_binary_operator_side(name, right, nest_steps)
  left_side +
  (if nest_steps { nest(name_doc) } else { name_doc }) +
  t(" ") +
  right_side
}

///|
/// The compiler's `constant_binary_operator_side`.
fn Formatter::constant_binary_operator_side(
  self : Formatter,
  operator : @ast.BinOp,
  side : @ast.Constant,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError {
  let side_doc = match side {
    String(value~, ..) => bin_op_string(value)
    BinaryOperator(operator~, left~, right~, ..) =>
      self.constant_binary_operator(operator, left, right, nest_steps)
    _ => self.const_expr(side)
  }
  match bin_op_name(side) {
    Some(side_name) if can_be_grouped_with(side_name, operator) => side_doc
    _ =>
      operator_side(
        group(side_doc),
        precedence(operator),
        bin_op_precedence(side),
      )
  }
}

///|
/// The compiler's `constant_record_update_argument`.
fn Formatter::constant_record_update_argument(
  self : Formatter,
  argument : @ast.RecordUpdateArg[@ast.Constant],
) -> @pretty.Doc raise FormatError {
  let comments = self.pop_comments(argument.location.start)
  if argument.location == argument.value.location() {
    commented(t(argument.label) + t(":"), comments[:])
  } else {
    let doc = group(
      t(argument.label) + t(": ") + self.const_expr(argument.value),
    )
    if is_binop(argument.value) {
      nest(commented(doc, comments[:]))
    } else {
      commented(doc, comments[:])
    }
  }
}

///|
/// A piece of a constant record update: the record or one argument.
priv enum ConstUpdatePiece {
  Record(@ast.RecordBeingUpdated[@ast.Constant])
  Argument(@ast.RecordUpdateArg[@ast.Constant])
}

///|
fn ConstUpdatePiece::location(self : ConstUpdatePiece) -> @span.SrcSpan {
  match self {
    Record(r) => r.location
    Argument(a) => a.location
  }
}

///|
/// The compiler's `const_record_update`.
fn Formatter::const_record_update(
  self : Formatter,
  module_ : @ast.SpannedString?,
  name : String,
  record : @ast.RecordBeingUpdated[@ast.Constant],
  arguments : ArrayView[@ast.RecordUpdateArg[@ast.Constant]],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  let constructor_doc = match module_ {
    Some(m) => t(m.name) + t(".") + t(name)
    None => t(name)
  }
  let pieces : Array[ConstUpdatePiece] = [Record(record)]
  for a in arguments {
    pieces.push(Argument(a))
  }
  self.append_inlinable_wrapped_arguments(
    constructor_doc,
    pieces,
    location,
    p => p.location(),
    p => {
      match p {
        Argument(a) => is_constant_breakable_argument(a.value)
        Record(r) => is_constant_breakable_argument(r.base)
      }
    },
    p => {
      match p {
        Argument(a) => self.constant_record_update_argument(a)
        Record(r) => {
          let comments = self.pop_comments(r.location.start)
          commented(t("..") + self.const_expr(r.base), comments[:])
        }
      }
    },
  )
}

///|
/// The compiler's `const_list`.
fn Formatter::const_list(
  self : Formatter,
  elements : ArrayView[@ast.Constant],
  location : @span.SrcSpan,
  tail : @ast.Constant?,
) -> @pretty.Doc raise FormatError {
  if elements.is_empty() {
    let comments = self.pop_comments(location.end)
    return match printed_comments(comments[:], false) {
      None => t("[]")
      Some(c) =>
        @pretty.force_break(
          t("[") + nest(empty_break) + c + empty_break + t("]"),
        )
    }
  }
  let packing = self.items_sequence_packing(
    elements,
    tail,
    c => c.location(),
    can_have_multiple_per_line,
    location,
  )
  let comma = match packing {
    FitMultiplePerLine => flex_comma
    FitOnePerLine | BreakOnePerLine => comma_break
  }
  let list_size = elements.length() + (if tail is Some(_) { 1 } else { 0 })
  let mut is_empty = true
  let mut elements_doc = @pretty.empty()
  for element in elements {
    let empty_lines = self.pop_empty_lines(element.location().start)
    let element_doc = self.comma_separated_constant_item(element, list_size)
    elements_doc = if is_empty {
      is_empty = false
      element_doc
    } else if empty_lines {
      elements_doc + @pretty.set_nesting(0, comma) + line_doc + element_doc
    } else {
      elements_doc + comma + element_doc
    }
  }
  let elements_doc = @pretty.next_break_fits(elements_doc, Disabled)
  let doc = open_square_break + elements_doc
  let (doc, final_break) = match tail {
    None => (nest(doc), trailing_comma_break)
    Some(tl) => {
      let comments = self.pop_comments(tl.location().start)
      let tail_doc = commented(t("..") + self.const_expr(tl), comments[:])
      (nest(doc + comma_break + tail_doc), empty_break)
    }
  }
  let comments = self.pop_comments(location.end)
  let doc = match printed_comments(comments[:], false) {
    None => doc + final_break + t("]")
    Some(c) =>
      @pretty.force_break(doc + nest(final_break) + nest(c) + line_doc + t("]"))
  }
  match packing {
    FitOnePerLine | FitMultiplePerLine => group(doc)
    BreakOnePerLine => @pretty.force_break(doc)
  }
}

///|
/// The compiler's `const_tuple`.
fn Formatter::const_tuple(
  self : Formatter,
  elements : ArrayView[@ast.Constant],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError {
  if elements.is_empty() {
    let comments = self.pop_comments(location.end)
    return match printed_comments(comments[:], false) {
      None => t("#()")
      Some(c) =>
        @pretty.force_break(
          t("#(") + nest(empty_break) + c + empty_break + t(")"),
        )
    }
  }
  let n = elements.length()
  self.append_inlinable_wrapped_arguments(
    t("#"),
    elements.to_owned(),
    location,
    c => c.location(),
    c => !is_tuple(c) && is_constant_breakable_argument(c),
    c => self.comma_separated_constant_item(c, n),
  )
}

///|
/// The compiler's `const_expr`. One unit of fuel per nesting level.
fn Formatter::const_expr(
  self : Formatter,
  value : @ast.Constant,
) -> @pretty.Doc raise FormatError {
  self.nested(op_format, () => {
    let comments = self.pop_comments(value.location().start)
    let document = match value {
      Todo(message~, ..) => self.append_as_message_constant(t("todo"), message)
      Int(value~, ..) => int(value)
      Float(value~, ..) => float(value)
      String(value~, ..) => string(value)
      List(elements~, location~, tail~) =>
        self.const_list(elements, location, tail)
      Tuple(elements~, location~) => self.const_tuple(elements, location)
      BitArray(segments~, location~) => {
        let segment_docs = []
        for s in segments {
          segment_docs.push(bit_array_segment(s, c => self.const_expr(c)))
        }
        let packing = self.items_sequence_packing(
          segments,
          None,
          s => s.location,
          s => can_have_multiple_per_line(s.value),
          location,
        )
        self.bit_array(segment_docs, packing, location)
      }
      Record(name~, arguments~, module_~, location~, ..) => {
        let head = match module_ {
          None => t(name)
          Some(m) => t(m.name) + t(".") + t(name)
        }
        match arguments {
          None => head
          Some(arguments) => {
            let docs = []
            for a in arguments {
              docs.push(self.constant_call_arg(a))
            }
            group(head + self.wrap_arguments(docs, location.end))
          }
        }
      }
      Var(name~, module_~, ..) =>
        match module_ {
          None => t(name)
          Some(m) => t(m.name) + t(".") + t(name)
        }
      BinaryOperator(operator~, left~, right~, ..) =>
        self.constant_binary_operator(operator, left, right, false)
      RecordUpdate(module_~, name~, record~, arguments~, location~, ..) =>
        self.const_record_update(module_, name, record, arguments, location)
    }
    commented(document, comments[:])
  })
}

///|
/// The constant arm of the compiler's `definition`.
fn Formatter::module_constant(
  self : Formatter,
  c : @ast.ModuleConstant,
) -> @pretty.Doc raise FormatError {
  let attrs = attributes(c.deprecation, c.publicity, None, None)
  let head = attrs + pub_(c.publicity) + t("const ") + t(c.name)
  let head = match c.annotation {
    None => head
    Some(type_) => head + t(": ") + self.type_ast(type_)
  }
  let value = match c.value {
    List(..) | Tuple(..) | BitArray(..) => {
      let expression_comments = self.pop_comments(c.value.location().start)
      let expression_doc = self.const_expr(c.value)
      match printed_comments(expression_comments[:], true) {
        Some(comments) => nest(line_doc + comments + expression_doc)
        None => t(" ") + expression_doc
      }
    }
    _ => nest(breakable_space + group(self.const_expr(c.value)))
  }
  let value = group(@pretty.next_break_fits(value, Disabled))
  head + t(" =") + value
}
