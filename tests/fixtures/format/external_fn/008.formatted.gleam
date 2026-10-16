@external(javascript, "./client-component.ffi.mjs", "register")
pub fn register(
  _app: App(WebComponent, Nil, model, msg),
  _name: String,
) -> Result(Nil, Error) {
  Error(NotABrowser)
}
