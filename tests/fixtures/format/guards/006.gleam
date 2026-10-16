pub fn main() {
  case wibble {
    Wibble(first_one)
      | Wibble(another_one)
      | Wibble(
        this_is_extra_long_to_go_over_the_line_limit,
        this_gets_broken_as_well,
      )
      if True
    -> Ok(wibble)
  }
}
