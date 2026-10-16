pub fn main() {
  case list.map(codepoints, string.utf_codepoint_to_int) {
    [drive, colon, slash]
      if { slash == 47 || slash == 92 }
      && colon == 58
      && drive >= 65
      && drive <= 90
      || drive >= 97
      && drive <= 122
    -> {
      1
      |> 2
    }
  }
}
