(** The expanding ring drawn wherever the player last clicked.

    Purely cosmetic, and deliberately global: every click in every view
    leaves one, so "the game saw that click" never depends on the mini-game
    under the cursor having something to say about it. A race is won by
    clicking fast, and a click that vanishes without a trace is
    indistinguishable from a miscount.

    {!App_state.Model} holds the most recent ripple and {!Render} draws it on
    top of everything else, growing it from a dot to {!end_radius} over
    {!duration} and then dropping it.

    {[
      let ripple = Click_ripple.create ~center:input.mouse ~now in
      match Click_ripple.radius ripple ~now with
      | None -> () (* already faded *)
      | Some radius -> draw_circle ~radius
    ]} *)

open! Core

type t [@@deriving sexp_of]

(** How long a ripple lives before {!radius} reports it gone. *)
val duration : Time_ns.Span.t

(** Widest the ring gets, at the very end of {!duration}. *)
val end_radius : int

(** [create ~center ~now] starts a ripple at the click position. *)
val create : center:Geometry.Point.t -> now:Time_ns.t -> t

val center : t -> Geometry.Point.t

(** [radius t ~now] is how wide the ring has grown, or [None] once the ripple
    has outlived {!duration} and should no longer be drawn. *)
val radius : t -> now:Time_ns.t -> int option
