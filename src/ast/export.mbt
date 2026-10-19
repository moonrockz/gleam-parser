///|
/// Compiler-compatible JSON cannot represent this extension target.
/// The error identifies the target and its definition or annotation location.
/// The AST is unchanged. Use the versioned extended interchange format instead.
pub(all) suberror ExportError {
  NonStandardTarget(target~ : Target, location~ : @span.SrcSpan)
} derive(Eq, Debug)

///|
fn check_target(
  target : Target,
  location : @span.SrcSpan,
) -> Unit raise ExportError {
  if target is Extension(_) {
    raise NonStandardTarget(target~, location~)
  }
}

///|
fn check_definition(definition : Definition) -> Unit raise ExportError {
  let externals = match definition {
    Function(f) => f.externals
    CustomType(t) => t.externals
    _ => ExternalBindings::empty()
  }
  for binding in externals.all() {
    check_target(binding.target, binding.external.location)
  }
}

///|
fn check_targeted_definition(
  definition : TargetedDefinition,
) -> Unit raise ExportError {
  if definition.target is Some(target) {
    check_target(target, definition.definition.location())
  }
  check_definition(definition.definition)
}

///|
fn check_module(module_ : Module) -> Unit raise ExportError {
  for definition in module_.definitions {
    check_targeted_definition(definition)
  }
}

///|
fn check_warning(warning : Warning) -> Unit raise ExportError {
  if warning is DeprecatedTargetShorthand(target~, location~) {
    check_target(target, location)
  }
}
