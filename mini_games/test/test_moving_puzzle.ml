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

(* Grab the handle at its centre, then drag so the shape reaches [offset].
   Because the grab is at the centre, moving the mouse by N pixels moves the
   offset by N. *)
let grab_and_drag_to game ~offset =
  let handle = Moving_puzzle.For_testing.handle_rect game in
  let cx = handle.x + (handle.w / 2) in
  let cy = handle.y + (handle.h / 2) in
  let game =
    update
      game
      ~mouse:{ x = cx; y = cy }
      ~mouse_down:true
      ~mouse_clicked:true
  in
  update
    game
    ~mouse:{ x = cx + offset; y = cy }
    ~mouse_down:true
    ~mouse_clicked:false
;;

let release game =
  update game ~mouse:{ x = 0; y = 0 } ~mouse_down:false ~mouse_clicked:false
;;

let%expect_test "cornering the fleeing slot at the wall solves it" =
  let game = create () in
  print_s [%sexp (Moving_puzzle.is_solved game : bool)];
  [%expect {| false |}];
  (* Drag hard to the right: the slot flees but is capped at the wall, so the
     shape catches it there. (A huge offset clamps to the maximum.) *)
  let game = grab_and_drag_to game ~offset:10_000 in
  let game = release game in
  print_s [%sexp (Moving_puzzle.is_solved game : bool)];
  [%expect {| true |}]
;;

let%expect_test "the slot flees forward as the shape approaches" =
  let game = create () in
  let start = Moving_puzzle.For_testing.target_offset game in
  (* Drag up to where the slot started; it should have run further right. *)
  let game = grab_and_drag_to game ~offset:start in
  let fled = Moving_puzzle.For_testing.target_offset game in
  print_s [%message "" ~fled_forward:(fled > start : bool)];
  [%expect {| (fled_forward true) |}]
;;

let%expect_test "releasing short of the slot does not solve, and snaps back" =
  let game = create () in
  (* A small drag leaves the shape far from the slot. *)
  let game = grab_and_drag_to game ~offset:20 in
  let game = release game in
  print_s
    [%message
      ""
        ~solved:(Moving_puzzle.is_solved game : bool)
        ~offset:(Moving_puzzle.For_testing.offset game : int)];
  [%expect {| ((solved false) (offset 0)) |}]
;;

let%expect_test "clicking away from the handle does not grab it" =
  let game = create () in
  let before = (Moving_puzzle.For_testing.handle_rect game).x in
  (* Click far from the handle, then move while held. *)
  let game =
    update
      game
      ~mouse:{ x = before + 400; y = 500 }
      ~mouse_down:true
      ~mouse_clicked:true
  in
  let game =
    update
      game
      ~mouse:{ x = before + 200; y = 60 }
      ~mouse_down:true
      ~mouse_clicked:false
  in
  let after = (Moving_puzzle.For_testing.handle_rect game).x in
  print_s [%message "" ~moved:(before <> after : bool)];
  [%expect {| (moved false) |}]
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
  (* Corner the slot at the wall, then check it is still on-screen. *)
  let cornered = grab_and_drag_to game ~offset:10_000 in
  let cornered_slot = Moving_puzzle.For_testing.slot_rect cornered in
  print_s
    [%message
      ""
        ~start_within:(within start_slot : bool)
        ~cornered_within:(within cornered_slot : bool)];
  [%expect {| ((start_within true) (cornered_within true)) |}]
;;
