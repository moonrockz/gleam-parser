pub fn do_len(list, acc) {
  case list {
    [] -> acc
    [_, ..rest] -> rest |> do_len(acc + 1)
    // Even the opposite wouldn't be optimised:
    // { acc + 1 } |> do_len(rest, _)
  }
}
