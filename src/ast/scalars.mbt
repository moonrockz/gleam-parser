///|
/// A tuple element index. The full unsigned 64-bit range matches Gleam.
///
/// ```mbt check
/// test {
///   let index : @ast.TupleIndex = @ast.TupleIndex(18446744073709551615UL)
///   assert_eq(index.to_uint64(), 18446744073709551615UL)
/// }
/// ```
pub(all) struct TupleIndex(UInt64) derive(Eq, Compare, Hash, Debug)

///|
/// Validate a signed input. Return `None` for a negative index.
pub fn TupleIndex::new(value : Int64) -> TupleIndex? {
  if value < 0L {
    None
  } else {
    Some(TupleIndex(value.reinterpret_as_uint64()))
  }
}

///|
/// The exact index for serialization or formatting.
pub fn TupleIndex::to_uint64(self : TupleIndex) -> UInt64 {
  self.0
}

///|
/// A bit array segment's unit, in the compiler's byte range `0..255`.
pub struct BitArrayUnit(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Validate a bit array unit. Return `None` outside `0..255`.
///
/// ```mbt check
/// test {
///   debug_inspect(@ast.BitArrayUnit::new(256), content="None")
///   assert_eq(@ast.BitArrayUnit::new(255).unwrap().to_int(), 255)
/// }
/// ```
pub fn BitArrayUnit::new(value : Int32) -> BitArrayUnit? {
  if value >= 0 && value <= 255 {
    Some(BitArrayUnit(value))
  } else {
    None
  }
}

///|
/// The unit value for serialization or formatting.
pub fn BitArrayUnit::to_int(self : BitArrayUnit) -> Int32 {
  self.0
}
