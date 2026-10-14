@external(erlang, "erlang", "length")
@external(javascript, "./ffi.mjs", "length")
pub fn length(list: List(a)) -> Int

@external(erlang, "mod", "fun",)
fn trailing(x: Int) -> Int

@target(erlang)
@deprecated("use other")
@internal
pub fn only_erlang() {
  Nil
}

@target(javascript)
pub const js_only = 1

@deprecated("gone")
pub type Old {
  @deprecated("use New")
  OldVariant
  New
}

@internal
pub type Hidden =
  Int

@external(erlang, "ets", "table")
@external(javascript, "./ffi.mjs", "table")
pub type Table

@deprecated("old alias")
pub type Alias(a) =
  List(a)
