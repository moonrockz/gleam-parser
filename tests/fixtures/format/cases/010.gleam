fn main() {
  case
    is_all_uppercase(remark),
    string.ends_with(remark, "?"),
    string.trim(remark) == ""
  {
    _, _, _ -> todo
  }
}
