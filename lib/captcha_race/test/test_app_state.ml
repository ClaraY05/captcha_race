open! Core
open Captcha_race

module Click_to_solve = struct
  type t = { is_solved : bool } [@@deriving sexp_of]

  let name = "click_to_solve"

  let create ~random:(_ : Random.State.t) ~bounds:(_ : Geometry.Rect.t) =
    { is_solved = false }
  ;;

  let update t ~(input : Input.t) ~elapsed:(_ : Time_ns.Span.t) =
    match input.mouse_clicked with
    | true -> { is_solved = true }
    | false -> t
  ;;

  let draw (_ : t) = ()
  let is_solved t = t.is_solved
end

let pool = [ Mini_game.pack (module Click_to_solve) ]
let click = { Input.idle with mouse_clicked = true }
let at ~seconds = Time_ns.add Time_ns.epoch (Time_ns.Span.of_int_sec seconds)
let elapsed = Time_ns.Span.of_int_ms 16

let apply model action ~seconds =
  Or_error.ok_exn
    (App_state.apply_action
       model
       action
       ~pool
       ~random:(Random.State.make [| 0 |])
       ~now:(at ~seconds))
;;

let show_view (model : App_state.Model.t) =
  let view =
    match model.view with
    | Menu -> "Menu"
    | Leaderboard -> "Leaderboard"
    | Playing (_ : Game_runner.t) -> "Playing"
  in
  print_s
    [%sexp
      { view : string
      ; leaderboard_entries =
          (List.length (Leaderboard.entries model.leaderboard) : int)
      }]
;;

let initial =
  { App_state.Model.view = Menu
  ; leaderboard = Leaderboard.empty
  ; ripple = None
  }
;;

let%expect_test "menu <-> leaderboard navigation" =
  let model = apply initial View_leaderboard ~seconds:0 in
  show_view model;
  [%expect {| ((view Leaderboard) (leaderboard_entries 0)) |}];
  show_view (apply model Back_to_menu ~seconds:1);
  [%expect {| ((view Menu) (leaderboard_entries 0)) |}]
;;

let%expect_test "each view offers the right buttons" =
  let playing = apply initial Play ~seconds:0 in
  List.iter
    [ initial.view; App_state.Leaderboard; playing.view ]
    ~f:(fun view ->
      print_s
        [%sexp
          (List.map (App_state.buttons view) ~f:(fun button -> button.label)
           : string list)]);
  [%expect {|
    (Play Leaderboard)
    (Back)
    (Quit)
    |}]
;;

let%expect_test "finishing a run records exactly one leaderboard entry" =
  let model = ref (apply initial Play ~seconds:0) in
  show_view !model;
  [%expect {| ((view Playing) (leaderboard_entries 0)) |}];
  (* One solving click per game per frame; the last one lands at t=95s. *)
  List.iter
    (List.init App_state.games_per_run ~f:(fun i -> 5 + (i * 10)))
    ~f:(fun seconds ->
      model
      := App_state.advance !model ~input:click ~now:(at ~seconds) ~elapsed);
  show_view !model;
  [%expect {| ((view Menu) (leaderboard_entries 1)) |}];
  print_s
    [%sexp
      (Option.map (Leaderboard.best !model.leaderboard) ~f:(fun entry ->
         entry.completion_time)
       : Time_ns.Span.t option)];
  [%expect {| (1m35s) |}]
;;

let%expect_test "quitting mid-run records nothing" =
  let model = apply initial Play ~seconds:0 in
  let model =
    App_state.advance model ~input:click ~now:(at ~seconds:5) ~elapsed
  in
  show_view model;
  [%expect {| ((view Playing) (leaderboard_entries 0)) |}];
  show_view (apply model Quit_run ~seconds:6);
  [%expect {| ((view Menu) (leaderboard_entries 0)) |}]
;;

let%expect_test "idle frames on menu and leaderboard change nothing" =
  List.iter
    [ initial; apply initial View_leaderboard ~seconds:0 ]
    ~f:(fun model ->
      show_view
        (App_state.advance
           model
           ~input:Input.idle
           ~now:(at ~seconds:1)
           ~elapsed));
  [%expect
    {|
    ((view Menu) (leaderboard_entries 0))
    ((view Leaderboard) (leaderboard_entries 0))
    |}]
;;
