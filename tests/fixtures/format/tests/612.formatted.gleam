pub fn main() {
  #(
    #(some_long_name, unbalanced(shift, before)),
    #(shift, unbalanced(shift, after)),
  )
}
