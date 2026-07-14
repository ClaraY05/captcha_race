open! Core

type t =
  { target : Geometry.Rect.t
  ; is_solved : bool
  }
[@@deriving sexp_of]

let name = "not a robot"
let target_w = 180
let target_h = 50

let create ~random ~(bounds : Geometry.Rect.t) =
  let x =
    Random.State.int_incl random bounds.x (bounds.x + bounds.w - target_w)
  in
  let y =
    Random.State.int_incl random bounds.y (bounds.y + bounds.h - target_h)
  in
  { target = { Geometry.Rect.x; y; w = target_w; h = target_h }
  ; is_solved = false
  }
;;

let update t ~(input : Input.t) ~elapsed:(_ : Time_ns.Span.t) =
  match
    input.mouse_clicked && Geometry.Rect.contains t.target input.mouse
  with
  | true -> { t with is_solved = true }
  | false -> t
;;

let draw t =
  let { Geometry.Rect.x; y; w; h } = t.target in
  Graphics.set_color (Graphics.rgb 235 235 235);
  Graphics.fill_rect x y w h;
  Graphics.set_color Graphics.black;
  Graphics.draw_rect x y w h;
  let label = "[ ] I am not a robot" in
  let text_w, text_h = Graphics.text_size label in
  Graphics.moveto (x + ((w - text_w) / 2)) (y + ((h - text_h) / 2));
  Graphics.draw_string label
;;

let is_solved t = t.is_solved

module For_testing = struct
  let target t = t.target
end
