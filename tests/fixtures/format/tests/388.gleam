type Triple {
  Triple(a: Int, b: Int, c: Int)
}

fn main() {
  let triple = Triple(1, 2, 3)
  let Triple(the_a, c: the_c, ..) = triple
  the_c
}
