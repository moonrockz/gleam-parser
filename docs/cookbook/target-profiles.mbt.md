# Register targets and compose profiles

The core parser defaults to standard Gleam. A target registration adds syntax
and metadata. It does not provide a backend or check a foreign symbol.

## Parse with the core only

Import `"moonrockz/gleam-parser" @gleam` in `moon.pkg`. No optional profile
module is required. Standard export retains the compiler's canonical JSON.

```mbt check
///|
test "tp: core-only parsing stays strict" {
  let ordinary = @gleam.parse_text("pub const answer = 42")
  assert_eq(ordinary.has_errors(), false)
  let json = @gleam.encode_parsed(ordinary.parsed())
  assert_eq(@gleam.decode_parsed(json), ordinary.parsed())
  assert_eq(
    @gleam.parse_text("@target(orbit) pub const answer = 42").has_errors(),
    true,
  )
}
```

## Register a custom target

Use a lowercase name that the Gleam scanner reads as one ordinary name.
Keywords, standard target names, and the `erl` and `js` aliases are reserved.
A registration applies to both `@target` and `@external`.

```mbt check
///|
test "tp: a custom target retains its external binding" {
  let orbit = @gleam.Target::extension("orbit")
  let dialect = @gleam.Dialect::gleam_1_19().register_target(orbit)
  let config = { ..@gleam.Config::default(), dialect, }
  let source = "@external(orbit, \"space/list\", \"length\")\npub fn length(xs: List(a)) -> Int\n"
  let result = @gleam.parse_text(source, config~)
  assert_eq(result.has_errors(), false)
  guard result.module_.definitions[0].definition is Function(function) else {
    fail("expected a function")
  }
  let binding = function.external_for(orbit).unwrap()
  assert_eq(binding.module_, "space/list")
  assert_eq(binding.function, "length")
  assert_eq(binding.location.start.to_int(), 0)
  // External bindings do not select or restrict a target.
  assert_eq(result.module_.definitions[0].target, None)
  assert_eq(result.cst.to_source(), source)
  assert_eq(@gleam.format_parsed(result), source)
}
```

A definition can have one external binding for each registered target. A
second binding for the same target reports `DuplicateAttribute` at the
conflicting annotation. Functions and external types use the same collection.
`external_for(Erlang)` and `external_for(JavaScript)` access standard bindings.
A target restriction is in `TargetedDefinition.target`.

## Compose independently supplied profiles

A profile gives registrations a reusable identity. Use a module-qualified name
and a version. A profile module can return a `Profile` from an ordinary function.
The core does not need to know the module's name.

```mbt check
///|
test "tp: compatible profiles compose in either order" {
  let orbit = @gleam.Profile(
    "example/orbit@1",
    [@gleam.Target::extension("orbit")][:],
  )
  let nebula = @gleam.Profile(
    "example/nebula@1",
    [@gleam.Target::extension("nebula")][:],
  )
  let base = @gleam.Dialect::gleam_1_19()
  let dialect = base.with_profile(orbit).with_profile(nebula)
  assert_eq(dialect, base.with_profile(nebula).with_profile(orbit))
  assert_eq(dialect.knows_target("orbit"), true)
  assert_eq(dialect.knows_target("nebula"), true)
  assert_eq(base.knows_target("orbit"), false)
}
```

Composition rejects repeated profiles and conflicting target registrations.
It never replaces an existing registration. Errors identify the target and
both providers. No source parse occurs when composition fails.

```mbt check
///|
test "tp: conflicts identify both profiles" {
  let orbit = @gleam.Target::extension("orbit")
  let first = @gleam.Profile("example/first@1", [orbit][:])
  let second = @gleam.Profile("example/second@1", [orbit][:])
  let conflict = try {
    let _ = @gleam.Dialect::gleam_1_19()
      .with_profile(first)
      .with_profile(second)
    None
  } catch {
    TargetConflict(name~, existing~, incoming~) =>
      Some((name, existing, incoming))
    _ => None
  }
  assert_eq(conflict, Some(("orbit", "example/first@1", "example/second@1")))
}
```

