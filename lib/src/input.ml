open! Core

type t =
  { mouse : Geometry.Point.t
  ; mouse_down : bool
  ; mouse_clicked : bool
  ; key : char option
  }
[@@deriving sexp_of]

let idle =
  { mouse = { Geometry.Point.x = 0; y = 0 }
  ; mouse_down = false
  ; mouse_clicked = false
  ; key = None
  }
;;
