///|
/// A half-open range of UTF-8 byte offsets in a source text, `start`
/// included and `end` excluded, as the Gleam compiler's `SrcSpan`.
pub(all) struct SrcSpan {
  start : Int32
  end : Int32
} derive(Eq, Debug, Hash)

///|
pub fn SrcSpan::new(start : Int32, end : Int32) -> SrcSpan {
  { start, end, }
}

///|
/// Whether `byte` lies in the span: `start <= byte < end`.
pub fn SrcSpan::contains(self : SrcSpan, byte : Int32) -> Bool {
  self.start <= byte && byte < self.end
}

///|
/// The number of bytes in the span.
pub fn SrcSpan::length(self : SrcSpan) -> Int32 {
  self.end - self.start
}

///|
/// A line and column in a source text. Both are 1-based; the column counts
/// code points (a surrogate pair is one column), as the compiler's error
/// output does.
pub(all) struct Position {
  line : Int32
  column : Int32
} derive(Eq, Debug, Hash)

///|
pub fn Position::new(line : Int32, column : Int32) -> Position {
  { line, column, }
}
