pub fn main() {
  case wibble, wobble, wubble {
    Wibble(one_thing, something_else, wibble),
      Wobble(this_will_go_over_the_line_limit, wobble),
      Wubble(this_will_go_over_the_line_limit, wubble)
    | Wibble(a), Wobble(b), Wubble(c)
    | Wibble(one_thing, something_else, wibble),
      Wobble(this_will_go_over_the_line_limit, wobble),
      Wubble(this_will_go_over_the_line_limit, wubble)
      if { wibble || wobble }
      && { wibble || wobble && wibble > 10 }
      || wobble < 10_000_000
    -> todo
  }
}
