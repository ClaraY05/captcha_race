open! Core
open Captcha_race
open Captcha_race_engine
open Captcha_race_mini_games

(* Drives the game through synthetic input only; [draw] is display-only and
   never called here. *)

let create () =
  Moving_puzzle.create
    ~random:(Random.State.make [| 7 |])
    ~bounds:Layout.play_bounds
;;

let zero = Time_ns.Span.zero

let update game ~mouse ~mouse_down ~mouse_clicked =
  Moving_puzzle.update
    game
    ~input:{ Input.idle with mouse; mouse_down; mouse_clicked }
    ~elapsed:zero
;;

(* Grab the shape at its centre, then drag by [(dx, dy)]. Because the grab is
   at the centre, moving the mouse by [(dx, dy)] moves the offset by the
   same, up to the field edges. *)
let grab_and_drag_by game ~dx ~dy =
  let piece = Moving_puzzle.For_testing.piece_rect game in
  let cx = piece.x + (piece.w / 2) in
  let cy = piece.y + (piece.h / 2) in
  let game =
    update
      game
      ~mouse:{ x = cx; y = cy }
      ~mouse_down:true
      ~mouse_clicked:true
  in
  update
    game
    ~mouse:{ x = cx + dx; y = cy + dy }
    ~mouse_down:true
    ~mouse_clicked:false
;;

let release game =
  update game ~mouse:{ x = 0; y = 0 } ~mouse_down:false ~mouse_clicked:false
;;

let%expect_test "cornering the fleeing slot at the far corner solves it" =
  let game = create () in
  print_s [%sexp (Moving_puzzle.is_solved game : bool)];
  [%expect {| false |}];
  (* Drag hard toward the top-right: the slot flees but is capped at the far
     corner, so the shape catches it there on both axes. *)
  let game = grab_and_drag_by game ~dx:10_000 ~dy:10_000 in
  let game = release game in
  print_s [%sexp (Moving_puzzle.is_solved game : bool)];
  [%expect {| true |}]
;;

let%expect_test "the slot flees forward on both axes as the shape approaches"
  =
  let game = create () in
  let start_x, start_y = Moving_puzzle.For_testing.target_offset game in
  (* Drag up to where the slot started; it should have run further away. *)
  let game = grab_and_drag_by game ~dx:start_x ~dy:start_y in
  let fled_x, fled_y = Moving_puzzle.For_testing.target_offset game in
  print_s
    [%message
      "" ~fled_x:(fled_x > start_x : bool) ~fled_y:(fled_y > start_y : bool)];
  [%expect {| ((fled_x true) (fled_y true)) |}]
;;

let%expect_test "releasing short of the slot does not solve, and snaps back" =
  let game = create () in
  (* A small drag leaves the shape far from the slot on both axes. *)
  let game = grab_and_drag_by game ~dx:12 ~dy:6 in
  let game = release game in
  print_s
    [%message
      ""
        ~solved:(Moving_puzzle.is_solved game : bool)
        ~offset:(Moving_puzzle.For_testing.offset game : int * int)];
  [%expect {| ((solved false) (offset (0 0))) |}]
;;

let%expect_test "clicking away from the shape does not grab it" =
  let game = create () in
  let piece = Moving_puzzle.For_testing.piece_rect game in
  (* Click clear of the shape, then move while held. *)
  let game =
    update
      game
      ~mouse:{ x = piece.x + 300; y = piece.y + 80 }
      ~mouse_down:true
      ~mouse_clicked:true
  in
  let game =
    update
      game
      ~mouse:{ x = piece.x + 150; y = piece.y + 40 }
      ~mouse_down:true
      ~mouse_clicked:false
  in
  print_s [%sexp (Moving_puzzle.For_testing.offset game : int * int)];
  [%expect {| (0 0) |}]
;;

let%expect_test "the slot stays within the play area, even when cornered" =
  let game = create () in
  let bounds = Layout.play_bounds in
  let within (rect : Geometry.Rect.t) =
    rect.x >= bounds.x
    && rect.y >= bounds.y
    && rect.x + rect.w <= bounds.x + bounds.w
    && rect.y + rect.h <= bounds.y + bounds.h
  in
  let start_slot = Moving_puzzle.For_testing.slot_rect game in
  (* Corner the slot at the far corner, then check it is still on-screen. *)
  let cornered = grab_and_drag_by game ~dx:10_000 ~dy:10_000 in
  let cornered_slot = Moving_puzzle.For_testing.slot_rect cornered in
  print_s
    [%message
      ""
        ~start_within:(within start_slot : bool)
        ~cornered_within:(within cornered_slot : bool)];
  [%expect {| ((start_within true) (cornered_within true)) |}]
;;
