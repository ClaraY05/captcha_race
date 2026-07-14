open! Core
open Captcha_race
open Captcha_race_engine
open Captcha_race_mini_games

(* Tests drive the game through synthetic input only; [draw] is display-only
   and never called here. The distortion is a pure function of the [~elapsed]
   fed to [update], so "waiting" is just a large span. *)

let create ?(seed = 1) () =
  Typing_game.create
    ~random:(Random.State.make [| seed |])
    ~bounds:Layout.play_bounds
;;

let step ?(elapsed = Time_ns.Span.zero) input game =
  Typing_game.update game ~input ~elapsed
;;

let press key game = step { Input.idle with key = Some key } game

let click_at mouse game =
  step
    { Input.idle with mouse; mouse_down = true; mouse_clicked = true }
    game
;;

let wait span game = step ~elapsed:span Input.idle game

let type_string string game =
  String.fold string ~init:game ~f:(fun game key -> press key game)
;;

(* Types the word that is actually on screen and submits it. *)
let solve game =
  game |> type_string (Typing_game.For_testing.word game) |> press '\r'
;;

let seeds ~count = List.init count ~f:(fun seed -> create ~seed ())

let print_state game =
  print_s
    [%message
      ""
        ~word:(Typing_game.For_testing.word game : string)
        ~typed:(Typing_game.For_testing.typed game : string)
        ~distortion:(Typing_game.For_testing.distortion game : float)
        ~wrong_attempts:(Typing_game.For_testing.wrong_attempts game : int)
        ~is_solved:(Typing_game.is_solved game : bool)]
;;

let%expect_test "a fresh game shows a word, fully distorted" =
  print_state (create ());
  [%expect
    {|
    ((word forest) (typed "") (distortion 1) (wrong_attempts 0)
     (is_solved false))
    |}]
;;

let%expect_test "the seed picks the word" =
  List.iter (seeds ~count:6) ~f:(fun game ->
    print_endline (Typing_game.For_testing.word game));
  [%expect
    {|
    harbor
    forest
    silver
    temple
    hollow
    island
    |}]
;;

let%test "every word is a plain lowercase word of typable length" =
  List.for_all (seeds ~count:200) ~f:(fun game ->
    let word = Typing_game.For_testing.word game in
    String.length word >= 5
    && String.length word <= 7
    && String.for_all word ~f:Char.is_lowercase)
;;

let%expect_test "typing the word and pressing Return solves it" =
  let game = solve (create ()) in
  print_state game;
  [%expect
    {|
    ((word forest) (typed forest) (distortion 1) (wrong_attempts 0)
     (is_solved true))
    |}]
;;

let%expect_test "the Enter button submits like the Return key" =
  let game = create () in
  let game =
    game
    |> type_string (Typing_game.For_testing.word game)
    |> fun game ->
    click_at
      (Geometry.Rect.center (Typing_game.For_testing.enter_button game))
      game
  in
  print_s [%sexp (Typing_game.is_solved game : bool)];
  [%expect {| true |}]
;;

let%expect_test "a wrong guess clears the field and keeps the same word" =
  let game = create () |> type_string "wrong" |> press '\r' in
  print_state game;
  [%expect
    {|
    ((word forest) (typed "") (distortion 1) (wrong_attempts 1)
     (is_solved false))
    |}];
  (* The word does not change under the player: the second guess is at the
     same one. *)
  print_s [%sexp (Typing_game.is_solved (solve game) : bool)];
  [%expect {| true |}]
;;

let%expect_test "a prefix of the word is not the word" =
  let game = create () in
  let prefix = String.prefix (Typing_game.For_testing.word game) 4 in
  let game = game |> type_string prefix |> press '\r' in
  print_state game;
  [%expect
    {|
    ((word forest) (typed "") (distortion 1) (wrong_attempts 1)
     (is_solved false))
    |}]
;;

let%expect_test "submitting an empty field does nothing" =
  let game = create () |> press '\r' in
  print_state game;
  [%expect
    {|
    ((word forest) (typed "") (distortion 1) (wrong_attempts 0)
     (is_solved false))
    |}]
;;

let%expect_test "letters are taken lowercase, digits ignored, backspace \
                 deletes"
  =
  let game = create () |> type_string "P9uZ" in
  print_s [%sexp (Typing_game.For_testing.typed game : string)];
  [%expect {| puz |}];
  (* Four backspaces on three letters: the fourth must not raise. *)
  let game = Fn.apply_n_times ~n:4 (press '\b') game in
  print_s [%sexp (Typing_game.For_testing.typed game : string)];
  [%expect {| "" |}]
;;

let%expect_test "the field stops at 12 letters" =
  let game = create () |> type_string "abcdefghijklmnop" in
  print_s [%sexp (Typing_game.For_testing.typed game : string)];
  [%expect {| abcdefghijkl |}]
;;

let%expect_test "the distortion decays to nothing over [clear_after]" =
  let game = create () in
  let half =
    Time_ns.Span.scale Typing_game.For_testing.clear_after 0.5 |> wait
  in
  let game = half game in
  print_s [%sexp (Typing_game.For_testing.distortion game : float)];
  [%expect {| 0.5 |}];
  let game = half game in
  print_s [%sexp (Typing_game.For_testing.distortion game : float)];
  [%expect {| 0 |}];
  (* And it stays there: no negative distortion, however long the player
     dawdles. *)
  let game = half game in
  print_s [%sexp (Typing_game.For_testing.distortion game : float)];
  [%expect {| 0 |}]
;;

let%expect_test "the word can be solved while still fully distorted" =
  (* Nothing gates submission on the distortion: a player who can read the
     smear finishes at once, which is the whole point of the game. *)
  let game = create () in
  print_s [%sexp (Typing_game.For_testing.distortion game : float)];
  [%expect {| 1 |}];
  print_s [%sexp (Typing_game.is_solved (solve game) : bool)];
  [%expect {| true |}]
;;

let%expect_test "a wrong guess neither sets the clock back nor speeds it up" =
  let game =
    create ()
    |> wait (Time_ns.Span.of_int_sec 5)
    |> type_string "wrong"
    |> press '\r'
  in
  print_state game;
  [%expect
    {|
    ((word forest) (typed "") (distortion 0.75) (wrong_attempts 1)
     (is_solved false))
    |}]
;;

let%expect_test "a solved game freezes" =
  let game = solve (create ()) |> wait (Time_ns.Span.of_int_sec 5) in
  print_state game;
  [%expect
    {|
    ((word forest) (typed forest) (distortion 1) (wrong_attempts 0)
     (is_solved true))
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
    [ "word area", Typing_game.For_testing.word_area game
    ; "input box", Typing_game.For_testing.input_box game
    ; "enter button", Typing_game.For_testing.enter_button game
    ]
  in
  List.iter rects ~f:(fun (name, rect) ->
    print_endline [%string "%{name} %{fits rect#Bool}"]);
  [%expect
    {|
    word area true
    input box true
    enter button true
    |}]
;;
