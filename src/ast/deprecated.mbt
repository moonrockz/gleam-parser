///|
/// Use `TupleIndex(value)` to import an unsigned index without loss.
#deprecated("Use `TupleIndex(value)` instead")
pub fn TupleIndex::from_uint64(value : UInt64) -> TupleIndex {
  TupleIndex(value)
}
