open! Core
open Captcha_race
open Captcha_race_engine
open Captcha_race_mini_games

(* Tests drive the game through synthetic input only; [draw] is display-only
   and never called here. *)

let create ?(seed = 1) () =
  Math_game.create
    ~random:(Random.State.make [| seed |])
    ~bounds:Layout.play_bounds
;;

let step input game = Math_game.update game ~input ~elapsed:Time_ns.Span.zero
let press key game = step { Input.idle with key = Some key } game

let click_at mouse game =
  step
    { Input.idle with mouse; mouse_down = true; mouse_clicked = true }
    game
;;

let type_string string game =
  String.fold string ~init:game ~f:(fun game key -> press key game)
;;

let click_checkbox game =
  click_at (Geometry.Rect.center (Math_game.For_testing.checkbox game)) game
;;

(* Types the correct answer and submits it, leaving the game in phase two. *)
let solve_math game =
  game
  |> type_string (Int.to_string (Math_game.For_testing.answer game))
  |> press '\r'
;;

let seeds ~count = List.init count ~f:(fun seed -> create ~seed ())

let%expect_test "generated problems" =
  List.iter (seeds ~count:8) ~f:(fun game ->
    print_endline
      [%string
        "%{Math_game.For_testing.problem game}  \
         %{Math_game.For_testing.answer game#Int}"]);
  [%expect
    {|
    95 / 5 = ?  19
    3 x 5 = ?  15
    12 - 2 = ?  10
    11 - 7 = ?  4
    5 - 4 = ?  1
    24 / 2 = ?  12
    13 + 4 = ?  17
    80 / 5 = ?  16
    |}]
;;

let%test "every answer is between 1 and 20" =
  List.for_all (seeds ~count:500) ~f:(fun game ->
    let answer = Math_game.For_testing.answer game in
    answer >= 1 && answer <= 20)
;;

(* Both operands stay typable and mentally tractable: division caps the
   dividend at two digits, and the widest right operand is addition's
   ([1 + 19]). Nothing may be negative, fractional, or unbounded. *)
let%test "operands stay small and positive" =
  List.for_all (seeds ~count:500) ~f:(fun game ->
    let left, right = Math_game.For_testing.operands game in
    left >= 1 && left <= 99 && right >= 1 && right <= 19)
;;

let%expect_test "all four operators show up" =
  let problems =
    List.map (seeds ~count:200) ~f:Math_game.For_testing.problem
  in
  List.iter [ "+"; "-"; "x"; "/" ] ~f:(fun operator ->
    let appears =
      List.exists problems ~f:(String.is_substring ~substring:operator)
    in
    print_endline [%string "%{operator} %{appears#Bool}"]);
  [%expect {|
    + true
    - true
    x true
    / true
    |}]
;;

let%test "division problems divide exactly" =
  List.for_all (seeds ~count:500) ~f:(fun game ->
    let left, right = Math_game.For_testing.operands game in
    match
      String.is_substring (Math_game.For_testing.problem game) ~substring:"/"
    with
    | false -> true
    | true -> left % right = 0)
;;

let%expect_test "the right answer starts the clicking phase" =
  let game = create () in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Solving_math (typed "") (wrong_attempts 0))))
    |}];
  let game = solve_math game in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Clicking (clicks_remaining 15) (fill_remaining 0s))))
    |}];
  print_s [%sexp (Math_game.is_solved game : bool)];
  [%expect {| false |}]
;;

let%expect_test "the Enter button submits like the Return key" =
  let game = create () in
  let game =
    game
    |> type_string (Int.to_string (Math_game.For_testing.answer game))
    |> fun game ->
    click_at
      (Geometry.Rect.center (Math_game.For_testing.enter_button game))
      game
  in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Clicking (clicks_remaining 15) (fill_remaining 0s))))
    |}]
;;

let%expect_test "a wrong answer clears the field and keeps the problem" =
  let game = create () in
  let wrong =
    match Math_game.For_testing.answer game = 1 with
    | true -> "2"
    | false -> "1"
  in
  let game = game |> type_string wrong |> press '\r' in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Solving_math (typed "") (wrong_attempts 1))))
    |}]
;;

let%expect_test "non-digits are ignored and backspace deletes" =
  let game = create () |> type_string "a1b2" in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Solving_math (typed 12) (wrong_attempts 0))))
    |}];
  (* Three backspaces on two digits: the third must not raise. *)
  let game = game |> press '\b' |> press '\b' |> press '\b' in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Solving_math (typed "") (wrong_attempts 0))))
    |}]
;;

let%expect_test "the field holds at most two digits" =
  let game = create () |> type_string "123" in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Solving_math (typed 12) (wrong_attempts 0))))
    |}]
;;

let%expect_test "submitting an empty field does nothing" =
  let game = create () |> press '\r' in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Solving_math (typed "") (wrong_attempts 0))))
    |}]
;;

let%expect_test "the checkbox must be clicked exactly [answer] times" =
  let game = solve_math (create ()) in
  let answer = Math_game.For_testing.answer game in
  let game = Fn.apply_n_times ~n:(answer - 1) click_checkbox game in
  print_s [%sexp (Math_game.is_solved game : bool)];
  [%expect {| false |}];
  let game = click_checkbox game in
  print_s [%sexp (Math_game.is_solved game : bool)];
  [%expect {| true |}]
;;

let%expect_test "clicks outside the checkbox do not count" =
  let game = solve_math (create ()) in
  let checkbox = Math_game.For_testing.checkbox game in
  let miss = { Geometry.Point.x = checkbox.x - 5; y = checkbox.y - 5 } in
  let game = Fn.apply_n_times ~n:30 (click_at miss) game in
  print_s [%sexp (Math_game.is_solved game : bool)];
  [%expect {| false |}]
;;

let%expect_test "the checkbox is inert until the math is solved" =
  (* The checkbox's rect sits inside the phase-one panel, so a click there
     reaches the game — it just must not do anything yet. *)
  let game = Fn.apply_n_times ~n:5 click_checkbox (create ()) in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Solving_math (typed "") (wrong_attempts 0))))
    |}]
;;

let%expect_test "the check blinks out well before the next click" =
  let game = click_checkbox (solve_math (create ())) in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Clicking (clicks_remaining 14) (fill_remaining 100ms))))
    |}];
  let game =
    Math_game.update
      game
      ~input:Input.idle
      ~elapsed:(Time_ns.Span.of_int_ms 150)
  in
  print_s [%sexp (game : Math_game.t)];
  [%expect
    {|
    ((problem ((left 3) (operator Multiply) (right 5)))
     (bounds ((x 196) (y 226) (w 408) (h 152)))
     (phase (Clicking (clicks_remaining 14) (fill_remaining 0s))))
    |}]
;;

let%expect_test "the layout stays inside the bounds" =
  let bounds = Layout.play_bounds in
  let game = create () in
  let fits (rect : Geometry.Rect.t) =
    rect.x >= bounds.x
    && rect.y >= bounds.y
    && rect.x + rect.w <= bounds.x + bounds.w
    && rect.y + rect.h <= bounds.y + bounds.h
  in
  let rects =
    [ "enter button", Math_game.For_testing.enter_button game
    ; "checkbox", Math_game.For_testing.checkbox game
    ]
  in
  List.iter rects ~f:(fun (name, rect) ->
    print_endline [%string "%{name} %{fits rect#Bool}"]);
  [%expect {|
    enter button true
    checkbox true
    |}]
;;
