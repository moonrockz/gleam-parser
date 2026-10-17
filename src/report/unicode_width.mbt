///|
/// The compiler's non-CJK single-character width; controls have width zero.
fn char_width(ch : Char) -> Int32 {
  let code = ch.to_int()
  let mut lo = 0
  let mut hi = unicode_width_ranges.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (start, end, width) = unicode_width_ranges[mid]
    if code < start {
      hi = mid
    } else if code >= end {
      lo = mid + 1
    } else {
      return width
    }
  }
  1
}
