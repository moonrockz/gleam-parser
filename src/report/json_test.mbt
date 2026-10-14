///|
test "encode_diagnostics writes every field" {
  let r = @parser.parse_text("fn f(a, b) {\n  [1, ..a, ..b]\n}\n")
  let j = @report.encode_diagnostics(r.diagnostics)
  inspect(
    j.stringify(),
    content=(
      #|[{"code":"GL-PARSE-001","kind":"ListSpreadWithAnotherSpread","severity":"error","title":"Syntax error","message":"I wasn't expecting a second list here","span":{"start":24,"end":26},"labels":[{"span":{"start":19,"end":21},"text":"You're using a list here"}],"text":"Lists are immutable and singly-linked, so to join two or more lists\nall the elements of the lists would need to be copied into a new list.\nThis would be slow, so there is no built-in syntax for it.","hint":null}]
    ),
  )
}
