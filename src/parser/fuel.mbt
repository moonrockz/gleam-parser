///|
/// The operations the parser spends fuel on: one per nesting site.
let op_expression : @fuel.Operation = @fuel.Operation("expression")

///|
let op_pattern : @fuel.Operation = @fuel.Operation("pattern")

///|
let op_type : @fuel.Operation = @fuel.Operation("type")

///|
let op_constant : @fuel.Operation = @fuel.Operation("constant")

///|
let op_clause_guard : @fuel.Operation = @fuel.Operation("clause guard")

///|
let op_bit_array_size : @fuel.Operation = @fuel.Operation("bit array size")
