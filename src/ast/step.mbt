// A pure trampoline for the codec. Every node encoder or decoder takes a
// continuation and returns a step instead of calling into its children;
// `run` and `run_decode` execute the steps in a loop, so the depth of the
// AST never reaches the native stack (wasm's is small). Four rules keep it
// so: enter a child only through `node`, `maybe`, `each` (or the
// decoder's `child`, `child_opt`, `child_list`, `children`); hand a result
// to a continuation only through `give` or `yield_`; leaves stay direct;
// no mutable state.

///|
/// Deferred work for the encoder: a finished value, or a thunk that gives
/// the next step.
priv enum Step[A] {
  Done(A)
  More(() -> Step[A])
}

///|
/// Run a chain of steps to its value. A loop, not a recursion.
fn[A] run(step : Step[A]) -> A {
  for s = step {
    match s {
      Done(a) => break a
      More(f) => continue f()
    }
  }
}

///|
/// Hand `value` to the continuation as a new step. A direct call `k(value)`
/// would chain every parent's continuation on the native stack when the
/// deepest leaf finishes, so every continuation call goes through `give`.
fn[A, R] give(k : (A) -> Step[R], value : A) -> Step[R] {
  More(() => k(value))
}

///|
/// Encode one child with `f` as a new step and hand its JSON to `k`.
fn[T, R] node(
  child : T,
  f : (T, (Json) -> Step[R]) -> Step[R],
  k : (Json) -> Step[R],
) -> Step[R] {
  More(() => f(child, k))
}

///|
/// Encode an optional child: `null` when absent.
fn[T, R] maybe(
  child : T?,
  f : (T, (Json) -> Step[R]) -> Step[R],
  k : (Json) -> Step[R],
) -> Step[R] {
  match child {
    Some(v) => More(() => f(v, k))
    None => give(k, Json::null())
  }
}

///|
/// Encode every element of `xs` with `f`, first element first, and hand
/// the results to `k` in order. The results are collected in an immutable
/// list and reversed once at the end.
fn[T, R] each(
  xs : ArrayView[T],
  f : (T, (Json) -> Step[R]) -> Step[R],
  k : (ArrayView[Json]) -> Step[R],
) -> Step[R] {
  fn go(i : Int32, acc : @list.List[Json]) -> Step[R] {
    if i == xs.length() {
      give(k, acc.rev().to_array()[:])
    } else {
      More(() => f(xs[i], j => go(i + 1, acc.prepend(j))))
    }
  }

  go(0, @list.List([]))
}

///|
/// Deferred work for the decoder; a step may raise `DecodeError`.
priv enum Decode[A] {
  Decoded(A)
  Decoding(() -> Decode[A] raise DecodeError)
}

///|
/// Run a chain of decode steps to its value; an error raised by a step
/// leaves here.
fn[A] run_decode(step : Decode[A]) -> A raise DecodeError {
  for s = step {
    match s {
      Decoded(a) => break a
      Decoding(f) => continue f()
    }
  }
}

///|
/// Hand `value` to the continuation as a new step (see `give`).
fn[A, R] yield_(k : (A) -> Decode[R] raise DecodeError, value : A) -> Decode[R] {
  Decoding(() => k(value))
}

///|
/// Decode every item with `f` (which also gets the item's index), first
/// item first, and hand the values to `k` in order.
fn[T, R] each_decode(
  items : ArrayView[Json],
  f : (Json, Int32, (T) -> Decode[R] raise DecodeError) -> Decode[R] raise DecodeError,
  k : (ArrayView[T]) -> Decode[R] raise DecodeError,
) -> Decode[R] {
  fn go(i : Int32, acc : @list.List[T]) -> Decode[R] {
    if i == items.length() {
      yield_(k, acc.rev().to_array()[:])
    } else {
      Decoding(() => f(items[i], i, v => go(i + 1, acc.prepend(v))))
    }
  }

  go(0, @list.List([]))
}
