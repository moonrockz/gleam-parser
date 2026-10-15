///|
/// Receives pushed events. `on_enter` steers the traversal like a walk's
/// `enter`; both methods have defaults (`Continue`, nothing). See
/// `push_events` for an example.
pub(open) trait Handler {
  fn on_enter(Self, EnterEvent) -> Control = _
  fn on_leave(Self, LeaveEvent) -> Unit = _
}

///|
impl Handler with fn on_enter(_self, _event) {
  Continue
}

///|
impl Handler with fn on_leave(_self, _event) {
  ()
}

///|
/// Pull every event from `source` and push it to `handler`: `on_enter`
/// for `Enter` (its `SkipChildren` skips the node's children, its `Stop`
/// ends the run) and `on_leave` for `Leave`. The source is usually an
/// `EventReader`; a streaming parser can implement `EventSource` too, and
/// handlers do not change.
///
/// A handler needs its own type, so this example is not a doc test (a doc
/// test holds only `test` blocks). The cookbook article "Choose a
/// traversal" has a tested handler:
/// https://github.com/moonrockz/gleam-parser/blob/main/docs/cookbook/traverse.mbt.md
///
/// ```mbt nocheck
/// struct Paths {
///   found : Array[String]
/// }
///
/// impl @gleam.Handler for Paths with fn on_enter(self, e) {
///   if e.category == "arg" {
///     self.found.push(e.path.to_string())
///   }
///   Continue
/// }
///
/// test {
///   let root = @gleam.NodeRef::of_result(
///     @gleam.parse_text("pub fn add(a, b) {\n  a + b\n}\n"),
///   )
///   let paths : Paths = { found: [], }
///   @gleam.push_events(@gleam.EventReader::new(root), paths)
///   inspect(paths.found[1], content="definitions[0].arguments[1]")
/// }
/// ```
pub fn[S : EventSource, H : Handler] push_events(
  source : S,
  handler : H,
) -> Unit {
  while source.next() is Some(event) {
    match event {
      Enter(e) =>
        match handler.on_enter(e) {
          Continue => ()
          SkipChildren => source.skip_children()
          Stop => return
        }
      Leave(e) => handler.on_leave(e)
    }
  }
}
