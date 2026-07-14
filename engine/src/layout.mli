(** Shared screen geometry: the window, the CRT screen surface, and the
    region mini-games draw in.

    The game is presented on a pixel-art CRT monitor. [screen] is the dark
    drawable surface inside the bezel — the region all three views render
    into — and [play_bounds] is the captcha card's interior at the centre of
    it, handed to every mini-game's [create]. Both live in the engine rather
    than the app so game logic, headless tests, and the button layout in
    {!Captcha_race_app.App_state} can reference them without depending on the
    rendering layer; {!Captcha_race_app.Render} frames them with the CRT
    chrome.

    {[
      Placeholder_game.create ~random ~bounds:Layout.play_bounds
    ]} *)

open! Core
open Captcha_race

(** Window dimensions, in pixels. *)
val window_width : int

val window_height : int

(** The dark CRT screen surface inside the bezel; every view renders within
    it and buttons sit inside it. *)
val screen : Geometry.Rect.t

(** The captcha card's interior: a centred region inside {!screen} where the
    active mini-game draws. Passed as [bounds] to every game's [create];
    {!Captcha_race_app.Render} draws the card chrome around it. *)
val play_bounds : Geometry.Rect.t
