fn main() {
  case pat {
    pat.Typeof("Boolean", pat)
    | pat.Typeof("Number", pat)
    | pat.Typeof("String", pat) -> Nil
  }
}
