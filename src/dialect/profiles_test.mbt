///|
test "independent profiles compose and conflicts identify both providers" {
  let orbit = @dialect.Profile(
    "example/orbit@1",
    [@target.Target::extension("orbit")][:],
  )
  let nebula = @dialect.Profile(
    "example/nebula@1",
    [@target.Target::extension("nebula")][:],
  )
  let base = @dialect.Dialect::gleam_1_19()
  let combined = base.with_profile(orbit).with_profile(nebula)
  @expect.expect_all(s => {
    s.expect(combined.knows_target("orbit")).to_equal(true)
    s.expect(combined.knows_target("nebula")).to_equal(true)
    s.expect(base.knows_target("orbit")).to_equal(false)
    s.expect(combined).to_equal(base.with_profile(nebula).with_profile(orbit))
  })
  let clash = @dialect.Profile(
    "other/orbit@1",
    [@target.Target::extension("orbit")][:],
  )
  let conflict = try {
    let _ = combined.with_profile(clash)
    None
  } catch {
    @dialect.TargetConflict(name~, existing~, incoming~) =>
      Some((name, existing, incoming))
    _ => None
  }
  @expect.expect(conflict).to_equal(
    Some(("orbit", "example/orbit@1", "other/orbit@1")),
  )
}