## Resolve profiles named by configuration

The application provides the available profiles. A missing identity is a
`ConfigError` with source `TomlKey("parser.profiles")`. The loader never imports
modules. Profile lists compose with the file's Gleam preset. As with other
configuration fields, an environment or caller dialect replaces the file's
whole dialect when merged with higher precedence.

```mbt check
///|
test "tp: configuration uses only supplied profiles" {
  let orbit = @gleam.Profile(
    "example/orbit@1",
    [@gleam.Target::extension("orbit")][:],
  )
  let profiles = @gleam.Profiles([orbit][:])
  let text = "[parser]\ngleam = \"1.19\"\nprofiles = [\"example/orbit@1\"]\n"
  let config = @gleam.Config::from_toml(text, profiles~).to_config(
    @gleam.Config::default(),
  )
  assert_eq(config.dialect.knows_target("orbit"), true)
  let missing = try {
    let _ = @gleam.Config::from_toml(text)
    false
  } catch {
    _ => true
  }
  assert_eq(missing, true)
}
```

Pass the same `profiles` argument to `Config::load(profiles~)` to read a file.
Direct programmatic registration needs no file or profile registry.

## Choose an interchange format

Compiler-compatible export raises `ExportError::NonStandardTarget` when a
definition or binding contains an extension. The AST is unchanged. Use the
separate versioned extended format to preserve the metadata.

```mbt check
///|
test "tp: extended JSON preserves identity and bindings" {
  let orbit = @gleam.Target::extension("orbit")
  let profile = @gleam.Profile("example/orbit@1", [orbit][:])
  let config = {
    ..@gleam.Config::default(),
    dialect: @gleam.Dialect::gleam_1_19().with_profile(profile),
  }
  let result = @gleam.parse_text(
    "@target(orbit)\n@external(orbit, \"domain\", \"Id\")\npub type Id\n",
    config~,
  )
  let rejected = try {
    let _ = @gleam.encode_parsed(result.parsed())
    false
  } catch {
    NonStandardTarget(target~, ..) => target == orbit
  }
  assert_eq(rejected, true)
  let json = @gleam.encode_extended(result)
  let decoded = @gleam.decode_extended(json)
  assert_eq(decoded.parsed, result.parsed())
  assert_eq(decoded.profiles, ["example/orbit@1"][:])
  assert_eq(decoded.targets.resolve("orbit"), Some(orbit))
}
```

The extended decoder validates the embedded registrations and every reference.
It rejects aliases, duplicate bindings, and unsupported format versions. Profile
identities are descriptive data, not executable code or proof of a trusted
provider. The document does not include source text or CST trivia. Keep the
source separately if you need exact reconstruction or comment-aware formatting.

## Format under the applicable dialect

`format(text, config~)` parses with that configuration. `format_parsed(result)`
uses the configuration stored in the result. An explicitly different dialect
raises `FormatError::DialectMismatch`. You can still change the fuel budget
without changing the dialect. Formatting preserves bindings and restrictions;
source locations change when layout changes.

```mbt check
///|
test "tp: an explicit incompatible formatter dialect is rejected" {
  let orbit = @gleam.Target::extension("orbit")
  let config = {
    ..@gleam.Config::default(),
    dialect: @gleam.Dialect::gleam_1_19().register_target(orbit),
  }
  let result = @gleam.parse_text("@target(orbit) pub const answer=42", config~)
  let formatted = @gleam.format_parsed(result)
  assert_eq(@gleam.parse_text(formatted, config~).has_errors(), false)
  let rejected = try {
    let _ = @gleam.format_parsed(result, config=@gleam.Config::default())
    false
  } catch {
    DialectMismatch(..) => true
    _ => false
  }
  assert_eq(rejected, true)
}
```

## Enable the optional Morphir module

Install `moonrockz/gleam-parser-morphir` separately and import its package as
`@morphir`. It registers `morphir` through the APIs shown above. See the module's
[tested README examples](../../profiles/morphir/src/README.mbt.md). The core archive
contains no Morphir module or dependency. Scala and Go in these examples are
synthetic profiles, not shipped backends.
