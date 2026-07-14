(** A clickable labeled region carrying the ['a] action it stands for.

    [Button] is pure: it knows its label, where it sits, and what it means —
    drawing happens in {!Render} and click dispatch in the event loop.
    {!App_state.buttons} lists the buttons for each view, so rendering and
    hit-testing always agree on where buttons are.

    {[
      match Button.hit_many (App_state.buttons view) input.mouse with
      | Some action -> ...apply the action...
      | None -> ...the click was not on a button...
    ]} *)

open! Core
open Captcha_race

type 'a t =
  { label : string
  ; rect : Geometry.Rect.t
  ; action : 'a
  }
[@@deriving sexp_of]

(** [hit t p] is [Some t.action] when [p] lies inside [t.rect]. *)
val hit : 'a t -> Geometry.Point.t -> 'a option

(** [hit_many ts p] is the action of the first button in [ts] containing [p],
    if any. *)
val hit_many : 'a t list -> Geometry.Point.t -> 'a option
