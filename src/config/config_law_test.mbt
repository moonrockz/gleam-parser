///|
/// A partial with each field set or unset, values from a small set.
struct Layer(@config.Partial) derive(@debug.Debug)

///|
fn pick_dialect(i : Int32) -> @dialect.Dialect? {
  match i % 3 {
    0 => None
    1 => Some(@dialect.Dialect::gleam_1_19())
    _ => Some({ ..@dialect.Dialect::gleam_1_19(), deprecations: [][:], })
  }
}

///|
fn pick_fuel(i : Int32) -> @fuel.Budget? {
  match i % 4 {
    0 => None
    1 => @fuel.Budget::from_int(1)
    2 => @fuel.Budget::from_int(7)
    _ => Some(@fuel.default_budget)
  }
}

///|
impl @quickcheck.Arbitrary for Layer with fn arbitrary(_size, rs) {
  Layer({
    dialect: pick_dialect(rs.next_int().abs()),
    fuel: pick_fuel(rs.next_int().abs()),
  })
}

///|
impl @quickcheck.Shrink for Layer with fn shrink(_self) {
  [].iter()
}

///|
test "law: empty is the identity of with_fallback" {
  @quickcheck.check(
    (l : Layer) => {
      let Layer(p) = l
      p.with_fallback(@config.Partial::empty()) == p &&
      @config.Partial::empty().with_fallback(p) == p
    },
    count=100,
    seed=3201,
  )
}

///|
test "law: with_fallback is associative" {
  @quickcheck.check(
    (t : (Layer, Layer, Layer)) => {
      let (Layer(a), Layer(b), Layer(c)) = t
      a.with_fallback(b).with_fallback(c) == a.with_fallback(b.with_fallback(c))
    },
    count=200,
    seed=3202,
  )
}

///|
test "law: with_fallback is idempotent" {
  @quickcheck.check(
    (l : Layer) => {
      let Layer(p) = l
      p.with_fallback(p) == p
    },
    count=100,
    seed=3203,
  )
}

///|
test "law: a full partial ignores its fallback; an empty one takes it whole" {
  @quickcheck.check(
    (t : (Layer, Layer)) => {
      let (Layer(a), Layer(b)) = t
      let c = a.to_config(@config.Config::default())
      let d = b.to_config(@config.Config::default())
      c.to_partial().to_config(d) == c &&
      @config.Partial::empty().to_config(d) == d
    },
    count=100,
    seed=3204,
  )
}

///|
/// A TOML writer for the law only: `from_toml(to_toml(p))` gives the
/// layer back, dialects compared by version.
fn to_toml(p : @config.Partial) -> String {
  let sb = StringBuilder()
  sb.write_string("[parser]\n")
  if p.dialect is Some(d) {
    sb.write_string("gleam = \"\{d.version()}\"\n")
  }
  if p.fuel is Some(b) {
    sb.write_string("fuel = \{b.units()}\n")
  }
  sb.to_string()
}

///|
test "law: from_toml after to_toml gives the layer back (dialects by version)" {
  @quickcheck.check(
    (l : Layer) => {
      let Layer(p) = l
      let back = @config.Config::from_toml(to_toml(p)) catch {
        _ => return false
      }
      back.dialect.map(d => d.version()) == p.dialect.map(d => d.version()) &&
      back.fuel == p.fuel
    },
    count=100,
    seed=3205,
  )
}
