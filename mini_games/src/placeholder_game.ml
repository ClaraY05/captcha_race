open! Core
open Captcha_race

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
  (* A recessed field on the captcha card: light fill with an inset shadow
     along the top-left, an accent check box, and dark ink label — matching
     the flat pixel palette [Render] draws the rest of the card in. *)
  Graphics.set_color (Graphics.rgb 217 212 200);
  Graphics.fill_rect x y w h;
  Graphics.set_color (Graphics.rgb 195 188 171);
  Graphics.fill_rect x (y + h - 3) w 3;
  Graphics.fill_rect x y 3 h;
  let box = 20 in
  let box_x = x + 14 in
  let box_y = y + ((h - box) / 2) in
  Graphics.set_color (Graphics.rgb 203 171 99);
  Graphics.fill_rect box_x box_y box box;
  Graphics.set_color (Graphics.rgb 38 36 31);
  Graphics.draw_rect box_x box_y box box;
  let label = "I am not a robot" in
  let (_ : int), text_h = Graphics.text_size label in
  Graphics.moveto (box_x + box + 12) (y + ((h - text_h) / 2));
  Graphics.draw_string label
;;

let is_solved t = t.is_solved

module For_testing = struct
  let target t = t.target
end
