open! Core
open Captcha_race_engine

(* Render [s] at scale 1 into ASCII art so the bitmap is legible in the
   expect output. The font's origin is bottom-left, so rows are flipped for
   printing (top row first). *)
let show s =
  let scale = 1 in
  let w = Int.max (Pixel_font.width s ~scale) 1 in
  let h = Pixel_font.cell_h in
  let grid = Array.make_matrix ~dimx:h ~dimy:w '.' in
  Pixel_font.foreach_pixel
    s
    ~scale
    ~x:0
    ~y:0
    ~f:(fun ~x ~y ~size:(_ : int) -> grid.(h - 1 - y).(x) <- '#');
  Array.iter grid ~f:(fun row ->
    print_endline (String.of_char_list (Array.to_list row)))
;;

let%expect_test "letters render as pixel bitmaps" =
  show "HI";
  [%expect
    {|
    #...#.#####
    #...#...#..
    #...#...#..
    #####...#..
    #...#...#..
    #...#...#..
    #...#.#####
    |}]
;;

let%expect_test "unknown characters render as blank space" =
  show "A~A";
  [%expect
    {|
    .###.........###.
    #...#.......#...#
    #...#.......#...#
    #####.......#####
    #...#.......#...#
    #...#.......#...#
    #...#.......#...#
    |}]
;;

let%expect_test "width scales and includes one inter-character gap" =
  List.iter
    [ "", 1; "A", 1; "AB", 1; "CAPTCHA RACE", 4 ]
    ~f:(fun (s, scale) ->
      print_s [%message s ~width:(Pixel_font.width s ~scale : int)]);
  [%expect
    {|
    ("" (width 0))
    (A (width 5))
    (AB (width 11))
    ("CAPTCHA RACE" (width 284))
    |}]
;;
