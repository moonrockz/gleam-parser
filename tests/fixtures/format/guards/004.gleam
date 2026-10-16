pub fn main() {
  case list.map(codepoints, string.utf_codepoint_to_int) {
    [drive, colon, slash]
      if { slash == 47 || slash == 92 }
      && colon == 58
      // Hello
      && drive >= 65
      && drive <= 90
      // This is a comment
      || drive >= 97
      // And another one
      && drive <= 122
    -> {
      1
      |> 2
    }
  }
}
