(** The Captcha Race engine: the gameplay logic, with no dependency on any
    display.

    Built on the shared {!Captcha_race} types, this library owns everything a
    race needs except drawing:

    - {!Game_runner} runs one race — a randomized sequence of mini-games,
      timed from the first game's start to the last game's end.
    - {!Mini_game_intf.S} is the contract a mini-game implements;
      {!Mini_game} packs implementations so the runner can drive a
      heterogeneous mix of them. Concrete games live in the separate
      [captcha_race.mini_games] library.
    - {!Leaderboard} keeps completion times fastest-first and persists them
      to disk as a sexp file.
    - {!Layout} is the shared play-area geometry handed to every game's
      [create].

    Nothing here touches [Graphics], so the whole library is exercised by
    headless expect tests. The rendering and window/event loop live in the
    [captcha_race.app] library and [bin/main.ml]. *)

module Game_runner = Game_runner
module Layout = Layout
module Leaderboard = Leaderboard
module Mini_game = Mini_game
module Mini_game_intf = Mini_game_intf
