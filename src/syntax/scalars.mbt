///|
/// A zero-based index of a node within one field of its parent.
/// Only `new` can construct an index from a signed integer.
pub struct ChildIndex(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Validate an index. Return `None` for a negative value.
///
/// ```mbt check
/// test {
///   debug_inspect(@syntax.ChildIndex::new(-1), content="None")
///   assert_eq(@syntax.ChildIndex::new(0).unwrap().to_int(), 0)
/// }
/// ```
pub fn ChildIndex::new(value : Int32) -> ChildIndex? {
  if value >= 0 {
    Some(ChildIndex(value))
  } else {
    None
  }
}

///|
/// The array index used to access the field's child nodes.
pub fn ChildIndex::to_int(self : ChildIndex) -> Int32 {
  self.0
}

///|
/// The number of parent edges from a traversal's start node. The root is zero.
pub struct NodeDepth(Int32) derive(Eq, Compare, Hash, Debug)

///|
/// Validate a depth. Return `None` for a negative value.
pub fn NodeDepth::new(value : Int32) -> NodeDepth? {
  if value >= 0 {
    Some(NodeDepth(value))
  } else {
    None
  }
}

///|
/// The depth for serialization or comparison with an array's length.
pub fn NodeDepth::to_int(self : NodeDepth) -> Int32 {
  self.0
}

///|
/// Write a depth as decimal digits in traversal reports.
pub impl Show for NodeDepth with fn output(self, logger) {
  logger.write_string(self.0.to_string())
}

///|
/// Write a child index as decimal digits in a node path.
pub impl Show for ChildIndex with fn output(self, logger) {
  logger.write_string(self.0.to_string())
}
