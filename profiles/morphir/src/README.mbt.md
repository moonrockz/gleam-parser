# Morphir target profile for gleam-parser

This optional MoonBit module adds the `morphir` target to the core parser.
It has its own release identity, `moonrockz/gleam-parser-morphir@0.1.1`, and
requires core parser 0.5.0. Installing the core does not install this module.

Install it with `moon add moonrockz/gleam-parser-morphir`. In `moon.pkg`, import:

```text
import {
  "moonrockz/gleam-parser-morphir" @morphir,
}
```

The profile re-exports the common core APIs used below. These functions keep
standard Gleam as their default. If you need other core APIs, also run
`moon add moonrockz/gleam-parser@0.5.0` and import that package as `@gleam`.

## Parse a Morphir external function

Enable the profile explicitly. `@external` retains the target, module, symbol,
and source location. It does not restrict the definition to Morphir.

```mbt check
///|
test "mr: retain a Morphir function binding" {
  let dialect = @morphir.Dialect::gleam_1_19().with_profile(@morphir.profile())
  let config = { ..@morphir.Config::default(), dialect, }
  let source = "@external(morphir, \"morphir/sdk/list\", \"length\")\npub fn length(xs: List(a)) -> Int\n"
  let result = @morphir.parse_text(source, config~)
  assert_eq(result.has_errors(), false)
  guard result.module_.definitions[0].definition is Function(function) else {
    fail("expected a function")
  }
  let target = dialect.targets.resolve("morphir").unwrap()
  let binding = function.external_for(target).unwrap()
  assert_eq(binding.module_, "morphir/sdk/list")
  assert_eq(binding.function, "length")
  assert_eq(result.module_.definitions[0].target, None)
  assert_eq(@morphir.format_parsed(result), source)
  assert_eq(
    @morphir.decode_extended(@morphir.encode_extended(result)).parsed,
    result.parsed(),
  )
}
```

## Retain a target restriction and an external type

Use `@target(morphir)` for a definition's target restriction. Parsing retains
all definitions. A consumer decides which target to translate later.

```mbt check
///|
test "mr: external types and restrictions stay distinct" {
  let dialect = @morphir.Dialect::gleam_1_19().with_profile(@morphir.profile())
  let config = { ..@morphir.Config::default(), dialect, }
  let result = @morphir.parse_text(
    "@target(morphir)\n@external(morphir, \"example/domain\", \"CustomerId\")\npub type CustomerId\n",
    config~,
  )
  assert_eq(result.has_errors(), false)
  assert_eq(
    result.module_.definitions[0].target.map(t => t.name()),
    Some("morphir"),
  )
  guard result.module_.definitions[0].definition is CustomType(type_) else {
    fail("expected an external type")
  }
  assert_eq(type_.externals.all()[0].external.function, "CustomerId")
  assert_eq(
    @morphir.parse_text("@target(morphir) pub const x = 1").has_errors(),
    true,
  )
  assert_eq(dialect.knows_target("go"), false)
}
```

## Compose with another provider

Other modules use the same public APIs. Conflicting registrations raise
`ProfileError`; no registration silently overrides another.

```mbt check
///|
test "mr: compose a separately defined target" {
  let scala = @morphir.Profile(
    "example/scala@1",
    [@morphir.Target::extension("scala")][:],
  )
  let dialect = @morphir.Dialect::gleam_1_19()
    .with_profile(@morphir.profile())
    .with_profile(scala)
  assert_eq(dialect.knows_target("morphir"), true)
  assert_eq(dialect.knows_target("scala"), true)
  let available = @morphir.Profiles([@morphir.profile(), scala][:])
  let config = @morphir.Config::from_toml(
    "[parser]\nprofiles = [\"moonrockz/gleam-parser-morphir@0.1.1\", \"example/scala@1\"]\n",
    profiles=available,
  ).to_config(@morphir.Config::default())
  assert_eq(config.dialect, dialect)
}
```

This module supplies no Morphir backend, symbol resolution, or foreign-call
execution. Module and symbol strings are opaque. Use extended JSON to retain
Morphir metadata. Compiler-compatible export raises `NonStandardTarget`.
See the core [target profile cookbook](../../../docs/cookbook/target-profiles.mbt.md)
and [migration guide](../../../docs/migration-0.5.md).

## Release this module

Publish the required core version first. Run the `Release Morphir profile`
workflow on the commit to release. Verify the module version on mooncakes.io,
then create the `morphir-v0.1.1` GitHub release at the same commit. Future profile
releases update this module's manifest, `version()`, profile identity, and notes
independently of the core version.
