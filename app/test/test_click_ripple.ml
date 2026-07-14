open! Core
open Captcha_race
open Captcha_race_app

let start = Time_ns.epoch
let at_ms ms = Time_ns.add start (Time_ns.Span.of_int_ms ms)
let center = { Geometry.Point.x = 100; y = 200 }
let create () = Click_ripple.create ~center ~now:start

let%expect_test "the ring grows from a dot and then disappears" =
  let ripple = create () in
  List.iter [ 0; 55; 110; 219; 220; 500 ] ~f:(fun ms ->
    let radius = Click_ripple.radius ripple ~now:(at_ms ms) in
    print_s [%message "" ~age_ms:(ms : int) (radius : int option)]);
  [%expect
    {|
    ((age_ms 0) (radius (4)))
    ((age_ms 55) (radius (9)))
    ((age_ms 110) (radius (13)))
    ((age_ms 219) (radius (22)))
    ((age_ms 220) (radius ()))
    ((age_ms 500) (radius ()))
    |}]
;;

let%expect_test "the ring is centered on the click" =
  let ripple = create () in
  print_s [%sexp (Click_ripple.center ripple : Geometry.Point.t)];
  [%expect {| ((x 100) (y 200)) |}]
;;

(* [Render] asks for a radius on every frame, including frames drawn before
   the ripple was created (the model carries the previous one). *)
let%expect_test "a ripple from the future is not drawn" =
  let ripple = Click_ripple.create ~center ~now:(at_ms 500) in
  let radius = Click_ripple.radius ripple ~now:start in
  print_s [%sexp (radius : int option)];
  [%expect {| () |}]
;;
