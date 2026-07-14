(** Shared type definitions for Captcha Race, with no dependencies of their
    own.

    This is the foundational library every other layer builds on:

    - {!Geometry} — pixel coordinates ([Point]) and rectangles ([Rect]) with
      hit-testing.
    - {!Input} — a per-frame snapshot of the player's pointer and keyboard.

    Nothing here touches [Graphics] or performs I/O, so it links and tests
    without an X server. The gameplay logic lives in [captcha_race.engine],
    the UI in [captcha_race.app], and the concrete captchas in
    [captcha_race.mini_games]. *)

module Geometry = Geometry
module Input = Input
