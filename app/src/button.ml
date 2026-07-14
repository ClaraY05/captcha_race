open! Core
open Captcha_race

type 'a t =
  { label : string
  ; rect : Geometry.Rect.t
  ; action : 'a
  }
[@@deriving sexp_of]

let hit t point =
  match Geometry.Rect.contains t.rect point with
  | true -> Some t.action
  | false -> None
;;

let hit_many ts point = List.find_map ts ~f:(fun t -> hit t point)
