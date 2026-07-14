(** The concrete captcha mini-games.

    Each module here implements {!Captcha_race_engine.Mini_game_intf.S} and
    is registered into the race pool in [bin/main.ml] with
    {!Captcha_race_engine.Mini_game.pack}. To add a captcha, add a module to
    this library, re-export it below, and add it to that pool.

    {!Placeholder_game} is the trivial reference implementation (click the
    box) and the model to copy for real games. {!Math_game} is the two-phase
    arithmetic captcha. *)

module Math_game = Math_game
module Placeholder_game = Placeholder_game
