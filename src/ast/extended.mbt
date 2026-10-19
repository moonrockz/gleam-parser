///|
/// Invalid extended-document metadata or an AST target absent from its registry.
/// These errors never alter the AST or substitute a standard target.
pub(all) suberror ExtendedError {
  UnregisteredTarget(Target)
  InvalidIdentity(String)
} derive(Eq, Debug)

///|
/// A parsed AST and its declared dialect, profile identities, and target registry.
/// This document contains data only. Decoding never imports profile code.
/// Use `Extended` to validate the references before encoding.
pub struct Extended {
  parsed : Parsed
  dialect : String
  profiles : ArrayView[String]
  targets : @target.Registry
} derive(Eq, Debug)

///|
/// Create an extended document. Every AST target must occur in `targets`.
/// `dialect` must be nonempty. Profile identities must be nonempty and unique;
/// use module-qualified identities with a version for published profiles.
/// The profile list is copied. Registration does not implement a backend.
pub fn Extended::Extended(
  parsed : Parsed,
  dialect~ : String,
  targets~ : @target.Registry,
  profiles~ : ArrayView[String] = [][:],
) -> Extended raise ExtendedError {
  if dialect.is_empty() {
    raise InvalidIdentity(dialect)
  }
  let names : Array[String] = []
  for profile in profiles {
    if profile.is_empty() || names.contains(profile) {
      raise InvalidIdentity(profile)
    }
    names.push(profile)
  }
  names.sort_by(byte_order)
  let document = { parsed, dialect, targets, profiles: names[:], }
  document.validate()
  document
}

///|
fn Extended::validate(self : Extended) -> Unit raise ExtendedError {
  fn check(target : Target) -> Unit raise ExtendedError {
    if self.targets.resolve(target.name()) != Some(target) {
      raise UnregisteredTarget(target)
    }
  }
  for definition in self.parsed.module_.definitions {
    if definition.target is Some(target) {
      check(target)
    }
    for binding in definition.definition.external_bindings().all() {
      check(binding.target)
    }
  }
  for warning in self.parsed.warnings {
    if warning is DeprecatedTargetShorthand(target~, ..) {
      check(target)
    }
  }
}

///|
/// Return a definition's external bindings. Definitions without an external
/// annotation grammar return an empty collection.
pub fn Definition::external_bindings(self : Definition) -> ExternalBindings {
  match self {
    Function(f) => f.externals
    CustomType(t) => t.externals
    _ => ExternalBindings::empty()
  }
}

///|
fn extended_definition(definition : TargetedDefinition) -> Json {
  // Reuse the stack-safe node codec. Replace only the compatibility fields at
  // the definition boundary; nested expression/type codecs stay identical.
  let payload = run(enc_definition(definition.definition, j => Done(j)))
  let fields = match payload {
    Object(fields) => fields
    _ => Map([])
  }
  match definition.definition {
    Function(_) | CustomType(_) => {
      fields.remove("external_erlang")
      fields.remove("external_javascript")
      fields.set(
        "externals",
        arr(
          definition.definition
          .external_bindings()
          .all()
          .map(binding => {
            obj([
              ("target", str(binding.target.name())),
              ("module", str(binding.external.module_)),
              ("function", str(binding.external.function)),
              ("location", encode_span(binding.external.location)),
            ])
          }),
        ),
      )
    }
    _ => ()
  }
  obj([
    ("definition", Json::object(fields)),
    ("target", opt(definition.target, t => str(t.name()))),
  ])
}

///|
/// Encode version 1 of the extended JSON format. Use `canonical` for
/// deterministic bytes. Unlike compiler-compatible export, this preserves
/// every registered target and generic external binding. Revalidate references
/// on each call in case the caller changed an AST array after construction.
///
/// ```mbt check
/// test {
///   let parsed : @ast.Parsed = {
///     module_: { definitions: [][:], },
///     extra: @ast.ModuleExtra::empty(),
///     warnings: [][:],
///   }
///   let document = @ast.Extended(
///     parsed,
///     dialect="gleam-1.19",
///     targets=@target.Registry::standard(),
///   )
///   assert_eq(@ast.decode_extended(@ast.encode_extended(document)), document)
/// }
/// ```
pub fn encode_extended(document : Extended) -> Json raise ExtendedError {
  document.validate()
  let targets = document.targets.all().map(t => t.name())
  targets.sort_by(byte_order)
  obj([
    ("format", str("gleam-parser-extended")),
    ("version", num(1)),
    ("dialect", str(document.dialect)),
    ("profiles", list(document.profiles, str)),
    ("targets", arr(targets.map(str))),
    (
      "parsed",
      obj([
        (
          "module",
          obj([
            (
              "definitions",
              list(document.parsed.module_.definitions, extended_definition),
            ),
          ]),
        ),
        ("extra", encode_extra(document.parsed.extra)),
        ("warnings", list(document.parsed.warnings, warning_json)),
      ]),
    ),
  ])
}

