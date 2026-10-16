type Triple {
  Triple(a: Int, b: Int, c: Int)
}

fn main() {
  let triple = Triple(1, 2, 3)
  let Triple(
    really_really_long_variable_name_a,
    c: really_really_long_variable_name_c,
    ..,
    // comment
  ) = triple
  really_really_long_variable_name_c
}
