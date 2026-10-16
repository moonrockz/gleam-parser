///|
/// A zero-based index of a node within one field of its parent.
/// Native construction raises on invalid input; `from_int` returns `Option`.
#valtype
pub struct ChildIndex {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Validate an index. Return `None` for a negative value.
///
/// ```mbt check
/// test {
///   debug_inspect(@syntax.ChildIndex::from_int(-1), content="None")
///   assert_eq(@syntax.ChildIndex::from_int(0).unwrap().to_int(), 0)
/// }
/// ```
#alias(new, deprecated="Use `ChildIndex::from_int(...)` instead")
pub fn ChildIndex::from_int(value : Int32) -> ChildIndex? {
  if value >= 0 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The array index used to access the field's child nodes.
pub fn ChildIndex::to_int(self : ChildIndex) -> Int32 {
  self.value
}

///|
/// The number of parent edges from a traversal's start node. The root is zero.
#valtype
pub struct NodeDepth {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Validate a depth. Return `None` for a negative value.
#alias(new, deprecated="Use `NodeDepth::from_int(...)` instead")
pub fn NodeDepth::from_int(value : Int32) -> NodeDepth? {
  if value >= 0 {
    Some({ value, })
  } else {
    None
  }
}

///|
/// The depth for serialization or comparison with an array's length.
pub fn NodeDepth::to_int(self : NodeDepth) -> Int32 {
  self.value
}

///|
/// Write a depth as decimal digits in traversal reports.
pub impl Show for NodeDepth with fn output(self, logger) {
  logger.write_string(self.value.to_string())
}

///|
/// Write a child index as decimal digits in a node path.
pub impl Show for ChildIndex with fn output(self, logger) {
  logger.write_string(self.value.to_string())
}

///|
/// Create a `ChildIndex`. Raise `TraversalValueError` for a negative value.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   assert_eq(@syntax.ChildIndex(0).to_int(), 0)
/// }
/// ```
pub fn ChildIndex::ChildIndex(
  value : Int32,
) -> ChildIndex raise TraversalValueError {
  guard ChildIndex::from_int(value) is Some(valid) else {
    raise InvalidChildIndex(value)
  }
  valid
}

///|
/// Create a `NodeDepth`. Raise `TraversalValueError` for a negative value.
/// Use `from_int` to get `Option`.
///
/// ```mbt check
/// test {
///   assert_eq(@syntax.NodeDepth(0).to_int(), 0)
/// }
/// ```
pub fn NodeDepth::NodeDepth(
  value : Int32,
) -> NodeDepth raise TraversalValueError {
  guard NodeDepth::from_int(value) is Some(valid) else {
    raise InvalidNodeDepth(value)
  }
  valid
}

///|
/// A child index or node depth is negative.
pub(all) suberror TraversalValueError {
  InvalidChildIndex(Int32)
  InvalidNodeDepth(Int32)
} derive(Eq, Debug)