///|
fn registered_target(
  json : Json,
  path : Path,
  registry : @target.Registry,
) -> Target raise DecodeError {
  let name = dec_string(json, path)
  match registry.resolve(name) {
    Some(target) => target
    None => fail(path, "unregistered target \"\{name}\"")
  }
}

///|
fn dec_extended_definition(
  json : Json,
  path : Path,
  registry : @target.Registry,
) -> TargetedDefinition raise DecodeError {
  let target = dec_field(json, path, "target", (value, path) => {
    dec_nullable(value, path, (value, path) => {
      registered_target(value, path, registry)
    })
  })
  let definition = dec_field(json, path, "definition", (value, path) => {
    let fields = dec_object(value, path).copy()
    let kind = dec_kind_of(value, path)
    let mut externals = ExternalBindings::empty()
    if kind == "function" || kind == "custom_type" {
      if fields.contains("external_erlang") ||
        fields.contains("external_javascript") {
        fail(path, "legacy external fields are not part of the extended format")
      }
      let bindings = dec_field(value, path, "externals", (value, path) => {
        dec_array(value, path, (value, path) => {
          let target = dec_field(value, path, "target", (value, path) => {
            registered_target(value, path, registry)
          })
          let external = dec_external(value, path)
          (target, external, path)
        })
      })
      for binding in bindings {
        let (target, external, binding_path) = binding
        externals = externals.with_binding(target, external) catch {
          _ =>
            fail(
              binding_path,
              "duplicate external binding for \"\{target.name()}\"",
            )
        }
      }
      fields.remove("externals")
      fields.set("external_erlang", Json::null())
      fields.set("external_javascript", Json::null())
    } else if fields.contains("externals") {
      fail(
        Key(path, "externals"),
        "external bindings are not allowed on this definition",
      )
    }
    let definition = run_decode(
      dec_definition(Json::object(fields), path, v => Decoded(v)),
    )
    match definition {
      Function(f) => Function({ ..f, externals, })
      CustomType(t) => CustomType({ ..t, externals, })
      _ => definition
    }
  })
  { definition, target, }
}

///|
/// Decode version 1 of the extended JSON format without loading profile code.
/// Validate the embedded registry, rejecting invalid names, aliases, duplicates,
/// missing standard identities, unknown references, and duplicate bindings.
/// Raise `DecodeError` with the JSON path for malformed or unsupported input.
/// Profile identities are descriptive data; an application must supply matching
/// profile code explicitly if it wants to parse or format new source.
pub fn decode_extended(json : Json) -> Extended raise DecodeError {
  let format = dec_field(json, Root, "format", dec_string)
  if format != "gleam-parser-extended" {
    fail(Key(Root, "format"), "unknown format")
  }
  let version = dec_field(json, Root, "version", dec_int)
  if version != 1 {
    fail(Key(Root, "version"), "unsupported extended format version")
  }
  let dialect = dec_field(json, Root, "dialect", dec_string)
  let profiles = dec_field(json, Root, "profiles", (v, p) => {
    dec_array(v, p, dec_string)
  })
  let names = dec_field(json, Root, "targets", (v, p) => {
    dec_array(v, p, dec_string)
  })
  let mut registry = @target.Registry::standard()
  let seen : Array[String] = []
  for i, name in names {
    let path = Index(Key(Root, "targets"), i)
    if seen.contains(name) {
      fail(path, "duplicate target registration \"\{name}\"")
    }
    seen.push(name)
    if Target::of(name) is None {
      registry = registry.register(Target::extension(name)) catch {
        _ => fail(path, "invalid target registration \"\{name}\"")
      }
    }
  }
  if !seen.contains("erlang") || !seen.contains("javascript") {
    fail(Key(Root, "targets"), "missing standard target registration")
  }
  let parsed = dec_field(json, Root, "parsed", (value, path) => {
    let extra = dec_field(value, path, "extra", dec_extra)
    let warnings = dec_field(value, path, "warnings", (v, p) => {
      dec_array(v, p, (v, p) => {
        if dec_kind_of(v, p) == "deprecated_target_shorthand" {
          DeprecatedTargetShorthand(
            target=dec_field(v, p, "target", (v, p) => {
              registered_target(v, p, registry)
            }),
            location=dec_field(v, p, "location", dec_span),
          )
        } else {
          dec_warning(v, p)
        }
      })
    })
    let definitions = dec_field(value, path, "module", (v, p) => {
      dec_field(v, p, "definitions", (v, p) => {
        dec_array(v, p, (v, p) => dec_extended_definition(v, p, registry))
      })
    })
    Parsed::{ module_: { definitions, }, extra, warnings, }
  })
  Extended(parsed, dialect~, targets=registry, profiles~) catch {
    InvalidIdentity(name) =>
      fail(Root, "invalid or repeated dialect/profile identity \"\{name}\"")
    UnregisteredTarget(target) =>
      fail(Root, "unregistered target \"\{target.name()}\"")
  }
}
