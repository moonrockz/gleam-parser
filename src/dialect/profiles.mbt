///|
/// A profile cannot be registered or composed. Conflicts identify both
/// providers. A missing profile names the identity requested by configuration.
pub(all) suberror ProfileError {
  InvalidIdentity(String)
  DuplicateProfile(String)
  MissingProfile(String)
  TargetConflict(name~ : String, existing~ : String, incoming~ : String)
} derive(Eq, Debug)

///|
/// A reusable, named set of extension target registrations.
/// Profile modules construct this value through the same API as applications.
/// Use a module-qualified identity with a version, such as `example/orbit@1`.
/// No profile is installed or activated by constructing it.
pub struct Profile {
  identity : String
  targets : ArrayView[@target.Target]
} derive(Eq, Debug)

///|
/// Validate a profile and copy its target list. Reject an empty identity,
/// duplicate registrations, and attempts to register either standard identity.
/// Standard aliases cannot be constructed as extension identities.
///
/// ```mbt check
/// test {
///   let profile = @dialect.Profile(
///     "example/orbit@1",
///     [@target.Target::extension("orbit")][:],
///   )
///   let dialect = @dialect.Dialect::gleam_1_19().with_profile(profile)
///   assert_eq(dialect.knows_target("orbit"), true)
///   assert_eq(dialect.knows_target("unregistered"), false)
/// }
/// ```
pub fn Profile::Profile(
  identity : String,
  targets : ArrayView[@target.Target],
) -> Profile raise ProfileError {
  if identity.is_empty() {
    raise InvalidIdentity(identity)
  }
  let mut registry = @target.Registry::standard()
  for target in targets {
    let existing = if target is Extension(_) { identity } else { "gleam-1.19" }
    registry = registry.register(target) catch {
      _ =>
        raise TargetConflict(name=target.name(), existing~, incoming=identity)
    }
  }
  let extensions = registry.all().filter(t => t is Extension(_))
  { identity, targets: extensions[:], }
}

///|
/// Compose this dialect with a profile. Preserve the original dialect on
/// success and failure. Compatible profiles commute; a repeated profile or
/// target fails explicitly, with no override and no registration-order winner.
pub fn Dialect::with_profile(
  self : Dialect,
  profile : Profile,
) -> Dialect raise ProfileError {
  if self.profiles.any(p => p.identity == profile.identity) {
    raise DuplicateProfile(profile.identity)
  }
  let mut targets = self.targets
  for target in profile.targets {
    let mut existing = self.name
    for p in self.profiles {
      if p.targets.contains(target) {
        existing = p.identity
      }
    }
    targets = targets.register(target) catch {
      _ =>
        raise TargetConflict(
          name=target.name(),
          existing~,
          incoming=profile.identity,
        )
    }
  }
  let profiles = self.profiles.to_owned()
  profiles.push(profile)
  profiles.sort_by((a, b) => a.identity.compare(b.identity))
  { ..self, targets, profiles: profiles[:], }
}

///|
/// An application-supplied registry of available profiles. It contains values,
/// not module loaders. Standard parsing needs no profile registry.
pub struct Profiles {
  available : ArrayView[Profile]
} derive(Eq, Debug)

///|
/// Copy and validate the available profiles. Reject duplicate identities even
/// when their registrations are identical, so lookup never depends on order.
pub fn Profiles::Profiles(
  available : ArrayView[Profile],
) -> Profiles raise ProfileError {
  let seen : Array[String] = []
  for profile in available {
    if seen.contains(profile.identity) {
      raise DuplicateProfile(profile.identity)
    }
    seen.push(profile.identity)
  }
  { available: available.to_owned()[:], }
}

///|
/// No optional profiles are available. Lookup of any identity fails explicitly.
pub fn Profiles::empty() -> Profiles {
  { available: [][:], }
}

///|
/// Find an available profile by its exact identity. Raise `MissingProfile`
/// instead of loading code, consulting a global registry, or using a fallback.
pub fn Profiles::get(
  self : Profiles,
  identity : String,
) -> Profile raise ProfileError {
  for profile in self.available {
    if profile.identity == identity {
      return profile
    }
  }
  raise MissingProfile(identity)
}

///|
/// Apply named profiles in order to the supplied base dialect. Conflicts and
/// missing identities raise `ProfileError`. The base remains unchanged.
pub fn Profiles::apply(
  self : Profiles,
  base : Dialect,
  identities : ArrayView[String],
) -> Dialect raise ProfileError {
  let mut dialect = base
  for identity in identities {
    dialect = dialect.with_profile(self.get(identity))
  }
  dialect
}
