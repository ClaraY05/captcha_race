# CLAUDE.md — captcha_race

## About this project

**Captcha Race** is a single-player game built on the OCaml `graphics`
library, in the Jane Street style: `Core` as the standard library,
`ppx_jane` for deriving, `dune` for builds, and expect tests.

The player races through a sequence of 10 randomly chosen captcha
mini-games, solving each to advance to the next. The time from the start
of the first game to the end of the last is recorded on a leaderboard
(persisted to disk as a sexp file), shown fastest-first. The app has
three views: **menu** (Play / Leaderboard), **leaderboard**, and
**playing** (with a Quit button available at all times).

## Architecture

The code is split into four libraries by concern, plus the executable —
each in its own top-level directory (dune discovers them anywhere, they
need not sit under `lib/`). Each is a dune-wrapped library:
`open Captcha_race` (etc.) brings its modules into scope. Only `lib/`
holds general type definitions; everything else is a higher-level layer.

**`lib/`** — `captcha_race`, module `Captcha_race`. The shared type
definitions, with **no dependencies** (core only, no `Graphics`, no
I/O). This is the foundation every other layer builds on.

- `Geometry` — pixel coordinates (`Point`) and rectangles (`Rect`) with
  hit-testing.
- `Input` — a per-frame snapshot of the player's pointer and keyboard.

**`engine/`** — `captcha_race.engine`, module `Captcha_race_engine`.
The gameplay logic; depends on `captcha_race`, **no `Graphics`**, so it
is fully covered by headless tests.

