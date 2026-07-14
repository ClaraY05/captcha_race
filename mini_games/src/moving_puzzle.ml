open! Core
open Captcha_race

(* A slider-puzzle captcha with a mischievous twist. A shape sits at the left
   of the play area and an empty slot waits to its right. Dragging the handle
   along the track slides the shape toward the slot — but the slot flees,
   sliding away to stay [flee_gap] ahead as the shape approaches. It only
   ever runs forward and never past the right wall, so the player can still
   corner it at the edge and drop the shape in; releasing lined up (within
   [tolerance]) solves the game, and releasing short snaps the shape back to
   the start. *)

type t =
  { bounds : Geometry.Rect.t
  ; target : int (* slot offset from the start, in pixels *)
  ; offset : int (* current shape/handle offset, [0, max_offset] *)
  ; dragging : bool
  ; grab_dx : int (* mouse.x - handle.x captured when grabbed *)
  ; solved : bool
  }
[@@deriving sexp_of]

let name = "slide the puzzle"

(* Layout constants, all in pixels. Sized to fit a compact play area — the
   pieces stack vertically as slider / label / puzzle, so nothing overlaps
   even on the small CRT screen. *)
let piece_size = 48
let track_h = 22
let handle_w = 48
let margin = 16
let label_gap = 10
let tolerance = 10

(* How far ahead of the shape the slot keeps as it flees. *)
let flee_gap = 70

(* Everything below is derived from [bounds] so the layout scales with the
   play area and nothing is hard-coded to a particular window size. The
   slider sits along the bottom, the instruction label just above it, and the
   puzzle piece and slot fill the top of the area. *)
let track_x (b : Geometry.Rect.t) = b.x + margin
let track_y (b : Geometry.Rect.t) = b.y + margin
let track_w (b : Geometry.Rect.t) = b.w - (2 * margin)
let max_offset b = track_w b - handle_w
let label_y (b : Geometry.Rect.t) = track_y b + track_h + label_gap
let piece_left (b : Geometry.Rect.t) = b.x + margin
let piece_y (b : Geometry.Rect.t) = b.y + b.h - piece_size - margin

let handle_rect t : Geometry.Rect.t =
  { x = track_x t.bounds + t.offset
  ; y = track_y t.bounds
  ; w = handle_w
  ; h = track_h
  }
;;

let piece_rect t : Geometry.Rect.t =
  { x = piece_left t.bounds + t.offset
  ; y = piece_y t.bounds
  ; w = piece_size
  ; h = piece_size
  }
;;

let slot_rect t : Geometry.Rect.t =
  { x = piece_left t.bounds + t.target
  ; y = piece_y t.bounds
  ; w = piece_size
  ; h = piece_size
  }
;;

let create ~random ~(bounds : Geometry.Rect.t) =
  let max_off = max_offset bounds in
  (* Start the slot short of the wall so it has room to flee toward it. *)
  let target =
    Random.State.int_incl random (max_off / 4) (max_off * 3 / 5)
  in
  { bounds
  ; target
  ; offset = 0
  ; dragging = false
  ; grab_dx = 0
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
          && Geometry.Rect.contains (handle_rect t) input.mouse
        with
        | false -> t
        | true ->
          { t with
            dragging = true
          ; grab_dx = input.mouse.x - (track_x t.bounds + t.offset)
          })
     | true ->
       (match input.mouse_down with
        | true ->
          let max_off = max_offset t.bounds in
          let offset =
            Int.clamp_exn
              (input.mouse.x - t.grab_dx - track_x t.bounds)
              ~min:0
              ~max:max_off
          in
          (* The slot flees to stay [flee_gap] ahead of the shape — but only
             ever forward, and never past the wall, so it can be cornered. *)
          let target =
            Int.max t.target (Int.min max_off (offset + flee_gap))
          in
          { t with offset; target }
        | false ->
          (match Int.abs (t.offset - t.target) <= tolerance with
           | true ->
             { t with dragging = false; solved = true; offset = t.target }
           | false -> { t with dragging = false; offset = 0 })))
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
  (* Instruction sits in the band just above the slider, centred. Dark ink so
     it reads on the light card the game is drawn on. *)
  let label = "Slide the piece into the slot" in
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
  let knob_x = piece.x + piece.w in
  let knob_y = piece.y + (piece.h / 2) in
  Graphics.set_color piece_color;
  Graphics.fill_circle knob_x knob_y knob_r;
  Graphics.set_color Graphics.black;
  Graphics.draw_circle knob_x knob_y knob_r;
  (* The slider track and its handle. *)
  draw_box
    { x = track_x b; y = track_y b; w = track_w b; h = track_h }
    ~fill:(Graphics.rgb 228 228 228)
    ~outline:(Graphics.rgb 150 150 150);
  let handle = handle_rect t in
  let handle_color =
    match t.solved with
    | true -> Graphics.rgb 80 180 90
    | false -> Graphics.rgb 250 250 250
  in
  draw_box handle ~fill:handle_color ~outline:(Graphics.rgb 80 80 80);
  Graphics.set_color (Graphics.rgb 60 60 60);
  Graphics.moveto
    (handle.x + (handle.w / 2) - 7)
    (handle.y + (handle.h / 2) - 6);
  Graphics.draw_string (match t.solved with true -> "OK" | false -> ">>")
;;

module For_testing = struct
  let target_offset t = t.target
  let handle_rect = handle_rect
  let slot_rect = slot_rect
  let offset t = t.offset
end
