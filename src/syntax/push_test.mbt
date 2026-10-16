///|
/// Records pushed events; skips arguments and stops at the first `var`.
struct Recording {
  pushed : Array[String]
}

///|
impl @syntax.Handler for Recording with fn on_enter(self, e) {
  self.pushed.push(event_label(Enter(e)))
  if e.kind == "var" {
    Stop
  } else if e.category == "arg" {
    SkipChildren
  } else {
    Continue
  }
}

///|
impl @syntax.Handler for Recording with fn on_leave(self, e) {
  self.pushed.push(event_label(Leave(e)))
}

///|
test "push_events follows the handler's SkipChildren and Stop" {
  let h : Recording = { pushed: [], }
  @syntax.push_events(
    @syntax.EventReader(root_of("pub fn f(x) {\n  f(x)\n}\n")),
    h,
  )
  @expect.expect(h.pushed).to_equal([
    "+module/module 0", "+definition/function definitions 0", "+arg/arg arguments 9",
    "-arg/arg", "+statement/expression body 16", "+expression/call expression 16",
    "+expression/var fun 16",
  ])
}

///|
/// A handler with only `on_leave`.
struct LeaveTally {
  mut tally : Int32
}

///|
impl @syntax.Handler for LeaveTally with fn on_leave(self, _) {
  self.tally = self.tally + 1
}

///|
test "a handler with only on_leave leaves every node" {
  let root = root_of(small)
  let h : LeaveTally = { tally: 0, }
  @syntax.push_events(@syntax.EventReader(root), h)
  @expect.expect(h.tally).to_equal(preorder(root).length())
}

///|
test "push_events handles 3000 nested lists" {
  let h : LeaveTally = { tally: 0, }
  @syntax.push_events(@syntax.EventReader(deep_list(3000)), h)
  @expect.expect(h.tally).to_equal(3001)
}

///|
/// An event source outside the syntax package: it replays events built
/// with `EnterEvent(...)` and `LeaveEvent(...)`.
struct Replay {
  events : Array[@syntax.Event]
  mut at : Int32
}

///|
impl @syntax.EventSource for Replay with fn next(self) {
  let e = self.events.get(self.at)
  self.at = self.at + 1
  e
}

///|
impl @syntax.EventSource for Replay with fn skip_children(_self) {
  ()
}

///|
test "an outside event source builds events with new, and push_events reads it" {
  @expect.expect_all(s => {
    let root = root_of(small)
    let path = @syntax.NodePath::root()
    let enter = @syntax.EnterEvent(
      category="module",
      kind="module",
      field=None,
      start=@span.ByteOffset::new(0).unwrap(),
      path~,
    )
    let source : Replay = {
      events: [Enter(enter), Leave(@syntax.LeaveEvent(node=root, path~))],
      at: 0,
    }
    let h : Recording = { pushed: [], }
    @syntax.push_events(source, h)
    s.expect(h.pushed).to_equal(["+module/module 0", "-module/module"])
    s.expect(enter.depth).to_equal(@syntax.NodeDepth::new(0).unwrap())
  })
}
