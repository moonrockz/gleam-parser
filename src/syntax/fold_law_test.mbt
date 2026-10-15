///|
/// fold's events under `p`, logged into the accumulator.
fn fold_events(root : @syntax.NodeRef, p : Policy) -> Array[String] {
  let (events, _) = @syntax.fold(
    root,
    ([], 0),
    (acc, n) => {
      let (events, k) = acc
      events.push("+" + tag(n))
      ((events, k + 1), decide(p, k))
    },
    leave=(acc, n) => {
      acc.0.push("-" + tag(n))
      acc
    },
  )
  events
}

///|
test "law: fold with a logging accumulator gives walk's events" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Policy)) => {
      let (m, p) = input
      let root = gleam_root(m)
      fold_events(root, p) == walk_events(root, p)
    },
    count=100,
    max_size=10,
    seed=2171,
  )
}

///|
test "law: a fold inside a fold callback leaves the outer fold unchanged" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Policy, Policy)) => {
      let (m, p, q) = input
      let root = gleam_root(m)
      let mut ok = true
      let (events, _) = @syntax.fold(
        root,
        ([], 0),
        (acc, n) => {
          let (events, k) = acc
          if fold_events(n, q) != model(n, q) {
            ok = false
          }
          events.push("+" + tag(n))
          ((events, k + 1), decide(p, k))
        },
        leave=(acc, n) => {
          if fold_events(n, q) != model(n, q) {
            ok = false
          }
          acc.0.push("-" + tag(n))
          acc
        },
      )
      ok && events == model(root, p)
    },
    count=50,
    max_size=8,
    seed=2172,
  )
}

///|
test "law: a fold inside a walk callback gives its standalone result" {
  @quickcheck.check(
    (input : (@lawkit.GleamModule, Policy, Policy)) => {
      let (m, p, q) = input
      let root = gleam_root(m)
      let mut ok = true
      let outer = walk_events(root, p)
      @syntax.walk(
        root,
        n => {
          if fold_events(n, q) != model(n, q) {
            ok = false
          }
          Continue
        },
        leave=n => if fold_events(n, q) != model(n, q) { ok = false },
      )
      ok && outer == model(root, p)
    },
    count=50,
    max_size=8,
    seed=2173,
  )
}
