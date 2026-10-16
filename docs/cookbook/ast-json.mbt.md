# Read and write the AST as JSON

The AST mirrors the Gleam compiler's untyped AST. `encode_parsed` writes the
canonical JSON of `docs/ast-json.md`; `decode_parsed` reads it back. Until
the parser lands, build an AST by hand or read one that the oracle wrote.

```mbt check
///|
test "aj: encode a tiny module and read it back" {
  let span = @gleam.SrcSpan::from_ints(0, 9).unwrap()
  let value : @gleam.Constant = Int(
    location=@gleam.SrcSpan::from_ints(10, 11).unwrap(),
    value="1",
    int_value=BigInt::from_int(1),
  )
  let parsed : @gleam.Parsed = {
    module_: {
      definitions: [
        @gleam.TargetedDefinition::{
          definition: @gleam.Definition::ModuleConstant({
            documentation: None,
            location: span,
            publicity: @gleam.Publicity::Private,
            name: "x",
            name_location: @gleam.SrcSpan::from_ints(6, 7).unwrap(),
            annotation: None,
            value,
            deprecation: @gleam.Deprecation::NotDeprecated,
          }),
          target: None,
        },
      ][:],
    },
    extra: @gleam.ModuleExtra::empty(),
    warnings: [][:],
  }
  let text = @gleam.canonical(@gleam.encode_parsed(parsed))
  @expect.expect_all(e => {
    e.expect(text.has_prefix("{\"extra\":")).to_be_true()
    e.expect(@gleam.decode_parsed(@json.parse(text))).to_equal(parsed)
  })
}
```

A decode error names the JSON path of the problem:

```mbt check
///|
test "aj: a decode error names the path" {
  let bad = @json.parse(
    "{\"kind\":\"var\",\"location\":{\"end\":1,\"start\":0}}",
  )
  let message = try {
    @gleam.decode_expr(bad) |> ignore
    "no error"
  } catch {
    @gleam.DecodeError::DecodeError(path~, message~) => "\{path}: \{message}"
  }
  @expect.expect(message).to_equal("$.name: missing field")
}
```
