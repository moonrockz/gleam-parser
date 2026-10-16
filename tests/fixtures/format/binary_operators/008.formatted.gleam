pub fn main() {
  case remainder {
    _ if remainder >=. 0.5 && x >=. 0.0 ->
      float_sign(x) *. truncate_float(xabs +. 1.0) /. p
    _ -> float_sign(x) *. xabs_truncated /. p
  }
}
