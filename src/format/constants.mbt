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
  // The trailing comma is looked for after the tail, or after the last item
  // when there is no tail (`tail.or_else(items.last())`).
  let last_end = match tail {
    Some(tl) => Some(location_of(tl).end)
    None => items.last().map(l => location_of(l).end)
  }
  // The empty-line check ends at the last item, or at the tail when there
  // is no item (`items.last().or(tail)`).
  let last = match items.last() {
    Some(l) => Some(l)
    None => tail
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
  let has_empty_lines_between_elements = match (first, last) {
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
async fn[A] Formatter::format_call_arg(
  self : Formatter,
  argument : @ast.CallArg[A],
  value_location : (A) -> @span.SrcSpan,
  format_value : async (A) -> @pretty.Doc raise FormatError + nocancel,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn[A] Formatter::append_inlinable_wrapped_arguments(
  self : Formatter,
  doc : @pretty.Doc,
  values : Array[A],
  location : @span.SrcSpan,
  location_of : (A) -> @span.SrcSpan,
  is_breakable_argument : (A) -> Bool,
  to_doc : async (A) -> @pretty.Doc raise FormatError + nocancel,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::constant_call_arg(
  self : Formatter,
  argument : @ast.CallArg[@ast.Constant],
) -> @pretty.Doc raise FormatError + nocancel {
  self.format_call_arg(argument, c => c.location(), c => self.const_expr(c))
}

///|
/// The compiler's `comma_separated_constant_item`.
async fn Formatter::comma_separated_constant_item(
  self : Formatter,
  constant : @ast.Constant,
  siblings : Int32,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::append_as_message_constant(
  self : Formatter,
  doc : @pretty.Doc,
  message : @ast.Constant?,
) -> @pretty.Doc raise FormatError + nocancel {
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
/// The compiler's `constant_binary_operator`, with the left spine walked
/// in a loop (see `bin_op`).
async fn Formatter::constant_binary_operator(
  self : Formatter,
  name : @ast.BinOp,
  left : @ast.Constant,
  right : @ast.Constant,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError + nocancel {
  let ops = [name]
  let rights = [right]
  let mut leaf = left
  while leaf is BinaryOperator(operator~, left=l, right=r, ..) {
    ops.push(operator)
    rights.push(r)
    leaf = l
  }
  let n = ops.length() - 1
  let mut doc = self.constant_binary_operator_side(ops[n], leaf, nest_steps)
  for k = n; k >= 0; k = k - 1 {
    let comments = self.pop_comments(rights[k].location().start)
    let name_doc = breakable_space + commented(binop(ops[k]), comments[:])
    let right_side = self.constant_binary_operator_side(
      ops[k],
      rights[k],
      nest_steps,
    )
    doc = doc +
      (if nest_steps { nest(name_doc) } else { name_doc }) +
      t(" ") +
      right_side
    if k > 0 {
      doc = if can_be_grouped_with(ops[k], ops[k - 1]) {
        doc
      } else {
        operator_side(group(doc), precedence(ops[k - 1]), precedence(ops[k]))
      }
    }
  }
  doc
}

///|
/// The compiler's `constant_binary_operator_side`.
async fn Formatter::constant_binary_operator_side(
  self : Formatter,
  operator : @ast.BinOp,
  side : @ast.Constant,
  nest_steps : Bool,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::constant_record_update_argument(
  self : Formatter,
  argument : @ast.RecordUpdateArg[@ast.Constant],
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::const_record_update(
  self : Formatter,
  module_ : @ast.SpannedString?,
  name : String,
  record : @ast.RecordBeingUpdated[@ast.Constant],
  arguments : ArrayView[@ast.RecordUpdateArg[@ast.Constant]],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::const_list(
  self : Formatter,
  elements : ArrayView[@ast.Constant],
  location : @span.SrcSpan,
  tail : @ast.Constant?,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::const_tuple(
  self : Formatter,
  elements : ArrayView[@ast.Constant],
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::const_expr(
  self : Formatter,
  value : @ast.Constant,
) -> @pretty.Doc raise FormatError + nocancel {
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
async fn Formatter::module_constant(
  self : Formatter,
  c : @ast.ModuleConstant,
) -> @pretty.Doc raise FormatError + nocancel {
  let attrs = attributes(c.deprecation, c.publicity, None, None)
  // The compiler counts `const ` as 5 columns (its CONST_SPACE_DOCUMENT
  // declares 5), so the space has no width here.
  let head = attrs +
    pub_(c.publicity) +
    t("const") +
    @pretty.zero_width(" ") +
    t(c.name)
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
