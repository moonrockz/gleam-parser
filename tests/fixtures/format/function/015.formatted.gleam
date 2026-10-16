pub fn main() {
  html([attribute("lang", "en")], [
    head([attribute("wibble", "wobble")], [
      title([], [text("Hello this is some HTML")]),
    ]),
    body([], [h1([], [text("Hello, world!")])]),
  ])
}
