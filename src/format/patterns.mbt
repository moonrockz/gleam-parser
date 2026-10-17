///|
fn is_discard(p : @ast.Pattern) -> Bool {
  p is Discard(..)
}

///|
/// The compiler's `pattern_constructor`.
async fn Formatter::pattern_constructor(
  self : Formatter,
  name : String,
  arguments : ArrayView[@ast.CallArg[@ast.Pattern]],
  module_ : @ast.SpannedString?,
  spread : @span.SrcSpan?,
  location : @span.SrcSpan,
) -> @pretty.Doc raise FormatError + nocancel {
  let is_breakable = (p : @ast.Pattern) => {
    match p {
      Tuple(..) | List(..) | BitArray(..) => true
      Constructor(arguments~, ..) => !arguments.is_empty()
      _ => false
    }
  }
  let name_doc = match module_ {
    Some(m) => t(m.name) + t(".") + t(name)
    None => t(name)
  }
  if arguments.is_empty() && spread is Some(_) {
    name_doc + t("(..)")
  } else if arguments.is_empty() {
    name_doc
  } else if spread is Some(_) {
    let docs = []
    for a in arguments {
      docs.push(self.pattern_call_arg(a))
    }
    group(name_doc + self.wrap_arguments_with_spread(docs, location.end))
  } else if arguments.length() == 1 && is_breakable(arguments[0].value) {
    group(name_doc + t("(") + self.pattern_call_arg(arguments[0]) + t(")"))
  } else {
    let docs = []
    for a in arguments {
      docs.push(self.pattern_call_arg(a))
    }
    group(name_doc + self.wrap_arguments(docs, location.end))
  }
}

///|
/// The compiler's `pattern`. One unit of fuel per nesting level.
async fn Formatter::pattern(
  self : Formatter,
  pattern : @ast.Pattern,
) -> @pretty.Doc raise FormatError + nocancel {
  self.nested(op_format, () => {
    let comments = self.pop_comments(pattern.location().start)
    let doc = match pattern {
      Int(value~, ..) => int(value)
      Float(value~, ..) => float(value)
      String(value~, ..) => string(value)
      Variable(name~, ..) => t(name)
      BitArraySize(size) => self.bit_array_size(size)
      Assign(name~, pattern~, ..) =>
        if is_discard(pattern) {
          t(name)
        } else {
          self.pattern(pattern) + t(" as ") + t(name)
        }
      Discard(name~, ..) => t(name)
      List(elements~, tail~, ..) => self.list_pattern(elements, tail)
      Constructor(name~, arguments~, module_~, spread~, location~, ..) =>
        self.pattern_constructor(name, arguments, module_, spread, location)
      Tuple(elements~, location~) => {
        let docs = []
        for e in elements {
          docs.push(self.pattern(e))
        }
        group(t("#") + self.wrap_arguments(docs, location.end))
      }
      BitArray(segments~, location~) => {
        let docs = []
        for s in segments {
          docs.push(bit_array_segment(s, p => self.pattern(p)))
        }
        self.bit_array(docs, FitOnePerLine, location)
      }
      StringPrefix(
        left_side_string~,
        right_side_assignment~,
        left_side_assignment~,
        ..
      ) => {
        let left = string(left_side_string)
        let right = match right_side_assignment {
          Variable(name) | Discard(name) => t(name)
        }
        match left_side_assignment {
          Some(a) => left + t(" as ") + t(a.name) + t(" <> ") + right
          None => left + t(" <> ") + right
        }
      }
    }
    commented(doc, comments[:])
  })
}

///|
/// The compiler's `bit_array_size`.
async fn Formatter::bit_array_size(
  self : Formatter,
  size : @ast.BitArraySize,
) -> @pretty.Doc raise FormatError + nocancel {
  self.nested(op_format, () => {
    match size {
      Int(value~, ..) => int(value)
      Variable(name~, ..) => t(name)
      BinaryOperator(left~, right~, operator~, ..) => {
        // The left spine in a loop: the parser accepts a chain of any
        // length, so no fuel and no stack per link.
        let ops = [operator]
        let rights = [right]
        let mut leaf = left
        while leaf is BinaryOperator(operator=o, left=l, right=r, ..) {
          ops.push(o)
          rights.push(r)
          leaf = l
        }
        let mut doc = self.bit_array_size(leaf)
        for k = ops.length() - 1; k >= 0; k = k - 1 {
          let op = match ops[k] {
            Add => t(" + ")
            Subtract => t(" - ")
            Multiply => t(" * ")
            Divide => t(" / ")
            Remainder => t(" % ")
          }
          doc = doc + op + self.bit_array_size(rights[k])
        }
        doc
      }
      Block(inner~, ..) => t("{ ") + self.bit_array_size(inner) + t(" }")
    }
  })
}

///|
/// The compiler's `list_pattern`.
async fn Formatter::list_pattern(
  self : Formatter,
  elements : ArrayView[@ast.Pattern],
  tail : @ast.TailPattern?,
) -> @pretty.Doc raise FormatError + nocancel {
  if elements.is_empty() {
    return match tail {
      Some(tl) => self.pattern(tl.pattern)
      None => t("[]")
    }
  }
  let docs = []
  for e in elements {
    docs.push(self.pattern(e))
  }
  let doc = open_square_break + @pretty.join(docs, comma_break)
  let doc = match tail {
    None => nest(doc) + trailing_comma_break
    Some(tl) => {
      let comments = self.pop_comments(tl.pattern.location().start)
      let tail_doc = if is_discard(tl.pattern) {
        t("..")
      } else {
        t("..") + self.pattern(tl.pattern)
      }
      let tail_doc = commented(tail_doc, comments[:])
      nest(doc + comma_break + tail_doc) + empty_break
    }
  }
  group(doc + t("]"))
}

///|
/// The compiler's `pattern_call_arg`.
async fn Formatter::pattern_call_arg(
  self : Formatter,
  argument : @ast.CallArg[@ast.Pattern],
) -> @pretty.Doc raise FormatError + nocancel {
  self.format_call_arg(argument, p => p.location(), p => self.pattern(p))
}
