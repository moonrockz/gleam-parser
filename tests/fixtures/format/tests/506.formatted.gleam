pub fn main() {
  [
    "Success!"
      |> ansi(apply: [1, 31]),
    "",
    "Wrote `" <> bin <> "`, `" <> pwsh_bin <> "`",
  ]
}
