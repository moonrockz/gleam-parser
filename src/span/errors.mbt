///|
/// A source coordinate or range violates its domain.
/// Each case retains the raw value that failed validation.
pub(all) suberror CoordinateError {
  InvalidByteOffset(Int32)
  InvalidUtf16Offset(Int32)
  InvalidByteLength(Int32)
  InvalidLineNumber(Int32)
  InvalidColumnNumber(Int32)
  InvalidLineCount(Int32)
  ReversedSpan(start~ : Int32, end~ : Int32)
} derive(Eq, Debug)
