///|
/// A half-open UTF-8 byte range, or the compiler's EOF location.
/// Fields are readable. Only validated constructors can create a span.
pub struct SrcSpan {
  start : ByteOffset
  end : ByteOffset
} derive(Eq, Debug, Hash)

///|
/// Create an ordered range from raw byte offsets.
/// Return `None` for negative offsets or an end before the start.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.SrcSpan::new(3, 2), content="None")
///   let span = @span.SrcSpan::new(2, 5).unwrap()
///   debug_inspect(span.length().map(n => n.to_int()), content="Some(3)")
/// }
/// ```
pub fn SrcSpan::new(start : Int32, end : Int32) -> SrcSpan? {
  match (ByteOffset::new(start), ByteOffset::new(end)) {
    (Some(start), Some(end)) => SrcSpan::between(start, end)
    _ => None
  }
}

///|
/// Create an ordered range. Return `None` when the end precedes the start.
pub fn SrcSpan::between(start : ByteOffset, end : ByteOffset) -> SrcSpan? {
  if start <= end {
    Some({ start, end, })
  } else {
    None
  }
}

///|
/// Create the compiler's `start..0` location.
/// A positive start gives a reversed EOF sentinel with no byte length.
/// At zero, this is the empty range `0..0`, as in the compiler.
///
/// ```mbt check
/// test {
///   let location = @span.SrcSpan::eof(@span.ByteOffset::new(5).unwrap())
///   assert_eq(location.is_eof(), true)
///   assert_eq(location.length(), None)
/// }
/// ```
pub fn SrcSpan::eof(start : ByteOffset) -> SrcSpan {
  { start, end: ByteOffset::zero(), }
}

///|
/// Import compiler offsets. A reversed `start..0` is an EOF sentinel.
/// Return `None` for any other reversed range.
pub fn SrcSpan::from_compiler(start : ByteOffset, end : ByteOffset) -> SrcSpan? {
  if start > end && end == ByteOffset::zero() {
    Some(SrcSpan::eof(start))
  } else {
    SrcSpan::between(start, end)
  }
}

///|
/// Whether this is a reversed compiler EOF sentinel.
/// EOF at byte zero has the same representation as the empty range at zero.
pub fn SrcSpan::is_eof(self : SrcSpan) -> Bool {
  self.start > self.end
}

///|
/// Whether the byte offset lies in the half-open range. EOF contains nothing.
pub fn SrcSpan::contains(self : SrcSpan, byte : ByteOffset) -> Bool {
  !self.is_eof() && self.start <= byte && byte < self.end
}

///|
/// The range's byte length, or `None` for a compiler EOF location.
pub fn SrcSpan::length(self : SrcSpan) -> ByteLength? {
  if self.is_eof() {
    None
  } else {
    ByteLength::new(self.end.to_int() - self.start.to_int())
  }
}

///|
/// A one-based line and column. Columns count Unicode code points.
pub struct Position {
  line : LineNumber
  column : ColumnNumber
} derive(Eq, Debug, Hash)

///|
/// Create a position from raw coordinates. Return `None` below one.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.Position::new(0, 1), content="None")
///   let position = @span.Position::new(1, 2).unwrap()
///   assert_eq(position.column.to_int(), 2)
/// }
/// ```
pub fn Position::new(line : Int32, column : Int32) -> Position? {
  match (LineNumber::new(line), ColumnNumber::new(column)) {
    (Some(line), Some(column)) => Some(Position::at(line, column))
    _ => None
  }
}

///|
/// Create a position from validated coordinates.
pub fn Position::at(line : LineNumber, column : ColumnNumber) -> Position {
  { line, column, }
}
