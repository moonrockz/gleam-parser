pub type Point {
  Point(x: Int, y: Int)
}

fn records(p: Point) {
  let q = Point(..p, x: 1)
  let r = Point(..p, x: 1, y: 2)
  let s = Point(..p)
  let t = Point(x: 1, y: 2)
  let u = Point(1, 2)
  let v = module.Point(..p, y:)
  let w = p.x + q.y
  let acc = p.x.y.z
  let idx = #(1, 2).0
  let deep = #(#(1, 2), 3).0.1
  w + acc + idx + deep
}
