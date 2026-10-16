pub fn main() {
  <<
    1:1,
    1:1,
    0:2,
    opcode:4,
    masked:1,
    length_section:bits,
    mask_key:bits,
    data:bits,
  >>
  |> bytes_tree.from_bit_array
}
