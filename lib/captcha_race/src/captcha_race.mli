(** Captcha Race: solve a randomized gauntlet of captcha mini-games as fast
    as you can.

    How the pieces fit together:

    - {!App_state} is the three-screen view state machine (menu / leaderboard
      / playing) and holds the {!Leaderboard}.
    - {!Game_runner} runs one race: a randomized sequence of mini-games,
      timed from the first game's start to the last game's end.
    - {!Mini_game_intf.S} is the contract a mini-game implements;
      {!Mini_game} packs implementations so the runner can drive a
      heterogeneous mix of them. {!Placeholder_game} is the reference
      implementation.
    - {!Leaderboard} keeps completion times fastest-first and persists them
      to disk as a sexp file.
    - {!Geometry}, {!Input} and {!Button} are the pure building blocks for
      layout, per-frame input snapshots and click hit-testing.
    - {!Render} is the only module that draws; the window and event loop live
      in [bin/main.ml].

    Everything except {!Render} (and each game's [draw]) is display-free, so
    all game logic is exercised by headless expect tests. *)

module App_state = App_state
module Button = Button
module Game_runner = Game_runner
module Geometry = Geometry
module Input = Input
module Leaderboard = Leaderboard
module Mini_game = Mini_game
module Mini_game_intf = Mini_game_intf
module Placeholder_game = Placeholder_game
module Render = Render
