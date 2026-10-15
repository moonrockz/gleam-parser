///|
/// The operations the parser spends fuel on: one per nesting site.
let op_expression : @fuel.Operation = @fuel.Operation::new("expression")

///|
let op_pattern : @fuel.Operation = @fuel.Operation::new("pattern")

///|
let op_type : @fuel.Operation = @fuel.Operation::new("type")

///|
let op_constant : @fuel.Operation = @fuel.Operation::new("constant")

///|
let op_clause_guard : @fuel.Operation = @fuel.Operation::new("clause guard")

///|
let op_bit_array_size : @fuel.Operation = @fuel.Operation::new("bit array size")
