type SillyResult(a, e) {
  Ok(
    first_value_with_really_long_name: a,
    second_value_with_really_long_name: List(
      #(Int, fn(a, a, a, a, a, a, a) -> List(a)),
    ),
  )
  Error(error: e)
}