- `Game_runner` — one race: samples 10 games from a pool with an
  injected `Random.State.t`, runs them sequentially, and reports
  `` `Finished total `` when the last one solves.
- `Mini_game_intf.S` — the contract a mini-game implements (see below).
- `Mini_game` — existentially packs any `S` into a uniform `t`
  (`pack`, `name`, `update`, `draw`, `is_solved`); a race pool is a
  `Mini_game.factory list`.
- `Leaderboard` — completion times, fastest-first, sexp `load`/`save`.
- `Layout` — window size and `play_bounds` (the drawable region handed
  to every game's `create`). Lives here, not in the app, so game logic
  and tests can reference `play_bounds` without depending on rendering.
- `Pixel_font` — the chunky 5x7 display face (a Press Start 2P
  stand-in) as pure geometry: it says *where* a string's lit pixels
  fall and leaves the drawing to its caller, so it needs no `Graphics`.
  Lives here, not in the app, because both the app's chrome and the
  mini-games' own text are set in it, and `engine` is the only layer
  both can see.

**`app/`** — `captcha_race.app`, module `Captcha_race_app`. The
application/UI layer; depends on `captcha_race` + `engine` + `graphics`.

- `App_state` — the three-view state machine
  (`Menu | Leaderboard | Playing of Game_runner.t`), plus `Model`
  (view + leaderboard), pure transitions, and the per-view button
  layout (`games_per_run` lives here; window/`play_bounds` in
  `Layout`).
- `Button` — a clickable labeled region + hit-testing.
- `Render` — the ONLY library module that issues `Graphics` drawing
  calls (mini-games draw themselves, but only from here).
- `Click_ripple` — the expanding ring every click leaves, wherever it
  lands; held by `Model` and drawn last by `Render`.

**`mini_games/`** — `captcha_race.mini_games`, module
`Captcha_race_mini_games`. The concrete captchas; depends on
`captcha_race` + `engine` + `graphics`.

- `Placeholder_game` — the trivial reference mini-game (click the box);
  the model to copy for real games.
- `Math_game` — solve an arithmetic problem, then click the reCAPTCHA
  checkbox that many times (the problem is gone by then).
- `Typing_game` — read a word that starts as an illegible smear and
  resolves over 20 seconds, and type it into the field.

**`bin/main.ml`** — owns the window and the non-blocking event loop;
assembles the mini-game pool, polls input, runs pure transitions, draws,
and saves the leaderboard when it changes. Depends on all four libraries
(it's where they meet). Input is polled every ~1ms and each poll steps
the model, while drawing happens at ~60 fps: `Graphics` reports only
whether the button is down *right now* (clicks are never queued), so
sampling once per frame would silently drop any press and release that
fell inside the same frame — fatal for a game that counts clicks.

Dependency direction: everything builds on `captcha_race`; then
`mini_games → engine ← app`, and `bin → all`. The app never depends on
concrete mini-games — the pool is injected in `bin/main.ml`.

Data flow: event loop → `Input.t` → `App_state.advance` /
`apply_action` → `Game_runner.advance` → active mini-game's `update` →
on finish, `Leaderboard.add` + save.

## Adding a mini-game

1. Create `mini_games/src/<my_game>.ml/.mli` implementing
   `Captcha_race_engine.Mini_game_intf.S` (`Placeholder_game` is the
   model to copy): `open Captcha_race` and `open Captcha_race_engine`,
   then an abstract `type t [@@deriving sexp_of]`, `name`, `create`,
   `update`, `draw`, `is_solved`.
2. Re-export it from `captcha_race_mini_games.ml`/`.mli`.
3. Register it in the pool in `bin/main.ml`:
   `Mini_game.pack (module My_game)`.
4. Add `mini_games/test/test_<my_game>.ml` driving it with synthetic
   `Input.t` values.

Invariants for every mini-game:

- **No `Graphics` calls outside `draw`.** `create`/`update`/`is_solved`
  must be display-free so tests and CI (headless) can run them.
- All randomness comes from the injected `Random.State.t`; all timing
  from the injected `~now`/`~elapsed`. Never call `Time_ns.now ()` or
  use global random state inside a game.
- Stay inside the `~bounds` rect passed to `create`
  (`Layout.play_bounds`).

## Headless rule (CI has no X server)

`Graphics.open_graph` needs an X display and raises `Graphic_failure`
without one. CI runs `dune runtest` on a headless runner, therefore:

- Tests must never open a display or call any drawing function
  (including a game's `draw`).
- Only `Render`, each mini-game's `draw`, and `bin/main.ml` may touch
  `Graphics`. That is exactly why `captcha_race` and `engine` have no
  `graphics` dependency — they link and test without an X server.
- To play locally you need a display; on a headless box use
  `xvfb-run -a dune exec bin/main.exe` just to smoke-test startup.

## Build, test, format

This project uses the external opam OCaml toolchain. Standard `dune`:

```sh
dune build                 # compile
dune runtest               # run all tests (headless-safe)
dune fmt --auto-promote    # format (uses .ocamlformat: janestreet profile, margin 77)
dune build @doc            # generate odoc HTML
dune exec bin/main.exe     # run the game (needs a graphical display)
```

Never modify anything under `_build/` — it's regenerated by dune.

## Code conventions

Match the existing style; don't introduce alternatives without a reason.

### Documentation

- Every lib needs docs
- Every module needs a comment
- All mli needs `(** doc *)`
- No useless comments (e.g., "adds numbers")
- Show examples
- Say how it fits with other modules
- Doc comments immediately after: `field : type (** doc *)`
- Use `[code]` and `{[blocks]}` in docs
- Use `{!Module.foo}` for links in docs
- `(*_ *)`: ignored by doc tools

### Naming

- Short scope = short name
- Bools: `is_foo` not `check_foo`
- Can raise? End with `_exn`
- Grabs/frees stuff? Start with `with_`
- American English only
- `snake_case` not `camelCase`
- `_`: unused only
- `unsafe`: can segfault. Name it `unchecked` otherwise
- No negative bools (e.g., `dont_foo`)
- Name constants
- Type params: `'a 'b` unless special (`'ok 'err`, `'k 'v` for maps)

### Printing

- `[%string "x is %{x}"]` not `sprintf`
- Always use `sprintf !` for `ppx_custom_printf`
- Always derive `sexp_of`
- `[%message]` > `[%sexp]` for humans

### Testing

- Make readable; use expect tests; tests in a separate dir
- Test-only stuff in `For_testing`
- Test files are named `test_<module>.ml` and live in `lib/<x>/test/`.
- Tests are `let%expect_test "<name>" = ...` with `[%expect {| ... |}]`
  blocks. `let%test` is fine for property-style boolean checks;
  `let%test_unit` for tests without expected output.
- When updating expect output, run `dune runtest --auto-promote` — but
  **read the diff first**. A surprising diff is a real signal.

### Interfaces

- Most modules have `type t`
- Most types are called `t`
- Args: `?optional`, `t`, positional, `~labeled`; label unclear args
- No new infix ops
- No `helpers.ml`
- Avoid functors (use first-class modules)

### Managing namespaces

- Only open if made for opening (`Let_syntax`, `O`, `Composition_infix`)
- `_intf.ml` for shared types
- Make a top-level lib module (see `lib/captcha_race/src/captcha_race.ml`)
- Small lib = one module
- Don't alias modules (if must: keep name same)

### Style preferences

- Short match first
- Match > if
- No `else ()`
- No `let...and...` (except monads)
- Type annotations > module paths
- Normal variants > poly variants
- `f();` not `let () = f()`
- Pass `[%here]` when function takes `Source_code_position.t`
- `^/` for paths
- `Time_ns` > `Time_float`

### Avoiding error-prone idioms

- No `| _ ->` when matching on variants
- Write types on ignored stuff (except record fields, labeled args, variant args)
- Use returned values
- No polymorphic compare

### Error handling

- Explicit error types; no `exception` in interfaces
- Raise: `_exn` only; make `ok_exn` visible
- Check human input (`sexp`/`json`); machine formats (`bin_io`) need no validation
- Add context
- For library-internal precondition violations: `raise_s [%message "..." (x : T.t)]`.
- For fallible operations exposed at module boundaries: return `'a Or_error.t`,
  build errors with `Or_error.error_s [%message ...]`.
- Prefer `Or_error.t` over `Result.t` directly.

### Opens

```ocaml
open! Core              (* always, for every src/test/bin .ml *)
```

The `!` suppresses unused-open warnings. Don't replace `Core` with
`Stdlib`; don't import individual functions from `Core`.

### Dune files

Libraries follow a uniform pattern:

```
(library
 (name <x>)
 (public_name <x>)
 (libraries <deps>)
 (preprocess (pps ppx_jane)))
```

Tests:

```
(library
 (name <x>_test)
 (libraries <x> expect_test_helpers_core core)
 (inline_tests)
 (preprocess (pps ppx_jane)))
```

dune discovers libraries automatically as long as they have a `dune` file.

## Project layout

Only general type definitions live in `lib/`; each higher-level concern
is its own top-level directory (dune finds `dune` files anywhere).

```
lib/            shared type definitions: Geometry, Input (no Graphics)
  src/ test/
engine/         gameplay logic: runner, mini-game interface,
  src/ test/    leaderboard, layout (depends on captcha_race)
app/            view state machine + rendering
  src/ test/    (depends on captcha_race + engine)
mini_games/     concrete captchas
  src/ test/    (depends on captcha_race + engine)
bin/
  main.ml       the game executable: window + event loop
```

See Architecture above for what each library contains.
