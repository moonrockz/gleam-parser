# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Overview

This module (`moonrockz/gleam-parser`) is a **parser and parsing utilities**
library for the [Gleam](https://gleam.run) programming language. One expected
user is [morphir-moonbit](https://github.com/finos/morphir-moonbit). It gives,
in stages (bd epics `v0.1`, `v0.2`, `v0.3`):

- **Scanner** — lossless tokenization. Each token's `trivia_before`, `lexeme`
  and `trivia_after` rebuild the source; spans are UTF-8 byte offsets, as in
  the Gleam compiler.
- **Parser** — a recursive-descent port of the compiler's `parse.rs`, with
  recovery per definition.
- **AST** — a mirror of the compiler's untyped AST at v1.19.2, with a
  canonical JSON encoder and decoder.
- **CST** — every token and definition, with trivia.
- **Syntax tree** (v0.2) — read-only node model and traversal.
- **Printer and formatter** (v0.3) — Gleam source with `gleam format` parity.

### Gleam reference

The reference is the Gleam compiler at tag `v1.19.2`
(<https://github.com/gleam-lang/gleam>). Sources that define behaviour:
`compiler-core/src/parse/lexer.rs`, `parse/token.rs`, `parse.rs`,
`parse/extra.rs`, `parse/error.rs`, `ast.rs`, `ast/untyped.rs`,
`ast/constant.rs`, `warning.rs`, `format/src/lib.rs`. The parity oracle is
`tools/gleam-ast-oracle` (Rust, on `gleam-core`); it runs only locally.

To move to a new Gleam version: bump the tag in
`tools/gleam-ast-oracle/Cargo.toml` and `tests/corpus/gleam_version.txt`;
diff the files above between the tags; apply the changes to `src/ast`,
`src/scanner`, `src/parser` and `docs/ast-json.md`; run
`mise run corpus:goldens`, `mise run test:parity`, `mise run parity:ratchet`.

### Architecture Summary

```
moonrockz/gleam-parser
├── moon.work             # Workspace: the library (.), tests (tests/) and the cookbook (docs/cookbook/)
├── src/                  # The library (the only published module)
│   ├── lib.mbt           # Package entry point; re-exports; version()
│   ├── span/             # SrcSpan (UTF-8 byte offsets), Position (1-based line and column)
│   ├── diagnostic/       # Severity, Label, Diagnostic, the code table
│   ├── scanner/          # SourceText; lexer (plan 2)
│   ├── lawkit/           # Property-test generators and helpers (public test support)
│   ├── ast/ cst/ parser/ dialect/ report/   # plans 3 and 4
│   └── syntax/ printer/  # v0.2, v0.3
├── tests/                # Unpublished module moonrockz/gleam_parser_tests
│   ├── bdd/              # MoonSpec step definitions for tests/features
│   ├── features/         # Gherkin features
│   └── parity/ rejection/ corpus/ fixtures/   # plan 5
├── tools/gleam-ast-oracle/   # Rust oracle (plan 3)
├── scripts/              # MoonBit tooling scripts (.mbtx)
├── docs/cookbook/        # Unpublished module moonrockz/gleam_parser_cookbook: tested articles
├── .dev/                 # Gitignored working area for specs, plans and scratch files
└── mise-tasks/           # File-based mise tasks
```

### Diagnostics

Every `Diagnostic` has a `code`, a `severity`, a one-line `message`, a `span`,
a `title` (the compiler's: "Syntax error"), `labels` (the primary label text
at the span, plus extra labels) and an optional `hint`, with the compiler's
wording from `parse/error.rs`.

| Code | Meaning |
|------|---------|
| `GL-SCAN-001` | Lexical error (the message names the LexicalErrorType) |
| `GL-PARSE-001` | Syntax error (the message names the ParseErrorType) |
| `GL-PARSE-002` | Deprecated syntax (warning) |
| `GL-PARSE-003` | Detached doc comment (warning) |
| `GL-PARSE-004` | Too much nesting |

`src/diagnostic/codes.mbt` holds these descriptions (`description(code)`,
re-exported as `diagnostic_description`). Keep this table and that file in
step when you add a code.

### Positions

`SrcSpan { start, end }` holds UTF-8 byte offsets, as the compiler does.
`SourceText` maps a byte offset to a UTF-16 offset (for editors) and to a
`Position { line, column }` (1-based; columns count code points). `\r\n` and
a lone `\r` are one line break each. A BOM and a lone surrogate are one code
point of three bytes each.

## Library Dependencies

Treat `moonbitlang/core`, `moonbitlang/x` and `moonbitlang/async` as the
MoonBit core library; look there before adding a helper or a dependency.
Library code (`src/**`) uses only `moonbitlang/core` and the module's own
packages (from v0.3 also `moonrockz/pretty`). The published `moon.mod`
imports only `moonrockz/expect` (used by the packages' own tests); it brings
`moonbitlang/async` and `moonbitlang/x` to users, which is accepted.

Test-only dependencies (`moonrockz/moonspec`, `moonbitlang/async`,
`moonbitlang/x`) live in the unpublished workspace module `tests/`
(`moonrockz/gleam_parser_tests`). Its tests run with `tests/` as the working
directory, so repository files are `../moon.mod`, `../.corpus`; data in the
module is `features/...`, `corpus/...`. `.moonignore` keeps everything but
`src/` and the READMEs out of the published package.

The module name has a hyphen, so every importer of the root package gives it
an alias in `moon.pkg`: `"moonrockz/gleam-parser" @gleam`. The root
package's own black-box tests import it the same way (`for "test"`).

### Toolchain

- Targets: wasm, wasm-gc, js and native (`mise run test:targets`, CI job
  `targets`). llvm is left out because the toolchain does not ship
  `moonbitlang/core` for it.
- The MoonBit toolchain version is pinned in `.github/workflows/*.yml`
  (`MOONBIT_VERSION`). Keep your local toolchain on the same version
  (`moon version --all`, `moon upgrade`).
- To upgrade: `moon upgrade`, bump `MOONBIT_VERSION`, bump the `import`
  versions in `moon.mod`, `tests/moon.mod`, `docs/cookbook/moon.mod` and the
  pinned imports in `scripts/*.mbtx`, then `moon update && moon check && mise
  run test`. Fix all new warnings, not only errors.
- Use `derive(Debug)` (not `derive(Show)`) for data types. `assert_eq`
  requires `Debug`. Implement `Show` by hand only for real text formats.

## Project Structure

- MoonBit packages are organized per directory; each has a `moon.pkg` listing dependencies.
- Blackbox tests: `*_test.mbt`; whitebox tests: `*_wbtest.mbt`. In blackbox tests,
  qualify names from the package under test (for example `@scanner.TokenKind`).
- Top-level `moon.mod` describes the module and metadata (the legacy `moon.mod.json`
  format is deprecated).

## Design Philosophy

This project follows **functional design principles** (aligned with moonrockz/gherkin and moonrockz/cucumber-expressions):

- **Algebraic data types (ADTs)** for domain concepts (enums + structs).
- **Make invalid states unrepresentable** — use the type system to prevent illegal states.
- **Avoid primitive obsession** — use domain types (e.g. `Token`, `Span`) instead of raw strings/ints.
- **Prefer immutability** — minimal `mut`; favor returning new values.
- **Pattern matching over conditionals** — exhaustive `match` on enums.
- **Total functions** — use `Option`/`Result` or typed `raise` for failures; avoid panic.

Visitor and AST design will aim for **flexibility** similar to moonrockz/gherkin (multiple traversal styles, composable visitors).

## Test-Driven Development (TDD)

- **Red–Green–Refactor**: Write a failing test first, then minimal implementation, then refactor.
- Use `#declaration_only` to sketch public APIs before implementation.
- Specify behavior as Gherkin features run by
  [moonrockz/moonspec](https://mooncakes.io/docs/moonrockz/moonspec)
  (`tests/features/` for the library, `scripts/features/` for scripts).
- Write assertions with [moonrockz/expect](https://mooncakes.io/docs/moonrockz/expect):
  `@expect.expect(actual).to_equal(expected)`, `.to_be_true()`, `.to_contain(...)`.
- Use soft assertions when a test or a step checks more than one fact: put the
  checks in one `@expect.expect_all(s => { ... })` block and write
  `s.expect(...)`, so a failure reports every failed check at once. Keep a
  precondition hard: a check that later code depends on uses
  `@expect.expect(...)` or `guard ... else { fail(...) }`. A single assertion
  needs no block, and a law returns a `Bool` instead. Use `inspect(...)` for
  snapshot tests.
- Gherkin `{string}` parameters keep backslash escapes literally; a step that
  needs a real line break unescapes `\\n` and `\\r` itself.
- Run `mise run test:unit` for tests; `moon test --update` to refresh snapshots.

### Property-Based Testing (Laws)

Property-based tests supplement the example tests and features; they state
**laws**: rules that hold for every input, checked against many generated
inputs.

- **When to write laws.** For every new type, feature or capability, ask which
  laws it must obey, and write them down in the plan next to the example
  tests: invariants (every child's span lies inside its parent's), round
  trips (decode after encode gives the value back), equivalences (two APIs
  give the same result), algebraic rules (identity, idempotence,
  associativity), and models (a small reference implementation agrees with
  the real one).
- **Tooling.** `moonbitlang/core/quickcheck` (import it and
  `moonbitlang/core/quickcheck/splitmix` for `"test"` only). Check a law with
  `@quickcheck.check(law, count=…, max_size=…, seed=…)`. Always set `seed`.
- **Generators.** Wrap the value in a newtype and implement
  `@quickcheck.Arbitrary` (and `@quickcheck.Shrink`). Shared generators are
  `pub` types in `src/lawkit`: `Units` (any UTF-16 text: surrogates, `\r`,
  CRLF, BOM) and `edge_chars()`; later plans add `GleamModule`,
  `GleamText`, `Nesting`, `Commented` and `Spaced`. Keep generated depth
  bounded by `size`, so generators do not overflow the stack on wasm.
- **Valid input fails loudly.** A generator of valid input makes the law fail
  on any diagnostic, never skip the case. Generate arbitrary text only for
  laws that must hold for any text (never crash; a diagnostic instead).
- **Name laws as laws.** Test names start with `law:` and state the rule.
- **Boundary values.** A law lists its edge values and its generator reaches
  them: none, one and many; equal, nested, adjacent and empty spans; the start
  and end of every span, one byte before each; line and file ends; non-ASCII
  text (surrogate pairs, lone surrogates); limits ± 1.
- **Reach the success branch.** A law that returns `true` on an error tests
  nothing for inputs that fail; measure how often the generator reaches the
  success branch.
- **Enumerate small edge products** in one example test with soft assertions
  instead of sampling.
- **Corpus as a law check.** A law that holds for generated input also holds
  for the pinned corpus; add it to the parity check where it is cheap.
- **Run on every target.** Laws run in `mise run test:unit` and `mise run
  test:targets`. Keep `count` and `max_size` small enough that a package's
  tests stay fast.

## Documentation

Two kinds of user documentation, both tested:

- **API reference**: `///` doc comments on public items, shown on
  mooncakes.io. The first line says what the item does; then the details a
  user needs (defaults, edge cases, errors). Entry points and items whose use
  is not obvious get an example in a fenced block with the info string
  `mbt check` that holds a `test { ... }`. `moon test` runs these examples as
  black-box tests of the package, so refer to the package by its alias
  (`@gleam.version`). Use `debug_inspect` for `derive(Debug)` values. A doc
  comment block can hold only `test` blocks: with a `struct` or `impl` in it,
  moon skips the block (warning 4191). For such an example, use a block with
  the info string `mbt nocheck`, check it once in a scratch test, and point
  to a tested example (a cookbook article, by its GitHub URL). When you
  add or change a public item, update its doc comment and example.
- **Cookbook** (`docs/cookbook/`): one article per user task
  (`<slug>.mbt.md`), indexed in `docs/cookbook/README.md`. The directory is
  the unpublished workspace module `moonrockz/gleam_parser_cookbook` with one
  package; `mise run test:docs` runs every `mbt check` block (CI job
  `unit-tests`). All articles share one namespace, so prefix each article's
  top-level names (`gs_`, …). Use an `mbt nocheck` block only
  for code that cannot run as a test, such as a `main` that writes a file.
- `README.mbt.md` is the mooncakes.io landing page. It is not in a package,
  so its examples are not run: keep them short and copy them from tested
  code.
- Write documentation in ASD-STE100 Simplified Technical English: short
  sentences, active voice, one word for one meaning.

## Coding Convention

- MoonBit block style: blocks separated by `///|`; block order irrelevant.
- Deprecated code in `deprecated.mbt` per directory.

## Conventional Commits

All commits MUST use **[Conventional Commits](https://www.conventionalcommits.org)**:

```
type(scope): description
```

Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `style`.
Breaking changes: add `!` after type (e.g. `feat(parser)!: change return type`).
Also add a `BREAKING CHANGE: <what breaks and how to migrate>` footer (Conventional
Commits 1.0.0; `BREAKING-CHANGE:` works too). git-cliff writes the footer text as the
changelog's breaking-change line; without it the line repeats the subject. For a
squash merge, put the footer in the squash commit body
(`gh pr merge --squash --body $'…\n\nBREAKING CHANGE: …'`).
`mise run release:prepare` warns about breaking commits without the footer.

Scopes (examples): `scanner`, `parser`, `ast`, `cst`, `span`, `diagnostic`, `ci`, `build`.

## Mise Tasks

All operations use **file-based mise tasks** in `mise-tasks/`. Do not add inline `[tasks]` to `.mise.toml`.

| Task | Purpose |
|------|---------|
| `hooks:install` | Install project git hooks via lefthook |
| `info:generate` | Run `moon info` to generate interfaces |
| `lint:check` | `moon check` |
| `format:check` | `moon fmt --check` (also `scripts/*.mbtx`) |
| `check` | info + lint + format + tests |
| `test:unit` | MoonBit unit tests of the library packages |
| `test:bdd` | MoonSpec features (`tests/bdd`) |
| `test:scripts` | Script tests (`scripts/*.mbtx`) |
| `test:docs` | Cookbook articles |
| `test:targets` | Check and test the library on wasm, wasm-gc, js and native |
| `test` | unit + bdd + scripts + docs |
| `coverage:ci-gate`, `coverage:ci-warn` | Coverage threshold (80) |
| `release:prepare`, `release:version`, `release:plan`, `release:notes`, `release:refresh`, `release:status`, `release:credentials`, `release:publish` | Release process (see Release Process) |

## Scripts

Project tooling logic is written in MoonBit, not bash, `jq` or `awk`.

- Put tooling logic in standalone scripts: `scripts/<name>.mbtx`.
- Keep each mise task a one-line launcher:
  `exec moon run -q --target wasm scripts/<name>.mbtx -- <args>`.
  `-q` hides dependency manifest warnings; errors and output still show.
  Do not use `moonx`; the CI toolchain does not include it.
- In a script, put logic in pure functions. `async fn main` does only I/O.
- Specify each script's behavior in `scripts/features/<name>.feature`. The script
  runs its feature with moonspec from an `async test`; `moon test` runs with
  `scripts/` as the working directory, so load `features/<name>.feature`.
- Pin module imports in each script (`moonbitlang/async@<version>`,
  `moonbitlang/x@<version>/sys`, `moonrockz/moonspec@<version>`,
  `moonrockz/expect@<version>`) to the versions used by the module.
- Test the scripts with `mise run test:scripts`. `moon test` and `moon fmt`
  handle a `.mbtx` file only when you give its path.
- Do not add new logic to bash task files. A task that calls one `moon`
  command can stay bash.

| Script | Task | Purpose |
|--------|------|---------|
| `scripts/coverage.mbtx` | `coverage:ci-gate`, `coverage:ci-warn` | Coverage summary and threshold |
| `scripts/credentials.mbtx` | `release:credentials` | Write mooncakes.io credentials (CI only) |
| `scripts/release.mbtx` | `release:prepare`, `release:version`, `release:plan`, `release:notes`, `release:refresh`, `release:status` | Release pull request, next version, release decision in CI, release notes, pull request body, release health check |
| `scripts/publish.mbtx` | `release:publish` | Publish to mooncakes.io; a release tag must match `moon.mod`'s version; an already published version (a second run for the tag) succeeds |
| `scripts/hooks_install.mbtx` | `hooks:install` | Install lefthook hooks |

## Tooling

- `moon fmt` — format code.
- `moon info` — update generated `.mbti` interface.
- `moon check` — typecheck.
- Run `moon info && moon fmt` before committing when API or formatting may have changed.

## The `.dev/` Working Area

`.dev/` is a gitignored scratch area for AI-assisted development: temporary scripts, agent and
script outputs, and working documents. Nothing in it is committed. Layout:

- Specs from the superpowers `brainstorming` skill: `.dev/docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- Plans from the superpowers `writing-plans` skill: `.dev/docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md`
- Scratch scripts and their outputs: `.dev/scripts/`, `.dev/out/`

This layout overrides the default location of any skill or tool. Never place specs, plans or
other working documents under `docs/`, and never `git add` anything under `.dev/`. When a
design is final and meant for readers, write it up in a committed location on purpose.

## Release Process

- Publishes to **mooncakes.io** and **GitHub Releases**, and records every release in
  `CHANGELOG.md`.
- The release-manager skill (`.claude/skills/release-manager/`) walks an agent through
  a release, troubleshooting (`TROUBLESHOOTING.md`) and improving the process after
  each release. Agents other than Claude Code can read its `SKILL.md` directly.
- `mise run release:status` checks that main, the tags, the GitHub release and
  mooncakes.io agree; each problem it prints names the command that fixes it.
- To release, run `mise run release:prepare` on a clean working tree. It fetches
  `origin/main`, computes the next version with git-cliff (pinned in `.mise.toml`,
  configured in `cliff.toml`; on 0.x a `feat` or a breaking change bumps the minor,
  anything else the patch), sets `version` in `moon.mod`, prepends the version's
  section to `CHANGELOG.md`, commits `chore(release): v<version>` on branch
  `release/v<version>`, pushes it and opens the pull request. It also sets the
  string that `version()` in `src/lib.mbt` returns; `tests/bdd/version_wbtest.mbt`
  checks that it equals `moon.mod`'s version. Give a version to
  override git-cliff (`mise run release:prepare 1.0.0`); `--local` stops before the
  push.
- `prepare` warns about breaking commits (`!`) without a `BREAKING CHANGE:` footer
  and lists them in the pull request body. Rewrite each such line under "Breaking
  changes" in `CHANGELOG.md`.
- In the pull request, replace the highlights comment at the top of the new section
  with a few sentences on what the release brings, and reword the generated lines
  where needed. Push, then run `mise run release:refresh` on the release branch: it
  writes the new notes into the pull request body. Then merge. Do not bump the
  version in any other pull request.
- Merge the release pull request before other pull requests. A pull request that
  merges first is not in the new section and goes into no later section either (the
  tag covers it). If that happens, close the release pull request, delete its branch
  and run `mise run release:prepare` again.
- The merge changes `moon.mod` on `main`, so the Release workflow runs:
  - `plan` (`mise run release:plan`) releases when `v<version>` has no tag yet and
    `CHANGELOG.md` has the version's section with its highlights written; otherwise
    it skips, or fails when the section is missing or still has the highlights
    placeholder.
  - `validate` runs `moon fmt`, `moon check`, `mise run test:unit` and
    `mise run test:scripts`; `publish` publishes to mooncakes.io (needs the
    `MOONCAKES_USER_TOKEN` org secret).
  - `release` creates the tag on the merge commit and the GitHub release. Its notes
    (`mise run release:notes <version>`) are an install line followed by the
    changelog section: highlights, breaking changes, grouped changes with PR links
    and authors, and the compare link.
- A pushed `v*` tag (it must match `moon.mod`'s version) and a manual run also work.
- A release run is safe to repeat: release runs never overlap (a concurrency group),
  an already published version and an existing GitHub release are skipped. The tag is
  created with `GITHUB_TOKEN`, which starts no second run.
- Write commit and pull request titles for the changelog: the squash-merge title is
  the changelog line. `chore(release)` and `chore(beads)` commits are left out.

## Work Tracking

**bd (beads) is the primary tracker for all work.** GitHub Issues are the
public intake for reports from outside contributors.

- Track every task, bug, feature and epic in bd. Do NOT use markdown TODO
  lists or other tracking methods.
- Mirror each GitHub issue into bd with `--external-ref gh-<number>`, and keep
  the two in step: when the bd issue closes, close the GitHub issue.
- A pull request that resolves a GitHub issue says `Closes #<number>` in its
  body. Name the bd issue in the body too.
- Work lands on `main` through pull requests (squash merge). Branch first;
  do not push to `main` unless the user says so for that change.
- bd runs with `agent.profile: team-maintainer` (`.beads/config.yaml`):
  commit, `bd sync` and push are routine parts of the work. An explicit
  "do not commit" or "do not push" from the user still wins, and pushes go to
  your branch, not to `main`.

## Persistent Memory

Store knowledge that must outlive the session with `bd remember`. Do not use
`MEMORY.md` files or any agent's own memory store for this project; bd
memories sync through `refs/dolt/data`, so every machine and agent sees them.

```bash
bd remember "insight" --key <slug>   # store, or update the memory with that key
bd memories <keyword>                # search
bd recall <key>                      # read one
```

`bd prime` (the SessionStart hook) injects the memories into each session.

<!-- BEGIN BEADS INTEGRATION -->

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT
use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: syncs through a Dolt remote on the Git origin
  (`refs/dolt/data`), separate from source branches
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:gleam-parser-123 --json
bd create "Issue title" --description="..." --external-ref gh-12 --json   # mirror a GitHub issue
```

**Claim and update:**

```bash
bd update gleam-parser-42 --status in_progress --json
bd update gleam-parser-42 --priority 1 --json
```

**Complete work:**

```bash
bd close gleam-parser-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Storage and Sync

- bd stores issues in an embedded Dolt database at `.beads/embeddeddolt/`
  (not committed).
- Git worktrees share the database of the main checkout. Do not create a
  database inside a worktree.
- Cross-machine sync uses a Dolt remote on the GitHub origin. Dolt keeps issue
  history under `refs/dolt/data`, separate from source branches:
  - `bd sync` — pull, check for conflicts, and push in one step.
  - `bd dolt pull` / `bd dolt push` — the individual steps.
- Issue changes need no commit or pull request: `bd sync` publishes them to
  `refs/dolt/data`.
- `.beads/issues.jsonl` is a passive export (`bd export -o .beads/issues.jsonl`)
  for viewers and interchange. It is gitignored; do not commit it.

### Setup on a Fresh Clone

```bash
bd bootstrap            # clones refs/dolt/data from origin and wires the Dolt remote
mise run hooks:install  # installs lefthook git hooks (these call `bd hooks run <hook>`)
git config beads.role maintainer   # or contributor
```

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT duplicate tracking systems (GitHub issues are mirrored, not tracked twice)

<!-- END BEADS INTEGRATION -->

## Landing the Plane (Session Completion)

When you end a work session, complete ALL steps below. Work is NOT complete
until the pushes succeed.

1. **File issues for remaining work** in bd.
2. **Run quality gates** if code changed: `mise run check`,
   `moon info && moon fmt`.
3. **Update issue status**: close finished work, update in-progress items.
4. **Push** (mandatory):
   ```bash
   bd sync                  # publish issue changes to refs/dolt/data
   git pull --rebase
   git push                 # your branch; open or update its pull request
   git status               # MUST show "up to date with origin"
   ```
5. **Clean up**: clear stashes, prune merged branches.
6. **Hand off**: give context for the next session.

Never stop before pushing; that leaves work stranded on one machine. If a push
fails, resolve the cause and retry.
