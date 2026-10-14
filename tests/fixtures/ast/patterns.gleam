fn patterns(x) {
  case x {
    1 | 2 | 3 -> "int"
    1.5 -> "float"
    "s" -> "string"
    "pre" <> rest -> rest
    "pre" as whole <> rest -> whole
    "all" as s -> s
    [] -> "empty"
    [a] -> "one"
    [a, b, ..rest] -> "many"
    [_, ..] -> "some"
    #(a, b) -> "tuple"
    Some(y) -> "some"
    option.Some(y: 1, z:, ..) -> "labelled"
    Ok(_) as result -> "as"
    <<1, 2:size(x), rest:bits>> -> "bits"
    <<a:8-unit(2), b:utf8, c:float-little, d:int-signed-big, e:utf16_codepoint>> -> "options"
    <<n:size(a + b * 2 - { c / 3 } % 4)>> -> "size expression"
    _ -> "any"
  }
}
