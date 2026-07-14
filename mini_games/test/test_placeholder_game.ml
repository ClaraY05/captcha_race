open! Core
open Captcha_race
open Captcha_race_engine
open Captcha_race_mini_games

(* Tests drive the game through synthetic input only; [draw] is display-only
   and never called here. *)

let create () =
  Placeholder_game.create
    ~random:(Random.State.make [| 1 |])
    ~bounds:Layout.play_bounds
;;

let click_at mouse =
  { Input.idle with mouse; mouse_down = true; mouse_clicked = true }
;;

let%expect_test "clicking the target solves the game" =
  let game = create () in
  let target = Placeholder_game.For_testing.target game in
  print_s [%sexp (Placeholder_game.is_solved game : bool)];
  [%expect {| false |}];
  let game =
    Placeholder_game.update
      game
      ~input:(click_at (Geometry.Rect.center target))
      ~elapsed:Time_ns.Span.zero
  in
  print_s [%sexp (Placeholder_game.is_solved game : bool)];
  [%expect {| true |}]
;;

let%expect_test "clicks off the target, hovers, and keys do not solve" =
  let game = create () in
  let target = Placeholder_game.For_testing.target game in
  let miss = { Geometry.Point.x = target.x - 1; y = target.y - 1 } in
  let inputs =
    [ click_at miss
    ; { Input.idle with mouse = Geometry.Rect.center target } (* hover *)
    ; { Input.idle with key = Some ' ' }
    ]
  in
  let game =
    List.fold inputs ~init:game ~f:(fun game input ->
      Placeholder_game.update game ~input ~elapsed:Time_ns.Span.zero)
  in
  print_s [%sexp (Placeholder_game.is_solved game : bool)];
  [%expect {| false |}]
;;

let%expect_test "the target lands inside the given bounds" =
  let bounds = Layout.play_bounds in
  let target = Placeholder_game.For_testing.target (create ()) in
  let fits =
    target.x >= bounds.x
    && target.y >= bounds.y
    && target.x + target.w <= bounds.x + bounds.w
    && target.y + target.h <= bounds.y + bounds.h
  in
  print_s [%sexp (fits : bool)];
  [%expect {| true |}]
;;
