type SillyResult(a, e) {
  Ok(
    first_value_with_really_long_name: a,
    second_value_with_really_long_name: a,
  )
  Error(error: e)
}
