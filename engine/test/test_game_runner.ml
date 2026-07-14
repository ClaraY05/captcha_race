open! Core
open Captcha_race
open Captcha_race_engine

(* Tiny display-free games for driving the runner. [Click_to_solve] solves on
   any click, [Key_to_solve] on any keypress, so tests control exactly when
   the runner moves on. *)

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

module Key_to_solve = struct
  type t = { is_solved : bool } [@@deriving sexp_of]

  let name = "key_to_solve"

  let create ~random:(_ : Random.State.t) ~bounds:(_ : Geometry.Rect.t) =
    { is_solved = false }
  ;;

  let update t ~(input : Input.t) ~elapsed:(_ : Time_ns.Span.t) =
    match input.key with
    | Some (_ : char) -> { is_solved = true }
    | None -> t
  ;;

  let draw (_ : t) = ()
  let is_solved t = t.is_solved
end

let click = { Input.idle with mouse_clicked = true }
let bounds = Layout.play_bounds
let at ~seconds = Time_ns.add Time_ns.epoch (Time_ns.Span.of_int_sec seconds)
let elapsed = Time_ns.Span.of_int_ms 16

let%expect_test "a fixed seed picks a deterministic sequence" =
  let runner =
    Or_error.ok_exn
      (Game_runner.create
         ~pool:
           [ Mini_game.pack (module Click_to_solve)
           ; Mini_game.pack (module Key_to_solve)
           ]
         ~random:(Random.State.make [| 42 |])
         ~bounds
         ~now:Time_ns.epoch
         ~count:10)
  in
  print_s [%sexp (runner : Game_runner.t)];
  [%expect
    {|
    ((index 0) (count 10)
     (games
      (click_to_solve click_to_solve key_to_solve click_to_solve key_to_solve
       click_to_solve click_to_solve click_to_solve click_to_solve
       click_to_solve))
     (started_at "1970-01-01 00:00:00Z"))
    |}]
;;

let%expect_test "the runner advances only when the current game solves" =
  let runner =
    Or_error.ok_exn
      (Game_runner.create
         ~pool:[ Mini_game.pack (module Click_to_solve) ]
         ~random:(Random.State.make [| 0 |])
         ~bounds
         ~now:Time_ns.epoch
         ~count:3)
  in
  let advance ~input ~seconds =
    let result =
      Game_runner.advance runner ~input ~now:(at ~seconds) ~elapsed
    in
    let current_index = Game_runner.current_index runner in
    print_s
      [%sexp
        ~~(current_index : int)
        , (result : [ `Running | `Finished of Time_ns.Span.t ])]
  in
  (* Idle frames do nothing. *)
  advance ~input:Input.idle ~seconds:1;
  advance ~input:Input.idle ~seconds:2;
  [%expect
    {|
    ((current_index 0) Running)
    ((current_index 0) Running)
    |}];
  (* Each click solves one game; the third finishes the run with the total
     time since [create]. *)
  advance ~input:click ~seconds:10;
  advance ~input:click ~seconds:20;
  advance ~input:click ~seconds:30;
  [%expect
    {|
    ((current_index 1) Running)
    ((current_index 2) Running)
    ((current_index 3) (Finished 30s))
    |}];
  print_s [%sexp (Game_runner.current runner : Mini_game.t option)];
  [%expect {| () |}]
;;

let%expect_test "elapsed_so_far measures from the start of the run" =
  let runner =
    Or_error.ok_exn
      (Game_runner.create
         ~pool:[ Mini_game.pack (module Click_to_solve) ]
         ~random:(Random.State.make [| 0 |])
         ~bounds
         ~now:(at ~seconds:100)
         ~count:1)
  in
  print_s
    [%sexp
      (Game_runner.elapsed_so_far runner ~now:(at ~seconds:107)
       : Time_ns.Span.t)];
  [%expect {| 7s |}]
;;

let%expect_test "create rejects an empty pool and a non-positive count" =
  let create ~pool ~count =
    print_s
      [%sexp
        (Game_runner.create
           ~pool
           ~random:(Random.State.make [| 0 |])
           ~bounds
           ~now:Time_ns.epoch
           ~count
         : Game_runner.t Or_error.t)]
  in
  create ~pool:[] ~count:10;
  [%expect {| (Error "Game_runner.create: empty mini-game pool") |}];
  create ~pool:[ Mini_game.pack (module Click_to_solve) ] ~count:0;
  [%expect
    {| (Error ("Game_runner.create: count must be positive" (count 0))) |}]
;;
