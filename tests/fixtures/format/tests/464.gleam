fn main() {
  let is_enabled = False
  let is_confirmed = False
  let is_admin = True
  case is_enabled, is_confirmed, is_admin {
    is_enabled, is_confirmed, is_admin
      if { is_enabled && is_confirmed } || is_admin
    -> Nil
    _, _, _ -> Nil
  }
}
