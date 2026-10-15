///|
/// The first place where two JSON values differ.
priv struct Difference {
  path : String
  expected : Json
  actual : Json
}

///|
/// Depth-first search for the first difference; object keys are visited in
/// sorted order. Returns `None` when the values are equal.
fn first_difference(expected : Json, actual : Json) -> Difference? {
  diff_at("$", expected, actual)
}

///|
fn diff_at(path : String, expected : Json, actual : Json) -> Difference? {
  match (expected, actual) {
    (Array(e), Array(a)) => {
      let n = if e.length() < a.length() { e.length() } else { a.length() }
      for i in 0..<n {
        if diff_at("\{path}[\{i}]", e[i], a[i]) is Some(d) {
          return Some(d)
        }
      }
      if e.length() != a.length() {
        Some({ path, expected, actual, })
      } else {
        None
      }
    }
    (Object(e), Object(a)) => {
      let keys = e.keys().collect()
      for k in a.keys() {
        if !e.contains(k) {
          keys.push(k)
        }
      }
      keys.sort()
      for k in keys {
        match (e.get(k), a.get(k)) {
          (Some(ev), Some(av)) =>
            if diff_at("\{path}.\{k}", ev, av) is Some(d) {
              return Some(d)
            }
          _ => return Some({ path: "\{path}.\{k}", expected, actual, })
        }
      }
      None
    }
    (Number(e, ..), Number(a, ..)) =>
      if e == a {
        None
      } else {
        Some({ path, expected, actual, })
      }
    _ =>
      if expected == actual {
        None
      } else {
        Some({ path, expected, actual, })
      }
  }
}

///|
let brief_width : Int32 = 120

///|
/// A JSON value as compact canonical text, cut to `brief_width` characters
/// with `...` at the end when longer.
fn brief(json : Json) -> String {
  let text = @gleam.canonical(json)
  if text.length() <= brief_width {
    text
  } else {
    text.view(end_offset=brief_width - 3).to_owned() + "..."
  }
}
