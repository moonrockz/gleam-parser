///|
test "law: Tree::step and Tree::field_of agree with the parent's field_of and with node_path" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let (tree, _, _, nodes) = module_tree(m)
      nodes
      .iter()
      .all(n => {
        match tree.parent(n) {
          None => tree.step(n) is None && tree.field_of(n) is None
          Some(parent) =>
            match tree.step(n) {
              Some(step) =>
                tree.field_of(n) == Some(step.field) &&
                parent.field_of(n) == Some(step.field) &&
                parent.field(step.field).get(step.index.to_int()).map(tag) ==
                Some(tag(n)) &&
                tree.node_path(n).bind(p => p.last()) == Some(step)
              None => false
            }
        }
      })
    },
    count=100,
    max_size=10,
    seed=2191,
  )
}

///|
test "law: a tree's node_path of every node is the reader's path at that node" {
  @quickcheck.check(
    (m : @lawkit.GleamModule) => {
      let (tree, _, _, nodes) = module_tree(m)
      let paths = reader_paths(tree.root())
      paths.length() == nodes.length() &&
      nodes
      .iter()
      .zip(paths.iter())
      .all(pair => tree.node_path(pair.0) == Some(pair.1))
    },
    count=100,
    max_size=10,
    seed=2192,
  )
}
