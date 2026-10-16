pub fn main(
  // a function with argument comments
  a: fn(
    // Int,
    String,
    Int,
    // this is A
    String,
    // this is B
    String,
    fn(
      // an inner fn, fn arg
      Int,
      // trailing comment
    ) -> String,
    // multiple lines
    // for a really interesting
    // comment
    Bool,
    // trailing comment
  ) -> Nil,
  // a function with no argument comments
  b: fn(Int) -> Nil,
  c: fn() -> Nil,
) {
  todo
}
