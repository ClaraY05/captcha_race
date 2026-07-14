open! Core
open Captcha_race_engine

let entry ~seconds =
  { Leaderboard.Entry.completion_time = Time_ns.Span.of_int_sec seconds
  ; achieved_at = Time_ns.epoch
  }
;;

let%expect_test "entries stay sorted fastest-first regardless of add order" =
  let leaderboard =
    List.fold [ 50; 30; 40 ] ~init:Leaderboard.empty ~f:(fun acc seconds ->
      Leaderboard.add acc (entry ~seconds))
  in
  List.iter (Leaderboard.entries leaderboard) ~f:(fun entry ->
    print_s [%sexp (entry.completion_time : Time_ns.Span.t)]);
  [%expect {|
    30s
    40s
    50s
    |}];
  print_s
    [%sexp
      (Option.map (Leaderboard.best leaderboard) ~f:(fun entry ->
         entry.completion_time)
       : Time_ns.Span.t option)];
  [%expect {| (30s) |}]
;;

let%expect_test "best of an empty leaderboard" =
  print_s
    [%sexp (Leaderboard.best Leaderboard.empty : Leaderboard.Entry.t option)];
  [%expect {| () |}]
;;

let%expect_test "sexp round-trip re-sorts (the file is human-editable)" =
  let leaderboard =
    List.fold [ 30; 50 ] ~init:Leaderboard.empty ~f:(fun acc seconds ->
      Leaderboard.add acc (entry ~seconds))
  in
  let sexp = [%sexp (leaderboard : Leaderboard.t)] in
  print_s sexp;
  [%expect
    {|
    (((completion_time 30s) (achieved_at "1970-01-01 00:00:00Z"))
     ((completion_time 50s) (achieved_at "1970-01-01 00:00:00Z")))
    |}];
  (* A hand-edited, out-of-order file comes back sorted. *)
  let shuffled =
    Sexp.of_string
      {| (((completion_time 50s) (achieved_at "1970-01-01 00:00:00Z"))
          ((completion_time 30s) (achieved_at "1970-01-01 00:00:00Z"))) |}
  in
  List.iter
    (Leaderboard.entries (Leaderboard.t_of_sexp shuffled))
    ~f:(fun entry ->
      print_s [%sexp (entry.completion_time : Time_ns.Span.t)]);
  [%expect {|
    30s
    50s
    |}]
;;

let%expect_test "save then load round-trips; missing file loads as empty" =
  let path = Filename_unix.temp_file "captcha_race_test" "scores.sexp" in
  let leaderboard = Leaderboard.add Leaderboard.empty (entry ~seconds:42) in
  Or_error.ok_exn (Leaderboard.save leaderboard ~path);
  let loaded = Or_error.ok_exn (Leaderboard.load ~path) in
  print_s [%sexp (loaded : Leaderboard.t)];
  [%expect
    {| (((completion_time 42s) (achieved_at "1970-01-01 00:00:00Z"))) |}];
  Sys_unix.remove path;
  let missing = Or_error.ok_exn (Leaderboard.load ~path) in
  print_s [%sexp (missing : Leaderboard.t)];
  [%expect {| () |}]
;;
