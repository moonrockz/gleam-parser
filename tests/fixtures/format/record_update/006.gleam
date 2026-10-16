pub fn example() {
  Record(..record, field: {
    use _ <- list.map(record.field)
    io.print("Example")
  })
}
