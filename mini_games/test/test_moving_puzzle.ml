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

let%expect_test "dragging the shape into the slot solves it" =
  let game = create () in
  print_s [%sexp (Moving_puzzle.is_solved game : bool)];
  [%expect {| false |}];
  let target = Moving_puzzle.For_testing.target_offset game in
  let game = grab_and_drag_to game ~offset:target in
  (* Lined up before release. *)
  print_s [%sexp (Moving_puzzle.For_testing.offset game = target : bool)];
  [%expect {| true |}];
  let game = release game in
  print_s [%sexp (Moving_puzzle.is_solved game : bool)];
  [%expect {| true |}]
;;

let%expect_test "releasing off-target snaps back and does not solve" =
  let game = create () in
  let target = Moving_puzzle.For_testing.target_offset game in
  (* Drag well short of the slot (target is at least max_offset/3, so this
     stays in range and is far outside the tolerance). *)
  let game = grab_and_drag_to game ~offset:(target - 80) in
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

let%expect_test "the slot sits within the play area and to the right of the \
                 start"
  =
  let game = create () in
  let target = Moving_puzzle.For_testing.target_offset game in
  let bounds = Layout.play_bounds in
  let slot = Moving_puzzle.For_testing.slot_rect game in
  let within (rect : Geometry.Rect.t) =
    rect.x >= bounds.x
    && rect.y >= bounds.y
    && rect.x + rect.w <= bounds.x + bounds.w
    && rect.y + rect.h <= bounds.y + bounds.h
  in
  print_s
    [%message
      ""
        ~target_is_a_real_drag:(target > 0 : bool)
        ~slot_within_bounds:(within slot : bool)];
  [%expect {| ((target_is_a_real_drag true) (slot_within_bounds true)) |}]
;;
