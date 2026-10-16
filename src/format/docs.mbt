///|
/// The compiler's indentation step.
let indent : Int32 = 2

///|
fn t(s : String) -> @pretty.Doc {
  @pretty.text(s)
}

///|
/// pretty-arena's `group`: the document fits on its own.
fn group(d : @pretty.Doc) -> @pretty.Doc {
  @pretty.group_alone(d)
}

///|
fn nest(d : @pretty.Doc) -> @pretty.Doc {
  @pretty.nest(indent, d)
}

///|
fn nest_if_broken(d : @pretty.Doc) -> @pretty.Doc {
  @pretty.nest_if_broken(indent, d)
}

///|
let line_doc : @pretty.Doc = @pretty.lines(1)

///|
let two_lines_doc : @pretty.Doc = @pretty.lines(2)

///|
let flex_comma : @pretty.Doc = @pretty.flex_break(",", ", ")

///|
let empty_break : @pretty.Doc = @pretty.break_("", "")

///|
let breakable_space : @pretty.Doc = @pretty.break_("", " ")

///|
let comma_break : @pretty.Doc = @pretty.break_(",", ", ")

///|
let trailing_comma_break : @pretty.Doc = @pretty.break_(",", "")

///|
let open_curly_break : @pretty.Doc = @pretty.break_("{", "{ ")

///|
let open_square_break : @pretty.Doc = @pretty.break_("[", "[")

///|
let open_paren_break : @pretty.Doc = @pretty.break_("(", "(")

///|
let open_bit_array_break : @pretty.Doc = @pretty.break_("<<", "<<")

///|
/// Lexicographic order of UTF-16 code units (the compiler orders bytes;
/// the two agree on ASCII). `String::compare` is length-first, so it is
/// not used.
fn lexicographic(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let x = a.code_units()[i].to_int()
    let y = b.code_units()[i].to_int()
    if x != y {
      return if x < y { -1 } else { 1 }
    }
  }
  a.length().compare(b.length())
}

///|
/// A stable sort (`Array::sort_by` is not stable past 16 elements; the
/// compiler's `sorted_by` is): equal keys keep their order.
fn[A] stable_sort_by(xs : Array[A], cmp : (A, A) -> Int32) -> Array[A] {
  let indexed = xs.mapi((i, x) => (i, x))
  indexed.sort_by((a, b) => {
    let c = cmp(a.1, b.1)
    if c != 0 {
      c
    } else {
      a.0.compare(b.0)
    }
  })
  indexed.map(p => p.1)
}

///|
/// `pub ` for a public or internal definition (the compiler's `pub_`).
fn pub_(publicity : @ast.Publicity) -> @pretty.Doc {
  match publicity {
    Public | Internal(..) => t("pub ")
    Private => @pretty.empty()
  }
}

///|
/// The compiler's `wrap_block`.
fn wrap_block(doc : @pretty.Doc) -> @pretty.Doc {
  nest(open_curly_break + doc) + breakable_space + t("}")
}
