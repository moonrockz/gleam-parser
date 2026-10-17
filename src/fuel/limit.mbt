///|
/// An optional limit on syntax nesting. `Unlimited` is the parser default.
/// A finite limit is a caller policy and is independent of machine stack size.
///
/// ```mbt check
/// test {
///   let limit : @fuel.NestingLimit = Limited(@fuel.Budget(500))
///   debug_inspect(limit.budget().map(b => b.units()), content="Some(500)")
///   debug_inspect(@fuel.NestingLimit::Unlimited.budget(), content="None")
/// }
/// ```
pub(all) enum NestingLimit {
  Unlimited
  Limited(Budget)
} derive(Eq, Debug)

///|
/// Return the finite budget, or `None` when nesting is unrestricted.
pub fn NestingLimit::budget(self : NestingLimit) -> Budget? {
  match self {
    Unlimited => None
    Limited(budget) => Some(budget)
  }
}
