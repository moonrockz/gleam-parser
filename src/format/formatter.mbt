///|
/// A comment as the compiler's `Comment`: the byte offset after the
/// slashes and the text after them.
priv struct Comment {
  start : @span.ByteOffset
  content : String
}

///|
/// What `pop_comments` returns: a comment's text, or an empty line between
/// comments (the compiler's `Option<&str>`).
priv enum CommentOrLine {
  Text(String)
  EmptyLine
}

///|
/// The compiler's `Formatter`: the comment arrays of `ModuleExtra` with a
/// cursor each (the compiler pops slices; a cursor only moves forward),
/// the new-line and trailing-comma positions (searched, never popped) and
/// the fuel of the current nesting level.
priv struct Formatter {
  comments : Array[Comment]
  doc_comments : Array[Comment]
  module_comments : Array[Comment]
  empty_lines : ArrayView[@span.ByteOffset]
  new_lines : ArrayView[@span.ByteOffset]
  trailing_commas : ArrayView[@span.ByteOffset]
  mut comments_at : Int32
  mut doc_comments_at : Int32
  mut empty_lines_at : Int32
  fuel : Ref[@fuel.Fuel]
}

///|
let op_format : @fuel.Operation = @fuel.Operation("format")

///|
fn comments_of(
  spans : ArrayView[@span.SrcSpan],
  source : @scanner.SourceText,
) -> Array[Comment] {
  spans
  .iter()
  .map(span => { start: span.start, content: source.slice(span).unwrap_or(""), })
  .to_array()
}

///|
fn Formatter::Formatter(
  extra : @ast.ModuleExtra,
  source : @scanner.SourceText,
  config : @config.Config,
) -> Formatter {
  {
    comments: comments_of(extra.comments, source),
    doc_comments: comments_of(extra.doc_comments, source),
    module_comments: comments_of(extra.module_comments, source),
    empty_lines: extra.empty_lines,
    new_lines: extra.new_lines,
    trailing_commas: extra.trailing_commas,
    comments_at: 0,
    doc_comments_at: 0,
    empty_lines_at: 0,
    fuel: { val: @fuel.Fuel(budget=config.fuel), },
  }
}

///|
/// Run `body` one nesting level deeper: one unit of fuel for `op`.
fn[A] Formatter::nested(
  self : Formatter,
  op : @fuel.Operation,
  body : () -> A raise FormatError,
) -> A raise FormatError {
  let inner = self.fuel.val.spend(op) catch { e => raise OutOfFuel(e) }
  self.fuel.protect(inner, body)
}

///|
/// The compiler's `any_comments`: a comment not popped yet starts before
/// `limit`.
fn Formatter::any_comments(self : Formatter, limit : @span.ByteOffset) -> Bool {
  self.comments_at < self.comments.length() &&
  self.comments[self.comments_at].start < limit
}

///|
/// The compiler's `any_comment_between`: a comment not popped yet starts
/// in `start..=end`.
fn Formatter::any_comment_between(
  self : Formatter,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
) -> Bool {
  let mut lo = self.comments_at
  let mut hi = self.comments.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let c = self.comments[mid].start
    if c < start {
      lo = mid + 1
    } else if c > end {
      hi = mid - 1
    } else {
      return true
    }
  }
  false
}

///|
fn Formatter::any_empty_lines(
  self : Formatter,
  limit : @span.ByteOffset,
) -> Bool {
  self.empty_lines_at < self.empty_lines.length() &&
  self.empty_lines[self.empty_lines_at] < limit
}

///|
/// The compiler's `comments_before`: the comments and (when `retain`) the
/// coalesced empty lines before `limit`, merged by position, without
/// leading empty lines; the cursors move past them.
fn Formatter::comments_before(
  self : Formatter,
  doc : Bool,
  limit : @span.ByteOffset,
  retain_empty_lines : Bool,
) -> Array[(@span.ByteOffset, CommentOrLine)] {
  let (comments, at) = if doc {
    (self.doc_comments, self.doc_comments_at)
  } else {
    (self.comments, self.comments_at)
  }
  let mut end_comments = at
  while end_comments < comments.length() &&
        comments[end_comments].start <= limit {
    end_comments += 1
  }
  let mut end_empty = self.empty_lines_at
  while end_empty < self.empty_lines.length() &&
        self.empty_lines[end_empty] <= limit {
    end_empty += 1
  }
  // Coalesce consecutive empty lines into one (position = the first).
  let lines : Array[@span.ByteOffset] = []
  if retain_empty_lines {
    let mut i = self.empty_lines_at
    while i < end_empty {
      let start = self.empty_lines[i]
      let mut last = start
      while i + 1 < end_empty &&
            self.empty_lines[i + 1] == last.shift(1).unwrap() {
        i += 1
        last = self.empty_lines[i]
      }
      lines.push(start)
      i += 1
    }
  }
  // Merge by position: a comment goes first when its position is smaller.
  let popped : Array[(@span.ByteOffset, CommentOrLine)] = []
  let mut c = at
  let mut l = 0
  while c < end_comments || l < lines.length() {
    if l >= lines.length() || (c < end_comments && comments[c].start < lines[l]) {
      popped.push((comments[c].start, Text(comments[c].content)))
      c += 1
    } else {
      popped.push((lines[l], EmptyLine))
      l += 1
    }
  }
  // Drop leading empty lines (`skip_while(is_none)`).
  let mut first = 0
  while first < popped.length() && popped[first].1 is EmptyLine {
    first += 1
  }
  if doc {
    self.doc_comments_at = end_comments
  } else {
    self.comments_at = end_comments
  }
  self.empty_lines_at = end_empty
  popped[first:].to_owned()
}

