(** Pure 2-D geometry for laying out views and hit-testing clicks.

    Coordinates follow the OCaml [Graphics] convention: the origin is the
    bottom-left corner of the window, [x] grows rightward and [y] grows
    upward. Nothing here touches the display, so layout and hit-testing stay
    unit-testable without an X server. [Button] builds on this for clickable
    regions.

    {[
      let r = { Geometry.Rect.x = 0; y = 0; w = 10; h = 10 } in
      Geometry.Rect.contains r { Geometry.Point.x = 5; y = 5 } = true
    ]} *)

open! Core

module Point : sig
  (** A pixel position. *)
  type t =
    { x : int
    ; y : int
    }
  [@@deriving sexp_of, compare, equal]
end

module Rect : sig
  (** An axis-aligned rectangle anchored at its bottom-left corner. *)
  type t =
    { x : int
    ; y : int
    ; w : int
    ; h : int
    }
  [@@deriving sexp_of, compare, equal]

  (** [contains t p] is [true] when [p] lies inside [t], inclusive of all
      four edges. *)
  val contains : t -> Point.t -> bool

  (** [center t] is the midpoint of [t], rounding toward the bottom-left
      corner. *)
  val center : t -> Point.t
end
