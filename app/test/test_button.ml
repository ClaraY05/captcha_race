open! Core
open Captcha_race
open Captcha_race_app

let%expect_test "Button.hit and hit_many" =
  let button label x action =
    { Button.label; rect = { x; y = 0; w = 10; h = 10 }; action }
  in
  let buttons = [ button "a" 0 "hit a"; button "b" 20 "hit b" ] in
  List.iter
    [ { Geometry.Point.x = 5; y = 5 }; { x = 25; y = 5 }; { x = 15; y = 5 } ]
    ~f:(fun point ->
      print_s [%sexp (Button.hit_many buttons point : string option)]);
  [%expect {|
    ("hit a")
    ("hit b")
    ()
    |}]
;;
