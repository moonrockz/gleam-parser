//// Module documentation.
//// Second line.

/// Documents the constant.
pub const c = 1

/// Detached doc comment.
// A regular comment detaches it.
pub fn f() {
  1
}

/// Multi-line docs
///   with indentation kept
/// and a third line.
pub type T {
  /// Variant docs.
  A
  /// Field docs on a labelled field.
  B(
    /// field doc
    label: Int,
    Int,
  )
}

/// Doc before attributes.
@deprecated("x")
pub fn g() {
  Nil
}

/// Doc inside a body is taken by the next definition.
fn h() {
  /// inside
  1
}

fn after() {
  Nil
}

/// Trailing doc comment with no definition after it.
