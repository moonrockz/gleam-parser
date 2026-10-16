fn main() {
  do_diff_attributes(
    dict.delete(prev, attr.name),
    rest,
    case attr.value == old.value {
      True -> added
      False -> [attr, ..added]
    },
  )
}
