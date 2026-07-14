(** The Captcha Race application layer: the view state machine and all
    rendering.

    - {!App_state} is the three-screen state machine (menu / leaderboard /
      playing) plus the pure transitions the event loop drives, and it holds
      the {!Captcha_race_engine.Leaderboard}.
    - {!Button} is a clickable labeled region; {!App_state.buttons} lists the
      buttons per view so rendering and hit-testing agree.
    - {!Render} turns a model into pixels — the only module here that issues
      [Graphics] calls.

    Built on top of {!Captcha_race_engine}; the concrete mini-games it runs
    are supplied as a pool from [bin/main.ml], so this library stays
    independent of any particular game. The window and event loop live in
    [bin/main.ml]. *)

module App_state = App_state
module Button = Button
module Render = Render
