open! Core

type t =
  { center : Geometry.Point.t
  ; started_at : Time_ns.t
  }
[@@deriving sexp_of]

let duration = Time_ns.Span.of_int_ms 220
let start_radius = 4
let end_radius = 22
let create ~center ~now = { center; started_at = now }
let center t = t.center

(* Linear from [start_radius] to [end_radius] over [duration]; [None] once
   the ripple has run its course, which is how {!Render} knows to skip it. *)
let radius t ~now =
  let age = Time_ns.diff now t.started_at in
  match
    Time_ns.Span.( < ) age Time_ns.Span.zero
    || Time_ns.Span.( >= ) age duration
  with
  | true -> None
  | false ->
    let progress = Time_ns.Span.to_sec age /. Time_ns.Span.to_sec duration in
    Some
      (start_radius
       + Float.iround_nearest_exn
           (progress *. Float.of_int (end_radius - start_radius)))
;;
