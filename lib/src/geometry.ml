open! Core

module Point = struct
  type t =
    { x : int
    ; y : int
    }
  [@@deriving sexp_of, compare, equal]
end

module Rect = struct
  type t =
    { x : int
    ; y : int
    ; w : int
    ; h : int
    }
  [@@deriving sexp_of, compare, equal]

  let contains { x; y; w; h } { Point.x = px; y = py } =
    px >= x && px <= x + w && py >= y && py <= y + h
  ;;

  let center { x; y; w; h } = { Point.x = x + (w / 2); y = y + (h / 2) }
end