///|
fn Formatter::pop_comments_with_position(
  self : Formatter,
  limit : @span.ByteOffset,
) -> Array[(@span.ByteOffset, CommentOrLine)] {
  self.comments_before(false, limit, true)
}

///|
fn Formatter::pop_comments(
  self : Formatter,
  limit : @span.ByteOffset,
) -> Array[CommentOrLine] {
  self.pop_comments_with_position(limit).map(p => p.1)
}

///|
/// Doc comments before `limit`; the empty lines before it are dropped.
fn Formatter::pop_doc_comments(
  self : Formatter,
  limit : @span.ByteOffset,
) -> Array[String] {
  let out = []
  for p in self.comments_before(true, limit, false) {
    if p.1 is Text(c) {
      out.push(c)
    }
  }
  out
}

///|
/// Move past the empty lines up to `limit`; whether there was one.
fn Formatter::pop_empty_lines(
  self : Formatter,
  limit : @span.ByteOffset,
) -> Bool {
  let before = self.empty_lines_at
  while self.empty_lines_at < self.empty_lines.length() &&
        self.empty_lines[self.empty_lines_at] <= limit {
    self.empty_lines_at += 1
  }
  self.empty_lines_at != before
}

///|
/// A line feed strictly between `start` and `end`.
fn Formatter::spans_multiple_lines(
  self : Formatter,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
) -> Bool {
  let mut lo = 0
  let mut hi = self.new_lines.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let n = self.new_lines[mid]
    if n <= start {
      lo = mid + 1
    } else if n >= end {
      hi = mid - 1
    } else {
      return true
    }
  }
  false
}

///|
/// A trailing comma in `start..=end`.
fn Formatter::has_trailing_comma(
  self : Formatter,
  start : @span.ByteOffset,
  end : @span.ByteOffset,
) -> Bool {
  let mut lo = 0
  let mut hi = self.trailing_commas.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let c = self.trailing_commas[mid]
    if c < start {
      lo = mid + 1
    } else if c > end {
      hi = mid - 1
    } else {
      return true
    }
  }
  false
}

///|
/// The compiler's `targeted_definition`.
fn Formatter::targeted_definition(
  self : Formatter,
  definition : @ast.TargetedDefinition,
) -> @pretty.Doc raise FormatError {
  let start = definition.definition.location().start
  let comments = self.pop_comments_with_position(start)
  let comments = self.printed_documented_comments(comments[:])
  let document = self.documented_definition(definition.definition)
  let document = match definition.target {
    None => document
    Some(Erlang) => t("@target(erlang)") + line_doc + document
    Some(JavaScript) => t("@target(javascript)") + line_doc + document
  }
  let document = group(document)
  match comments {
    Some(c) => c + document
    None => document
  }
}

///|
/// The compiler's `documented_definition`.
fn Formatter::documented_definition(
  self : Formatter,
  definition : @ast.Definition,
) -> @pretty.Doc raise FormatError {
  let comments = self.doc_comments(definition.location().start)
  group(comments + group(self.definition(definition)))
}

///|
/// The compiler's `definition`.
fn Formatter::definition(
  self : Formatter,
  definition : @ast.Definition,
) -> @pretty.Doc raise FormatError {
  match definition {
    Function(f) => self.statement_fn(f)
    TypeAlias(a) => self.type_alias(a)
    CustomType(c) => self.custom_type(c)
    Import(i) => import_(i)
    ModuleConstant(c) => self.module_constant(c)
  }
}

///|
/// The compiler's `module` (`module` is a reserved word).
fn Formatter::format_module(
  self : Formatter,
  module_ : @ast.Module,
) -> @pretty.Doc raise FormatError {
  let documents : Array[@pretty.Doc] = []
  let mut previous_was_a_definition = false
  // Consecutive imports form one chunk (`chunk_by(is_import)`).
  let mut i = 0
  let defs = module_.definitions
  while i < defs.length() {
    let is_import_group = defs[i].definition is Import(_)
    let chunk : Array[@ast.TargetedDefinition] = []
    while i < defs.length() &&
          (defs[i].definition is Import(_)) == is_import_group {
      chunk.push(defs[i])
      i += 1
    }
    if is_import_group {
      if previous_was_a_definition {
        documents.push(two_lines_doc)
      }
      for d in self.imports(chunk) {
        documents.push(d)
      }
      previous_was_a_definition = false
    } else {
      for definition in chunk {
        if !documents.is_empty() {
          documents.push(two_lines_doc)
        }
        documents.push(self.targeted_definition(definition))
      }
      previous_was_a_definition = true
    }
  }
  let definitions = if documents.is_empty() {
    None
  } else {
    Some(@pretty.concat(documents))
  }
  // Only freestanding comments and doc comments remain: they go at the end.
  let doc_comments = if self.doc_comments_at < self.doc_comments.length() {
    let rest = self.doc_comments[self.doc_comments_at:]
    Some(
      @pretty.join(
        rest.map(c => t("///") + @pretty.zero_width(c.content)),
        line_doc,
      ),
    )
  } else {
    None
  }
  let comments = printed_comments(
    self.pop_comments(@span.ByteOffset::from_int(0x7fffffff).unwrap())[:],
    false,
  )
  let module_comments = if self.module_comments.is_empty() {
    None
  } else {
    let lines = self.module_comments.map(c => {
      t("////") + @pretty.zero_width(c.content)
    })
    Some(@pretty.join(lines, line_doc) + line_doc)
  }
  let non_empty : Array[@pretty.Doc] = []
  for part in [module_comments, definitions, doc_comments, comments] {
    if part is Some(d) {
      non_empty.push(d)
    }
  }
  @pretty.join(non_empty, line_doc) + line_doc
}
