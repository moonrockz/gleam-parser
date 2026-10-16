// Fuel: the recursion budget of the parser and of every other recursive
// operation of the library, as the Scala 3.10 compiler counts it. One
// unit per nested entry of a fuel-checked operation; the budget is a
// value, so leaving a scope gives the outer budget back by construction.

///|
/// Units of fuel, at least 1.
///
/// ```mbt check
/// test {
///   debug_inspect(@fuel.Budget::new(100).map(b => b.units()), content="Some(100)")
///   debug_inspect(@fuel.Budget::new(0), content="None")
/// }
/// ```
pub struct Budget(Int32) derive(Eq, Compare, Debug)

///|
/// A budget of `units`; `None` below 1.
pub fn Budget::new(units : Int32) -> Budget? {
  if units >= 1 {
    Some(Budget(units))
  } else {
    None
  }
}

///|
/// The number of units.
pub fn Budget::units(self : Budget) -> Int32 {
  self.0
}

///|
/// The default budget, 100 units: measured safe on wasm, the smallest
/// stack (it overflows at about 140 nested lists). Raise it only on
/// native or js.
pub let default_budget : Budget = Budget(100)

///|
/// The name of a fuel-checked operation (`expression`, `pattern`, ...).
/// Each package that spends fuel defines its operations as constants.
pub(all) struct Operation(String) derive(Eq, Hash, Debug)

///|
/// The operation's name.
pub fn Operation::name(self : Operation) -> String {
  self.0
}

///|
/// One operation on the stack with the number of nested levels it holds.
pub(all) struct Spent {
  operation : Operation
  levels : Int32
} derive(Eq, Debug)

///|
/// An immutable fuel value: the budget, the units not yet spent, and the
/// operations on the stack (innermost first). `spend` gives a new value;
/// there is no restore: the enclosing operation keeps its own `Fuel`.
///
/// ```mbt check
/// test {
///   let f = @fuel.Fuel(budget=@fuel.Budget::new(2).unwrap())
///   let inner = f.spend(@fuel.Operation("expression"))
///   inspect(inner.left(), content="1")
///   inspect(f.left(), content="2")
/// }
/// ```
pub struct Fuel {
  budget : Budget
  left : Int32
  ops : @list.List[Operation]
} derive(Eq, Debug)

///|
/// A full budget (`default_budget` when none is given).
#alias(new, deprecated="Use `Fuel(...)` instead")
pub fn Fuel::Fuel(budget~ : Budget = default_budget) -> Fuel {
  { budget, left: budget.units(), ops: @list.List([]), }
}

///|
/// Enter a nested operation: one unit less, `op` on the stack. Raises
/// `FuelExhausted` with the budget and the stack when no unit is left.
pub fn Fuel::spend(self : Fuel, op : Operation) -> Fuel raise FuelExhausted {
  if self.left == 0 {
    raise FuelExhausted(budget=self.budget, spent=self.spent())
  }
  { budget: self.budget, left: self.left - 1, ops: self.ops.prepend(op), }
}

///|
/// The units not yet spent.
pub fn Fuel::left(self : Fuel) -> Int32 {
  self.left
}

///|
/// The budget this fuel started with.
pub fn Fuel::budget(self : Fuel) -> Budget {
  self.budget
}

///|
/// The distinct operations on the stack, outermost first, each with the
/// number of levels it holds.
pub fn Fuel::spent(self : Fuel) -> Array[Spent] {
  let out : Array[Spent] = []
  for op in self.ops.rev() {
    let mut found = false
    for i, s in out {
      if s.operation == op {
        out[i] = { operation: op, levels: s.levels + 1, }
        found = true
        break
      }
    }
    if !found {
      out.push({ operation: op, levels: 1, })
    }
  }
  out
}

///|
/// The budget ran out: `spent` is the stack at that moment, outermost
/// first.
pub(all) suberror FuelExhausted {
  FuelExhausted(budget~ : Budget, spent~ : Array[Spent])
} derive(Eq, Debug)
