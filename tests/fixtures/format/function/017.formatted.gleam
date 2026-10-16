pub fn main() {
  tbd.workbook(for: "my_project")
  |> task(
    doc: "Run the project tests",
    tags: list.concat([["test", "ci"], gleam, typescript]),
    action: fn(_, _) { tbd.command(run: "gleam", with: ["test"]) },
  )
  |> run
}
