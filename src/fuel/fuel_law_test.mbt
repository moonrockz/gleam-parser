///|
/// A budget between 1 and 50 and a sequence of operation names drawn from
/// a small set.
struct Trace(Int32, Array[String]) derive(@debug.Debug)

///|
impl @quickcheck.Arbitrary for Trace with fn arbitrary(size, rs) {
  let budget = 1 + rs.next_int().abs() % 50
  let n = rs.next_int().abs() % (size + 60)
  let names = ["expression", "pattern", "type", "constant"]
  let ops = Array::makei(n, _ => names[rs.next_int().abs() % names.length()])
  Trace(budget, ops)
}

///|
impl @quickcheck.Shrink for Trace with fn shrink(self) {
  let Trace(b, ops) = self
  if ops.length() == 0 {
    return [].iter()
  }
  [Trace(b, ops[0:ops.length() - 1].to_owned())].iter()
}

///|
/// `spend` chains exactly `budget` times from a fresh fuel, fails on the
/// next, and the error's levels sum to the budget; every intermediate
/// value keeps its receiver unchanged (immutability) and `spent()` keeps
/// first-entry order with exact counts.
test "law: fuel chains budget times, fails on budget + 1, and counts every push" {
  @quickcheck.check(
    (t : Trace) => {
      let Trace(budget, ops) = t
      let b = @fuel.Budget::new(budget).unwrap()
      let mut f = @fuel.Fuel(budget=b)
      let mut ok = true
      for i, name in ops {
        let before = f
        let r = Some(f.spend(@fuel.Operation(name))) catch {
          @fuel.FuelExhausted(budget=eb, spent~) => {
            let sum = spent.fold(init=0, (acc, s) => acc + s.levels)
            if i != budget || eb != b || sum != budget {
              ok = false
            }
            None
          }
        }
        if before != f {
          ok = false
        }
        match r {
          Some(next) => {
            if i >= budget || next.left() != budget - i - 1 {
              ok = false
            }
            let seen : Map[String, Int32] = Map([])
            for j in 0..<=i {
              seen[ops[j]] = seen.get(ops[j]).unwrap_or(0) + 1
            }
            let spent = next.spent()
            if spent.length() != seen.length() {
              ok = false
            }
            for s in spent {
              if seen.get(s.operation.name()) != Some(s.levels) {
                ok = false
              }
            }
            let mut first = -1
            for s in spent {
              let mut pos = -1
              for j in 0..<=i {
                if pos < 0 && ops[j] == s.operation.name() {
                  pos = j
                }
              }
              if pos <= first {
                ok = false
              }
              first = pos
            }
            f = next
          }
          None => break
        }
      }
      ok
    },
    count=200,
    max_size=40,
    seed=3101,
  )
}
