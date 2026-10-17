# Run grammar continuations on a synchronous executor

Use MoonBit's compiler-generated continuations for the parser, formatter
and recursive AST equality and debug representation. A local executor
resumes one continuation at a time. Suspend before recursive descent and
on return, including error unwinding. This keeps the compiler port's
grammar functions, typed errors and cleanup scopes without a manual frame
variant for every grammar stage.

The executor isolates `%async.run` and `%async.suspend`, the compiler
primitives also used by MoonBit's core lexbuf tests. It needs no async
runtime, event loop, host async imports or public async entry points.
The pinned MoonBit toolchain and tests on wasm, wasm-gc, JavaScript and
native guard this compiler dependency. A 100,000-level executor test checks
descent, return and errors. Parser tests exercise all recursive grammar
families at 10,000 levels. Memory grows with the pending work.

`Config.fuel` is `NestingLimit`, either `Unlimited` or `Limited(Budget)`.
Default parsing and formatting are unlimited. Finite limits remain caller
policy. Configuration layers distinguish an absent field from an explicit
`Unlimited`, so a caller or environment can clear a file's limit.
