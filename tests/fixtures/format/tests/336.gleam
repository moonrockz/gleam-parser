fn main() {
  case pat {
    // Hello Ada
    pat.Typeof("Boolean", pat) | pat.Typeof("Number", pat) -> True

    // Hello Alan
    pat.Typeof("Boolean", pat)
    | pat.Typeof("Number", pat)
    | pat.Typeof("String", pat) -> False
  }
}
