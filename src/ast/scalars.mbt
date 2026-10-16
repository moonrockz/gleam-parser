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
#alias(new, deprecated="Use `TupleIndex::from_int64(...)` instead")
pub fn TupleIndex::from_int64(value : Int64) -> TupleIndex? {
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
#valtype
pub struct BitArrayUnit {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Validate a bit array unit. Return `None` outside `0..255`.
///
/// ```mbt check
/// test {
///   debug_inspect(@ast.BitArrayUnit::from_int(256), content="None")
///   assert_eq(@ast.BitArrayUnit::from_int(255).unwrap().to_int(), 255)
/// }
/// ```
#alias(new, deprecated="Use `BitArrayUnit::from_int(...)` instead")
pub fn BitArrayUnit::from_int(value : Int32) -> BitArrayUnit? {
  if value >= 0 && value <= 255 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The unit value for serialization or formatting.
pub fn BitArrayUnit::to_int(self : BitArrayUnit) -> Int32 {
  self.value
}

///|
/// A bit array unit falls outside the byte range `0..255`.
pub(all) suberror InvalidBitArrayUnit {
  InvalidBitArrayUnit(Int32)
} derive(Eq, Debug)

///|
/// Create a bit array unit. Raise `InvalidBitArrayUnit` outside `0..255`.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   assert_eq(@ast.BitArrayUnit(255).to_int(), 255)
/// }
/// ```
pub fn BitArrayUnit::BitArrayUnit(
  value : Int32,
) -> BitArrayUnit raise InvalidBitArrayUnit {
  guard BitArrayUnit::from_int(value) is Some(unit) else {
    raise InvalidBitArrayUnit(value)
  }
  unit
}
