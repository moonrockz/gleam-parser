///|
/// The recursive reference reduction (test-only; generated trees are
/// shallow).
fn[A] reduce_model(
  n : @syntax.NodeRef,
  f : (@syntax.NodeRef, ArrayView[A]) -> A,
) -> A {
  let kids = n.children().map(c => reduce_model(c, f))
  f(n, kids[:])
}

///|
test "law: reduce agrees with the recursive model" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let f = (n : @syntax.NodeRef, kids : ArrayView[String]) => {
        tag(n) + "(" + kids.to_owned().join(",") + ")"
      }
      @syntax.reduce(root, f) == reduce_model(root, f)
    },
    count=100,
    max_size=10,
    seed=2107,
  )
}

///|
test "law: reduce's node count is walk's enter count" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let mut entered = 0
      @syntax.walk(root, _ => {
        entered += 1
        Continue
      })
      let counted = @syntax.reduce(root, (_, kids) => {
        let mut n = 1
        for k in kids {
          n += k
        }
        n
      })
      counted == entered
    },
    count=100,
    max_size=10,
    seed=2108,
  )
}

///|
test "law: reduce_with_fields gives each child the step of children_with_fields" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let root = gleam_root(m)
      let mut ok = true
      ignore(
        @syntax.reduce_with_fields(root, (n, kids) => {
          let expected = n
            .children_with_fields()
            .map(x => "\{x.0.field}[\{x.0.index}]")
          let got = kids.to_owned().map(k => "\{k.0.field}[\{k.0.index}]")
          if got != expected {
            ok = false
          }
          0
        }),
      )
      ok
    },
    count=100,
    max_size=10,
    seed=2109,
  )
}
