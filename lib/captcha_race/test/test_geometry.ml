open! Core
open Captcha_race

let%expect_test "Rect.contains: inside, edges, corners, outside" =
  let rect = { Geometry.Rect.x = 10; y = 20; w = 100; h = 50 } in
  List.iter
    [ { Geometry.Point.x = 50; y = 40 } (* inside *)
    ; { x = 10; y = 20 } (* bottom-left corner *)
    ; { x = 110; y = 70 } (* top-right corner *)
    ; { x = 10; y = 45 } (* left edge *)
    ; { x = 9; y = 45 } (* just left of the left edge *)
    ; { x = 111; y = 45 } (* just right of the right edge *)
    ; { x = 50; y = 71 } (* just above the top edge *)
    ]
    ~f:(fun point ->
      print_s
        [%sexp
          (point : Geometry.Point.t)
          , (Geometry.Rect.contains rect point : bool)]);
  [%expect
    {|
    (((x 50) (y 40)) true)
    (((x 10) (y 20)) true)
    (((x 110) (y 70)) true)
    (((x 10) (y 45)) true)
    (((x 9) (y 45)) false)
    (((x 111) (y 45)) false)
    (((x 50) (y 71)) false)
    |}]
;;

let%expect_test "Rect.center" =
  print_s
    [%sexp
      (Geometry.Rect.center { x = 10; y = 20; w = 100; h = 50 }
       : Geometry.Point.t)];
  [%expect {| ((x 60) (y 45)) |}]
;;

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
