///|
/// How the items of a list or the segments of a bit array are packed.
priv enum ItemsPacking {
  FitOnePerLine
  FitMultiplePerLine
  BreakOnePerLine
}

///|
/// The compiler's `bit_array`: lay out formatted segments.
fn Formatter::bit_array(
  self : Formatter,
  segments : Array[@pretty.Doc],
  packing : ItemsPacking,
  location : @span.SrcSpan,
) -> @pretty.Doc {
  let comments = self.pop_comments(location.end)
  let comments_doc = printed_comments(comments[:], false)
  if segments.is_empty() {
    return match comments_doc {
      None => t("<<>>")
      Some(c) =>
        @pretty.force_break(
          t("<<") + nest(empty_break) + c + empty_break + t(">>"),
        )
    }
  }
  let comma = match packing {
    FitMultiplePerLine => flex_comma
    FitOnePerLine | BreakOnePerLine => comma_break
  }
  let doc = nest(open_bit_array_break + @pretty.join(segments, comma))
  let doc = match comments_doc {
    None => doc + trailing_comma_break + t(">>")
    Some(c) =>
      @pretty.force_break(
        doc + nest(trailing_comma_break) + nest(c) + line_doc + t(">>"),
      )
  }
  match packing {
    FitOnePerLine | FitMultiplePerLine => group(doc)
    BreakOnePerLine => @pretty.force_break(doc)
  }
}

///|
/// The compiler's `bit_array_segment`.
fn[V] bit_array_segment(
  segment : @ast.BitArraySegment[V],
  to_doc : (V) -> @pretty.Doc raise FormatError,
) -> @pretty.Doc raise FormatError {
  if segment.options.is_empty() {
    return to_doc(segment.value)
  }
  let options = []
  for o in segment.options {
    options.push(segment_option(o, to_doc))
  }
  to_doc(segment.value) + t(":") + @pretty.join(options, t("-"))
}

///|
/// The compiler's `segment_option`.
fn[V] segment_option(
  option : @ast.BitArrayOption[V],
  to_doc : (V) -> @pretty.Doc raise FormatError,
) -> @pretty.Doc raise FormatError {
  match option {
    Bytes(..) => t("bytes")
    Bits(..) => t("bits")
    Int(..) => t("int")
    Float(..) => t("float")
    Utf8(..) => t("utf8")
    Utf16(..) => t("utf16")
    Utf32(..) => t("utf32")
    Utf8Codepoint(..) => t("utf8_codepoint")
    Utf16Codepoint(..) => t("utf16_codepoint")
    Utf32Codepoint(..) => t("utf32_codepoint")
    Signed(..) => t("signed")
    Unsigned(..) => t("unsigned")
    Big(..) => t("big")
    Little(..) => t("little")
    Native(..) => t("native")
    Size(value~, short_form~, ..) =>
      if short_form {
        to_doc(value)
      } else {
        t("size") + t("(") + to_doc(value) + t(")")
      }
    Unit(value~, ..) =>
      t("unit") + t("(") + t(value.to_int().to_string()) + t(")")
  }
}
