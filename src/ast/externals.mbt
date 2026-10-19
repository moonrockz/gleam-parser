///|
/// One target-specific reference with its annotation's source location.
/// The module and function strings are opaque. Consumers interpret them.
pub(all) struct ExternalBinding {
  target : Target
  external : External
} derive(Eq, Debug)

///|
/// A repeated external binding. The existing collection is unchanged.
pub(all) suberror BindingError {
  DuplicateBinding(Target)
} derive(Eq, Debug)

///|
/// An immutable collection with at most one external binding per target.
/// Use `with_binding` to add a binding and `get` to look one up.
///
/// ```mbt check
/// test {
///   let target = @ast.Target::extension("orbit")
///   let external : @ast.External = {
///     module_: "space/list",
///     function: "length",
///     location: @span.SrcSpan::from_ints(0, 40).unwrap(),
///   }
///   let bindings = @ast.ExternalBindings::empty().with_binding(target, external)
///   assert_eq(bindings.get(target), Some(external))
///   assert_eq(bindings.get(Erlang), None)
/// }
/// ```
pub struct ExternalBindings {
  bindings : ArrayView[ExternalBinding]
} derive(Eq, Debug)

///|
/// No external bindings.
pub fn ExternalBindings::empty() -> ExternalBindings {
  { bindings: [][:], }
}

///|
/// Add a binding in a new collection. Raise `DuplicateBinding` when that
/// target already has a binding. No registration or backend selection occurs.
pub fn ExternalBindings::with_binding(
  self : ExternalBindings,
  target : Target,
  external : External,
) -> ExternalBindings raise BindingError {
  if self.get(target) is Some(_) {
    raise DuplicateBinding(target)
  }
  let bindings = self.bindings.to_owned()
  bindings.push({ target, external, })
  bindings.sort_by((a, b) => {
    match (a.target, b.target) {
      (Erlang, _) => -1
      (_, Erlang) => 1
      (JavaScript, _) => -1
      (_, JavaScript) => 1
      _ => byte_order(a.target.name(), b.target.name())
    }
  })
  { bindings: bindings[:], }
}

///|
/// Find a binding by target identity. Return `None` when none is present.
pub fn ExternalBindings::get(
  self : ExternalBindings,
  target : Target,
) -> External? {
  for binding in self.bindings {
    if binding.target == target {
      return Some(binding.external)
    }
  }
  None
}

///|
/// Return a copy of all bindings in canonical order, with standard targets first.
pub fn ExternalBindings::all(self : ExternalBindings) -> Array[ExternalBinding] {
  self.bindings.to_owned()
}

///|
/// Whether the definition has no external binding for any target.
pub fn ExternalBindings::is_empty(self : ExternalBindings) -> Bool {
  self.bindings.is_empty()
}

///|
/// Import the compiler's two optional external fields into a generic collection.
/// Standard compatibility decoders use this boundary. New code can use
/// `empty().with_binding(target, external)` for any registered target.
pub fn ExternalBindings::from_standard(
  erlang : External?,
  javascript : External?,
) -> ExternalBindings {
  let bindings = []
  if erlang is Some(external) {
    bindings.push({ target: Erlang, external, })
  }
  if javascript is Some(external) {
    bindings.push({ target: JavaScript, external, })
  }
  { bindings: bindings[:], }
}

///|
/// Find this function's binding for a target, including standard targets.
/// A binding does not imply a target restriction on the definition.
pub fn Function::external_for(self : Function, target : Target) -> External? {
  self.externals.get(target)
}

///|
/// Find this external type's binding for a target, including standard targets.
pub fn CustomType::external_for(
  self : CustomType,
  target : Target,
) -> External? {
  self.externals.get(target)
}
