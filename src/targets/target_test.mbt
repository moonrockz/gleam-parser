///|
test "a consumer registers a new target without changing the parser" {
  let orbit = @targets.Target::extension("orbit")
  let registry = @targets.Registry::standard().register(orbit)
  @expect.expect_all(s => {
    s.expect(registry.resolve("orbit")).to_equal(Some(orbit))
    s.expect(registry.resolve("erlang")).to_equal(Some(@targets.Erlang))
    s
    .expect(registry.resolve("js", aliases=true))
    .to_equal(Some(@targets.JavaScript))
    s.expect(registry.resolve("unregistered")).to_equal(None)
  })
}
