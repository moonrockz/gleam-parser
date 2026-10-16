///|
/// A half-open UTF-8 byte range, or the compiler's EOF location.
/// Fields are readable. Only validated constructors can create a span.
pub struct SrcSpan {
  start : ByteOffset
  end : ByteOffset
} derive(Eq, Debug, Hash)

///|
/// Create an ordered byte range. Raise `CoordinateError` for negative
/// offsets or an end before the start. Use `from_ints` to get `Option`.
///
/// ```mbt check
/// test {
///   let span = @span.SrcSpan(2, 5)
///   assert_eq(span.length().map(n => n.to_int()), Some(3))
/// }
/// ```
pub fn SrcSpan::SrcSpan(
  start : Int32,
  end : Int32,
) -> SrcSpan raise CoordinateError {
  let start_offset = ByteOffset(start)
  let end_offset = ByteOffset(end)
  guard SrcSpan::from_offsets(start_offset, end_offset) is Some(span) else {
    raise ReversedSpan(start~, end~)
  }
  span
}

///|
/// Create an ordered range from raw byte offsets.
/// Return `None` for negative offsets or an end before the start.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.SrcSpan::from_ints(3, 2), content="None")
///   let span = @span.SrcSpan::from_ints(2, 5).unwrap()
///   debug_inspect(span.length().map(n => n.to_int()), content="Some(3)")
/// }
/// ```
#alias(new, deprecated="Use `SrcSpan::from_ints(...)` instead")
pub fn SrcSpan::from_ints(start : Int32, end : Int32) -> SrcSpan? {
  match (ByteOffset::from_int(start), ByteOffset::from_int(end)) {
    (Some(start), Some(end)) => SrcSpan::from_offsets(start, end)
    _ => None
  }
}

///|
/// Create an ordered range. Return `None` when the end precedes the start.
#alias(between, deprecated="Use `SrcSpan::from_offsets(...)` instead")
pub fn SrcSpan::from_offsets(start : ByteOffset, end : ByteOffset) -> SrcSpan? {
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
///   let location = @span.SrcSpan::eof(@span.ByteOffset::from_int(5).unwrap())
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
    SrcSpan::from_offsets(start, end)
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
    ByteLength::from_int(self.end.to_int() - self.start.to_int())
  }
}

///|
/// A one-based line and column. Columns count Unicode code points.
pub struct Position {
  line : LineNumber
  column : ColumnNumber
} derive(Eq, Debug, Hash)

///|
/// Create a one-based position from raw coordinates.
/// Raise `CoordinateError` for a line or column below one.
/// Use `from_ints` to get `Option`, or `at` with validated coordinates.
///
/// ```mbt check
/// test {
///   let position = @span.Position(2, 1)
///   assert_eq(position.line.to_int(), 2)
/// }
/// ```
pub fn Position::Position(
  line : Int32,
  column : Int32,
) -> Position raise CoordinateError {
  Position::at(LineNumber(line), ColumnNumber(column))
}

///|
/// Create a position from raw coordinates. Return `None` below one.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.Position::from_ints(0, 1), content="None")
///   let position = @span.Position::from_ints(1, 2).unwrap()
///   assert_eq(position.column.to_int(), 2)
/// }
/// ```
#alias(new, deprecated="Use `Position::from_ints(...)` instead")
pub fn Position::from_ints(line : Int32, column : Int32) -> Position? {
  match (LineNumber::from_int(line), ColumnNumber::from_int(column)) {
    (Some(line), Some(column)) => Some(Position::at(line, column))
    _ => None
  }
}

///|
/// Create a position from validated coordinates.
///
/// ```mbt check
/// test {
///   let position = @span.Position::at(
///     @span.LineNumber::from_int(2).unwrap(),
///     @span.ColumnNumber::from_int(1).unwrap(),
///   )
///   assert_eq(position, @span.Position::from_ints(2, 1).unwrap())
/// }
/// ```
pub fn Position::at(line : LineNumber, column : ColumnNumber) -> Position {
  { line, column, }
}
