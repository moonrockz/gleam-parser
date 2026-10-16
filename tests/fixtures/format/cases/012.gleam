fn main() {
  do_diff_attributes(rest, case attr.value == old.value {
    True -> added
    False -> [attr, ..added]
  })
}
