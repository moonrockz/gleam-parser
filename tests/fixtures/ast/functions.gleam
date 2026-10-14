import gleam/io

/// Docs for main.
pub fn main() {
  io.println("hi")
}

@deprecated("gone")
@internal
pub fn labelled(label name: String, _ignored: Int, _: Bool) -> String {
  name
}

@external(erlang, "erlang", "length")
@external(javascript, "./ffi.mjs", "length")
pub fn length(list: List(a)) -> Int

@target(erlang)
fn only_erlang() {
  Nil
}

fn body_statements(x: Int) -> Int {
  let y = x + 1
  let assert Ok(z) = Ok(y)
  let assert Ok(w) = Ok(z) as "message"
  let #(a, b): #(Int, Int) = #(1, 2)
  assert a < b
  assert w == 3 as "w"
  use q <- apply(a)
  use <- apply_unit
  use r, s <- two(q)
  r + s
}

fn apply(x, f) {
  f(x)
}
