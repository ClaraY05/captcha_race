# Captcha Race

A single-player OCaml game: solve a gauntlet of 10 randomly chosen
captcha mini-games as fast as you can. Your time — from the start of
the first captcha to the end of the last — lands on a leaderboard,
fastest first, persisted between runs.

Built in the Jane Street style:
[`Core`](https://opam.ocaml.org/packages/core/) as the standard
library, `ppx_jane` for deriving, `dune` for builds, expect tests, the
`janestreet` ocamlformat profile, and the OCaml
[`graphics`](https://opam.ocaml.org/packages/graphics/) library for the
window.

## How to play

```sh
dune exec bin/main.exe   # needs a graphical display
```

- **Menu** — click **Play** to start a race or **Leaderboard** to see
  your best times.
- **Playing** — solve each captcha to advance to the next; a **Quit**
  button in the top-right abandons the race (nothing is recorded).
- After the 10th captcha your total time is saved to
  `~/.captcha_race_scores.sexp` and you're back at the menu.

On a headless machine the window can't open (`graphics` needs an X
server); `xvfb-run -a dune exec bin/main.exe` works for smoke tests.

## Adding a mini-game

Mini-games are pluggable. Implement
`Captcha_race.Mini_game_intf.S` (copy
`lib/captcha_race/src/placeholder_game.ml` as a starting point),
re-export the module from `captcha_race.ml`/`.mli`, and register it in
the pool in `bin/main.ml`:

```ocaml
let pool =
  [ Mini_game.pack (module Placeholder_game)
  ; Mini_game.pack (module My_game)
  ]
```

Each race samples 10 games from the pool. One rule matters: **no
`Graphics` calls outside `draw`** — everything else must stay
display-free so the logic is testable headlessly. See `CLAUDE.md` for
the full architecture and conventions.

## Build, test, format

```sh
dune build                      # compile
dune runtest                    # run tests (headless-safe; CI runs this)
dune fmt --auto-promote         # format (.ocamlformat: janestreet profile)
```

All game logic (sequencing, timing, leaderboard, hit-testing) is pure
and covered by expect tests in `lib/captcha_race/test/`; only
`Render` and `bin/main.ml` touch the display, and no test ever opens
one.

## GitHub Actions

- **`.github/workflows/ci.yml`** — builds, tests, and checks formatting
  on every push to `main` and every PR. Self-contained via
  `ocaml/setup-ocaml`; needs no secrets.
- **`.github/workflows/claude.yml`** — runs the
  [Claude Code Action](https://github.com/anthropics/claude-code-action)
  when someone writes `@claude` in an issue or PR. Needs an
  `ANTHROPIC_API_KEY` secret (or a `CLAUDE_CODE_OAUTH_TOKEN` from
  `/install-github-app`).

## Layout

```
lib/captcha_race/src/    the game library (state machine, runner,
                         mini-game interface, leaderboard, render)
lib/captcha_race/test/   headless expect tests
bin/main.ml              the executable: window + event loop
```

See `CLAUDE.md` for the architecture, the mini-game contract, and the
full code conventions.
