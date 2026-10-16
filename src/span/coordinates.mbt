///|
/// A zero-based offset in UTF-8 bytes. It does not identify a character boundary until checked against a source text.
/// Construct with `new`; values outside the domain return `None`.
pub struct ByteOffset(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 0.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.ByteOffset::new(-1), content="None")
///   debug_inspect(@span.ByteOffset::new(0), content="Some(ByteOffset(0))")
/// }
/// ```
pub fn ByteOffset::new(value : Int32) -> ByteOffset? {
  if value >= 0 {
    Some(ByteOffset(value))
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn ByteOffset::to_int(self : ByteOffset) -> Int32 {
  self.0
}

///|
/// The offset at the beginning of a source.
pub fn ByteOffset::zero() -> ByteOffset {
  ByteOffset(0)
}

///|
/// Move by a signed displacement. Return `None` on underflow or overflow.
///
/// ```mbt check
/// test {
///   let offset = @span.ByteOffset::new(2).unwrap()
///   debug_inspect(offset.shift(-3), content="None")
///   debug_inspect(offset.shift(1), content="Some(ByteOffset(3))")
/// }
/// ```
pub fn ByteOffset::shift(self : ByteOffset, delta : Int32) -> ByteOffset? {
  let value = self.0.to_int64() + delta.to_int64()
  if value < 0L || value > 2147483647L {
    None
  } else {
    Some(ByteOffset(value.to_int()))
  }
}

///|
/// A zero-based offset in UTF-16 code units. It is distinct from a byte offset.
/// Construct with `new`; values outside the domain return `None`.
pub struct Utf16Offset(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 0.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.Utf16Offset::new(-1), content="None")
///   debug_inspect(@span.Utf16Offset::new(2), content="Some(Utf16Offset(2))")
/// }
/// ```
pub fn Utf16Offset::new(value : Int32) -> Utf16Offset? {
  if value >= 0 {
    Some(Utf16Offset(value))
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn Utf16Offset::to_int(self : Utf16Offset) -> Int32 {
  self.0
}

///|
/// The offset at the beginning of a source.
pub fn Utf16Offset::zero() -> Utf16Offset {
  Utf16Offset(0)
}

///|
/// Move by a signed displacement. Return `None` on underflow or overflow.
pub fn Utf16Offset::shift(self : Utf16Offset, delta : Int32) -> Utf16Offset? {
  let value = self.0.to_int64() + delta.to_int64()
  if value < 0L || value > 2147483647L {
    None
  } else {
    Some(Utf16Offset(value.to_int()))
  }
}

///|
/// A non-negative number of UTF-8 bytes.
/// Construct with `new`; values outside the domain return `None`.
pub struct ByteLength(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 0.
pub fn ByteLength::new(value : Int32) -> ByteLength? {
  if value >= 0 {
    Some(ByteLength(value))
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn ByteLength::to_int(self : ByteLength) -> Int32 {
  self.0
}

///|
/// A one-based line number.
/// Construct with `new`; values outside the domain return `None`.
pub struct LineNumber(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 1.
pub fn LineNumber::new(value : Int32) -> LineNumber? {
  if value >= 1 {
    Some(LineNumber(value))
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn LineNumber::to_int(self : LineNumber) -> Int32 {
  self.0
}

///|
/// A one-based column number that counts Unicode code points.
/// Construct with `new`; values outside the domain return `None`.
pub struct ColumnNumber(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 1.
pub fn ColumnNumber::new(value : Int32) -> ColumnNumber? {
  if value >= 1 {
    Some(ColumnNumber(value))
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn ColumnNumber::to_int(self : ColumnNumber) -> Int32 {
  self.0
}

///|
/// The number of source lines. Even an empty source contains one line.
pub struct LineCount(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Validate a source line count. Return `None` below one.
pub fn LineCount::new(value : Int32) -> LineCount? {
  if value >= 1 {
    Some(LineCount(value))
  } else {
    None
  }
}

///|
/// The number of lines for serialization or allocation.
pub fn LineCount::to_int(self : LineCount) -> Int32 {
  self.0
}
