///|
/// Compile-time check that the lists in the AST are read-only views: a
/// `push` on them must not type-check. The body is never run.
fn _readonly(m : @ast.Module, f : @ast.Function, c : @ast.Clause) -> Unit {
  let d : ArrayView[@ast.TargetedDefinition] = m.definitions
  let b : ArrayView[@ast.Statement] = f.body
  let p : ArrayView[@ast.Pattern] = c.pattern
  ignore((d, b, p))
}

///|
test "AST lists are views" {
  // The function above compiles only while the fields are ArrayView.
  ignore(_readonly)
}
