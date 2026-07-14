open! Core
open Captcha_race

(* A drag-puzzle captcha with a mischievous twist, in two dimensions. A shape
   sits at the bottom-left of the play area and an empty slot waits up and to
   its right. Dragging the shape moves it freely on both axes — but the slot
   flees, sliding away on each axis to stay [flee_gap] ahead as the shape
   approaches. It only ever runs forward (up and to the right) and never past
   the far corner, so the player can still corner it there and drop the shape
   in. Releasing with the shape lined up with the slot on both axes (within
   [tolerance]) solves the game; releasing short snaps the shape back to the
   start. Chasing a target that dodges diagonally is the challenge. *)

type t =
  { bounds : Geometry.Rect.t
  ; target_x : int (* slot offset from the start, x, in pixels *)
  ; target_y : int (* slot offset from the start, y, in pixels *)
  ; off_x : int (* current shape offset, [0, max_x] *)
  ; off_y : int (* current shape offset, [0, max_y] *)
  ; dragging : bool
  ; grab_dx : int (* mouse.x - piece.x captured when grabbed *)
  ; grab_dy : int (* mouse.y - piece.y captured when grabbed *)
  ; solved : bool
  }
[@@deriving sexp_of]

let name = "drag the puzzle"

(* Layout constants, all in pixels. The shape roams a 2-D field that fills
   the play area below a one-line instruction. *)
let piece_size = 40
let margin = 14
let label_h = 20
let tolerance = 12

(* How far ahead of the shape the slot keeps as it flees, on each axis. *)
let flee_gap = 46

(* Everything below is derived from [bounds] so the layout scales with the
   play area rather than being hard-coded to a window size. The field is the
   region the shape's bottom-left corner may occupy. *)
let field_x (b : Geometry.Rect.t) = b.x + margin
let field_y (b : Geometry.Rect.t) = b.y + margin
let field_w (b : Geometry.Rect.t) = b.w - (2 * margin)
let field_h (b : Geometry.Rect.t) = b.h - (2 * margin) - label_h
let max_x b = field_w b - piece_size
let max_y b = field_h b - piece_size
let label_y (b : Geometry.Rect.t) = field_y b + field_h b + 4

let piece_rect t : Geometry.Rect.t =
  { x = field_x t.bounds + t.off_x
  ; y = field_y t.bounds + t.off_y
  ; w = piece_size
  ; h = piece_size
  }
;;

let slot_rect t : Geometry.Rect.t =
  { x = field_x t.bounds + t.target_x
  ; y = field_y t.bounds + t.target_y
  ; w = piece_size
  ; h = piece_size
  }
;;

let create ~random ~(bounds : Geometry.Rect.t) =
  let mx = max_x bounds in
  let my = max_y bounds in
  (* Start the slot short of the far corner so it has room to flee. *)
  let target_x = Random.State.int_incl random (mx / 4) (mx * 3 / 5) in
  let target_y = Random.State.int_incl random (my / 4) (my * 3 / 5) in
  { bounds
  ; target_x
  ; target_y
  ; off_x = 0
  ; off_y = 0
  ; dragging = false
  ; grab_dx = 0
  ; grab_dy = 0
  ; solved = false
  }
;;

let update t ~(input : Input.t) ~elapsed:(_ : Time_ns.Span.t) =
  match t.solved with
  | true -> t
  | false ->
    (match t.dragging with
     | false ->
       (match
          input.mouse_clicked
          && Geometry.Rect.contains (piece_rect t) input.mouse
        with
        | false -> t
        | true ->
          let piece = piece_rect t in
          { t with
            dragging = true
          ; grab_dx = input.mouse.x - piece.x
          ; grab_dy = input.mouse.y - piece.y
          })
     | true ->
       (match input.mouse_down with
        | true ->
          let mx = max_x t.bounds in
          let my = max_y t.bounds in
          let off_x =
            Int.clamp_exn
              (input.mouse.x - t.grab_dx - field_x t.bounds)
              ~min:0
              ~max:mx
          in
          let off_y =
            Int.clamp_exn
              (input.mouse.y - t.grab_dy - field_y t.bounds)
              ~min:0
              ~max:my
          in
          (* The slot flees to stay [flee_gap] ahead on each axis — but only
             ever forward, and never past the corner, so it can be cornered. *)
          let target_x =
            Int.max t.target_x (Int.min mx (off_x + flee_gap))
          in
          let target_y =
            Int.max t.target_y (Int.min my (off_y + flee_gap))
          in
          { t with off_x; off_y; target_x; target_y }
        | false ->
          (match
             Int.abs (t.off_x - t.target_x) <= tolerance
             && Int.abs (t.off_y - t.target_y) <= tolerance
           with
           | true ->
             { t with
               dragging = false
             ; solved = true
             ; off_x = t.target_x
             ; off_y = t.target_y
             }
           | false -> { t with dragging = false; off_x = 0; off_y = 0 })))
;;

let is_solved t = t.solved

let draw t =
  let draw_box (rect : Geometry.Rect.t) ~fill ~outline =
    Graphics.set_color fill;
    Graphics.fill_rect rect.x rect.y rect.w rect.h;
    Graphics.set_color outline;
    Graphics.draw_rect rect.x rect.y rect.w rect.h
  in
  let b = t.bounds in
  (* Instruction near the top of the play area, centred. Dark ink so it reads
     on the light card the game is drawn on. *)
  let label = "Drag the piece into the slot" in
  let label_w, (_ : int) = Graphics.text_size label in
  Graphics.set_color (Graphics.rgb 60 58 52);
  Graphics.moveto (b.x + ((b.w - label_w) / 2)) (label_y b);
  Graphics.draw_string label;
  (* The empty slot: a recessed grey square outline. *)
  draw_box
    (slot_rect t)
    ~fill:(Graphics.rgb 205 205 205)
    ~outline:(Graphics.rgb 120 120 120);
  (* The draggable shape, green once solved. *)
  let piece = piece_rect t in
  let piece_color =
    match t.solved with
    | true -> Graphics.rgb 80 180 90
    | false -> Graphics.rgb 70 120 200
  in
  draw_box piece ~fill:piece_color ~outline:Graphics.black;
  (* A round knob so it reads as a puzzle piece rather than a plain box. *)
  let knob_r = piece_size / 6 in
  Graphics.set_color piece_color;
  Graphics.fill_circle (piece.x + piece.w) (piece.y + (piece.h / 2)) knob_r;
  Graphics.set_color Graphics.black;
  Graphics.draw_circle (piece.x + piece.w) (piece.y + (piece.h / 2)) knob_r;
  (* Centre mark: a move-cross while playing, "OK" once solved, so it reads
     as a thing you drag in any direction. *)
  let cx = piece.x + (piece.w / 2) in
  let cy = piece.y + (piece.h / 2) in
  match t.solved with
  | true ->
    Graphics.set_color (Graphics.rgb 240 240 240);
    let tw, th = Graphics.text_size "OK" in
    Graphics.moveto (cx - (tw / 2)) (cy - (th / 2));
    Graphics.draw_string "OK"
  | false ->
    Graphics.set_color (Graphics.rgb 235 235 235);
    Graphics.moveto (cx - 7) cy;
    Graphics.lineto (cx + 7) cy;
    Graphics.moveto cx (cy - 7);
    Graphics.lineto cx (cy + 7)
;;

module For_testing = struct
  let target_offset t = t.target_x, t.target_y
  let offset t = t.off_x, t.off_y
  let piece_rect = piece_rect
  let slot_rect = slot_rect
end
