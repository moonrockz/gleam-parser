fn guards(x, y) {
  case x, y {
    a, b if a == b -> 1
    a, b if a != b && a > 1 || b < 2 -> 2
    a, _ if a >= 1 && a <= 2 -> 3
    a, b if a.0 == b.1 -> 4
    a, b if a.field == b.other.field -> 5
    a, b if !{ a || b } -> 6
    a, b if a +. 1.0 >. b *. 2.0 -. 0.5 /. 2.0 -> 7
    a, b if a + 1 > b * 2 - 3 / 4 % 5 -> 8
    a, b if a <> "s" == b -> 9
    a, _ if a == Some(1) || a == option.None -> 10
    a, _ if a == <<1>> || a == #(1, 2) || a == [1] -> 11
    a, _ if a <. 1.0 || a <=. 2.0 || a >=. 3.0 -> 12
    _, _ -> 0
  }
}
