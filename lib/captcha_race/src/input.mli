(** A per-frame snapshot of the player's input.

    The event loop in [bin/main.ml] polls [Graphics] once per frame and packs
    what it saw into a [t], which then flows unchanged into
    {!App_state.advance} and the active mini-game's [update]. Keeping input a
    plain value (rather than letting game logic query [Graphics] directly)
    keeps every consumer display-free: tests simply construct whatever input
    they need.

    {[
      let click_at point =
        { Input.idle with
          mouse = point
        ; mouse_down = true
        ; mouse_clicked = true
        }
      ;;
    ]} *)

open! Core

type t =
  { mouse : Geometry.Point.t (** current pointer position *)
  ; mouse_down : bool (** the mouse button is currently held *)
  ; mouse_clicked : bool
  (** the mouse button went down this frame (an edge, unlike the level
      [mouse_down]) — use this for "the player clicked" *)
  ; key : char option (** key pressed this frame, if any *)
  }
[@@deriving sexp_of]

(** A frame with no activity and the mouse at the origin. The natural base
    for tests and for frames where only time passes. *)
val idle : t
