pub fn main() {
  function(
    arg0,
    thing
      |> string.replace(
        "{something something}",
        date.month_to_string(month, config.l10n.context),
      ),
  )
}
