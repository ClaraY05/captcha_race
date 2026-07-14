(** Shared screen geometry: the window size and the region mini-games draw
    in.

    [play_bounds] is the contract between [Render] — which lays out the
    window and the HUD strip — and every mini-game, whose [create] is handed
    these bounds. It lives in the engine rather than the app so that game
    logic and headless tests can reference it without depending on the
    rendering layer.

    {[
      Placeholder_game.create ~random ~bounds:Layout.play_bounds
    ]} *)

open! Core
open Captcha_race

(** Window dimensions, in pixels. *)
val window_width : int

val window_height : int

(** The region a mini-game may draw in: the window minus the HUD strip along
    the top. Passed as [bounds] to every game's [create]. *)
val play_bounds : Geometry.Rect.t
