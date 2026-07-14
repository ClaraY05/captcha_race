(** The concrete captcha mini-games.

    Each module here implements {!Captcha_race_engine.Mini_game_intf.S} and
    is registered into the race pool in [bin/main.ml] with
    {!Captcha_race_engine.Mini_game.pack}. To add a captcha, add a module to
    this library, re-export it below, and add it to that pool.

    {!Placeholder_game} is the trivial reference implementation (click the
    box) and the model to copy for real games. {!Math_game} is the two-phase
    arithmetic captcha. {!Moving_puzzle} is a slider-puzzle captcha: drag a
    shape into a matching slot. {!Typing_game} is the distorted word that
    resolves as the clock runs. *)

module Math_game = Math_game
module Moving_puzzle = Moving_puzzle
module Placeholder_game = Placeholder_game
module Typing_game = Typing_game
