///|
/// A nesting construct of Gleam, for the depth laws.
pub(all) enum Construct {
  List
  Tuple
  Block
  Call
  FnBody
  Case
  PatternList
  TypeTuple
  ConstantList
  Negation
} derive(Eq, Debug, Hash)

///|
pub fn Construct::all() -> Array[Construct] {
  [
    List,
    Tuple,
    Block,
    Call,
    FnBody,
    Case,
    PatternList,
    TypeTuple,
    ConstantList,
    Negation,
  ]
}

///|
fn repeat(s : String, n : Int32) -> String {
  let sb = StringBuilder()
  for _ in 0..<n {
    sb.write_string(s)
  }
  sb.to_string()
}

///|
/// A complete module with `construct` nested `depth` deep around a leaf.
///
/// ```mbt check
/// test {
///   inspect(@lawkit.nested(Tuple, 2), content="fn f() {\n  #(#(1))\n}\n")
/// }
/// ```
pub fn nested(construct : Construct, depth : Int32) -> String {
  match construct {
    List => "fn f() {\n  \{repeat("[", depth)}1\{repeat("]", depth)}\n}\n"
    Tuple => "fn f() {\n  \{repeat("#(", depth)}1\{repeat(")", depth)}\n}\n"
    Block => "fn f() {\n  \{repeat("{ ", depth)}1\{repeat(" }", depth)}\n}\n"
    Call => "fn f() {\n  \{repeat("f(", depth)}1\{repeat(")", depth)}\n}\n"
    FnBody =>
      "fn f() {\n  \{repeat("fn() { ", depth)}1\{repeat(" }", depth)}\n}\n"
    Case =>
      "fn f() {\n  \{repeat("case 1 { 1 -> ", depth)}1\{repeat(" }", depth)}\n}\n"
    PatternList =>
      "fn f(x) {\n  case x {\n    \{repeat("[", depth)}_\{repeat("]", depth)} -> 1\n  }\n}\n"
    TypeTuple => "type T =\n  \{repeat("#(", depth)}Int\{repeat(")", depth)}\n"
    ConstantList => "const x = \{repeat("[", depth)}1\{repeat("]", depth)}\n"
    Negation => "fn f(x) {\n  \{repeat("!", depth)}x\n}\n"
  }
}
