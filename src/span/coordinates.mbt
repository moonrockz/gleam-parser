///|
/// A zero-based offset in UTF-8 bytes. It does not identify a character boundary until checked against a source text.
/// Construct with the native constructor, or use `from_int` to get `Option`.
#valtype
pub struct ByteOffset {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 0.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.ByteOffset::from_int(-1), content="None")
///   debug_inspect(
///     @span.ByteOffset::from_int(0),
///     content=(
///       #|Some({ value: 0 })
///     ),
///   )
/// }
/// ```
#alias(new, deprecated="Use `ByteOffset::from_int(...)` instead")
pub fn ByteOffset::from_int(value : Int32) -> ByteOffset? {
  if value >= 0 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn ByteOffset::to_int(self : ByteOffset) -> Int32 {
  self.value
}

///|
/// The offset at the beginning of a source.
pub fn ByteOffset::zero() -> ByteOffset {
  { value: 0, }
}

///|
/// Move by a signed displacement. Return `None` on underflow or overflow.
///
/// ```mbt check
/// test {
///   let offset = @span.ByteOffset::from_int(2).unwrap()
///   debug_inspect(offset.shift(-3), content="None")
///   debug_inspect(
///     offset.shift(1),
///     content=(
///       #|Some({ value: 3 })
///     ),
///   )
/// }
/// ```
pub fn ByteOffset::shift(self : ByteOffset, delta : Int32) -> ByteOffset? {
  let value = self.value.to_int64() + delta.to_int64()
  if value < 0L || value > 2147483647L {
    None
  } else {
    Some({ value: value.to_int(), })
  }
}

///|
/// A zero-based offset in UTF-16 code units. It is distinct from a byte offset.
/// Construct with the native constructor, or use `from_int` to get `Option`.
#valtype
pub struct Utf16Offset {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 0.
///
/// ```mbt check
/// test {
///   debug_inspect(@span.Utf16Offset::from_int(-1), content="None")
///   debug_inspect(
///     @span.Utf16Offset::from_int(2),
///     content=(
///       #|Some({ value: 2 })
///     ),
///   )
/// }
/// ```
#alias(new, deprecated="Use `Utf16Offset::from_int(...)` instead")
pub fn Utf16Offset::from_int(value : Int32) -> Utf16Offset? {
  if value >= 0 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn Utf16Offset::to_int(self : Utf16Offset) -> Int32 {
  self.value
}

///|
/// The offset at the beginning of a source.
pub fn Utf16Offset::zero() -> Utf16Offset {
  { value: 0, }
}

///|
/// Move by a signed displacement. Return `None` on underflow or overflow.
pub fn Utf16Offset::shift(self : Utf16Offset, delta : Int32) -> Utf16Offset? {
  let value = self.value.to_int64() + delta.to_int64()
  if value < 0L || value > 2147483647L {
    None
  } else {
    Some({ value: value.to_int(), })
  }
}

///|
/// A non-negative number of UTF-8 bytes.
/// Construct with the native constructor, or use `from_int` to get `Option`.
#valtype
pub struct ByteLength {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 0.
#alias(new, deprecated="Use `ByteLength::from_int(...)` instead")
pub fn ByteLength::from_int(value : Int32) -> ByteLength? {
  if value >= 0 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn ByteLength::to_int(self : ByteLength) -> Int32 {
  self.value
}

///|
/// A one-based line number.
/// Construct with the native constructor, or use `from_int` to get `Option`.
#valtype
pub struct LineNumber {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 1.
#alias(new, deprecated="Use `LineNumber::from_int(...)` instead")
pub fn LineNumber::from_int(value : Int32) -> LineNumber? {
  if value >= 1 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn LineNumber::to_int(self : LineNumber) -> Int32 {
  self.value
}

///|
/// A one-based column number that counts Unicode code points.
/// Construct with the native constructor, or use `from_int` to get `Option`.
#valtype
pub struct ColumnNumber {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Return a validated value, or `None` below 1.
#alias(new, deprecated="Use `ColumnNumber::from_int(...)` instead")
pub fn ColumnNumber::from_int(value : Int32) -> ColumnNumber? {
  if value >= 1 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The numeric value for serialization or string and array operations.
pub fn ColumnNumber::to_int(self : ColumnNumber) -> Int32 {
  self.value
}

///|
/// The number of source lines. Even an empty source contains one line.
#valtype
pub struct LineCount {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Validate a source line count. Return `None` below one.
#alias(new, deprecated="Use `LineCount::from_int(...)` instead")
pub fn LineCount::from_int(value : Int32) -> LineCount? {
  if value >= 1 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The number of lines for serialization or allocation.
pub fn LineCount::to_int(self : LineCount) -> Int32 {
  self.value
}

///|
/// Create a validated `ByteOffset`. Raise `CoordinateError` outside its domain.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   let value = @span.ByteOffset(1)
///   assert_eq(value.to_int(), 1)
/// }
/// ```
pub fn ByteOffset::ByteOffset(
  value : Int32,
) -> ByteOffset raise CoordinateError {
  guard ByteOffset::from_int(value) is Some(valid) else {
    raise InvalidByteOffset(value)
  }
  valid
}

///|
/// Create a validated `Utf16Offset`. Raise `CoordinateError` outside its domain.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   let value = @span.Utf16Offset(1)
///   assert_eq(value.to_int(), 1)
/// }
/// ```
pub fn Utf16Offset::Utf16Offset(
  value : Int32,
) -> Utf16Offset raise CoordinateError {
  guard Utf16Offset::from_int(value) is Some(valid) else {
    raise InvalidUtf16Offset(value)
  }
  valid
}

///|
/// Create a validated `ByteLength`. Raise `CoordinateError` outside its domain.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   let value = @span.ByteLength(1)
///   assert_eq(value.to_int(), 1)
/// }
/// ```
pub fn ByteLength::ByteLength(
  value : Int32,
) -> ByteLength raise CoordinateError {
  guard ByteLength::from_int(value) is Some(valid) else {
    raise InvalidByteLength(value)
  }
  valid
}

///|
/// Create a validated `LineNumber`. Raise `CoordinateError` outside its domain.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   let value = @span.LineNumber(1)
///   assert_eq(value.to_int(), 1)
/// }
/// ```
pub fn LineNumber::LineNumber(
  value : Int32,
) -> LineNumber raise CoordinateError {
  guard LineNumber::from_int(value) is Some(valid) else {
    raise InvalidLineNumber(value)
  }
  valid
}

///|
/// Create a validated `ColumnNumber`. Raise `CoordinateError` outside its domain.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   let value = @span.ColumnNumber(1)
///   assert_eq(value.to_int(), 1)
/// }
/// ```
pub fn ColumnNumber::ColumnNumber(
  value : Int32,
) -> ColumnNumber raise CoordinateError {
  guard ColumnNumber::from_int(value) is Some(valid) else {
    raise InvalidColumnNumber(value)
  }
  valid
}

///|
/// Create a validated `LineCount`. Raise `CoordinateError` outside its domain.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   let value = @span.LineCount(1)
///   assert_eq(value.to_int(), 1)
/// }
/// ```
pub fn LineCount::LineCount(value : Int32) -> LineCount raise CoordinateError {
  guard LineCount::from_int(value) is Some(valid) else {
    raise InvalidLineCount(value)
  }
  valid
}
