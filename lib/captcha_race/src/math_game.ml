open! Core

module Operator = struct
  type t =
    | Add
    | Subtract
    | Multiply
    | Divide
  [@@deriving sexp_of]

  let apply t ~left ~right =
    match t with
    | Add -> left + right
    | Subtract -> left - right
    | Multiply -> left * right
    | Divide -> left / right
  ;;

  (* The [Graphics] font is Latin-1, so "x" and "/" stand in for the
     multiplication and division signs. *)
  let symbol t =
    match t with
    | Add -> "+"
    | Subtract -> "-"
    | Multiply -> "x"
    | Divide -> "/"
  ;;
end

module Problem = struct
  type t =
    { left : int
    ; operator : Operator.t
    ; right : int
    }
  [@@deriving sexp_of]

  (* Derived rather than stored, so it cannot drift out of sync with the
     problem the player is looking at. *)
  let answer { left; operator; right } = Operator.apply operator ~left ~right

  let to_string { left; operator; right } =
    [%string "%{left#Int} %{Operator.symbol operator} %{right#Int} = ?"]
  ;;

  let min_answer = 1
  let max_answer = 20
  let max_factor = 10
  let max_subtrahend = 9
  let max_divisor = 9

  (* Keeps division to two digits over one: [96 / 6] is a fair thing to ask
     under time pressure, [171 / 9] is not. *)
  let max_dividend = 99

  (* Ways to write [answer] as a product of two factors in [2, max_factor],
     so a multiplication never degenerates into "1 x 17" or asks for an
     operand nobody knows the times table for. Empty for primes, which is why
     the operator is chosen after the answer. *)
  let factor_pairs answer =
    List.filter_map
      (List.range 2 max_factor ~stop:`inclusive)
      ~f:(fun left ->
        match answer % left = 0 with
        | false -> None
        | true ->
          let right = answer / left in
          (match right >= 2 && right <= max_factor with
           | true -> Some (left, right)
           | false -> None))
  ;;

  (* Pick the answer first, then work backwards to operands that produce it.
     That makes "the answer is in [1, 20]" true by construction instead of by
     a rejection loop, and keeps every operand a small positive int. *)
  let generate ~random =
    let answer = Random.State.int_incl random min_answer max_answer in
    let factors = factor_pairs answer in
    let operators =
      List.concat
        [ (* 1 is not the sum of two positive ints. *)
          (match answer >= 2 with true -> [ Operator.Add ] | false -> [])
        ; [ Operator.Subtract ]
        ; (match List.is_empty factors with
           | true -> []
           | false -> [ Operator.Multiply ])
        ; [ Operator.Divide ]
        ]
    in
    let operator = List.random_element_exn ~random_state:random operators in
    match operator with
    | Add ->
      let left = Random.State.int_incl random 1 (answer - 1) in
      { left; operator; right = answer - left }
    | Subtract ->
      let right = Random.State.int_incl random 1 max_subtrahend in
      { left = answer + right; operator; right }
    | Multiply ->
      let left, right =
        List.random_element_exn ~random_state:random factors
      in
      { left; operator; right }
    | Divide ->
      (* The mirror of [Multiply]: choose the divisor, then multiply up, so
         the division is always exact. Divisors that would push the dividend
         past two digits are dropped, and a divisor of 2 always survives:
         even the largest answer only makes a dividend of 40. *)
      let right =
        Random.State.int_incl
          random
          2
          (Int.min max_divisor (max_dividend / answer))
      in
      { left = answer * right; operator; right }
  ;;
end

module Phase = struct
  type t =
    | Solving_math of
        { typed : string
        ; wrong_attempts : int
        }
    | Clicking of
        { clicks_remaining : int
        ; fill_remaining : Time_ns.Span.t
        }
    | Solved
  [@@deriving sexp_of]
end

type t =
  { problem : Problem.t
  ; bounds : Geometry.Rect.t
  ; phase : Phase.t
  }
[@@deriving sexp_of]

let name = "math problem"

(* Every rect the game uses, as pure arithmetic on [bounds]: [update], [draw]
   and [For_testing] all derive their geometry from here, so what is drawn
   and what is clickable cannot disagree. Nothing here touches [Graphics]
   (not even [text_size]), which is what lets [update] and the tests run
   headless. *)
module Layout = struct
  let panel_w = 360
  let panel_h = 180

  let panel (bounds : Geometry.Rect.t) : Geometry.Rect.t =
    { x = bounds.x + ((bounds.w - panel_w) / 2)
    ; y = bounds.y + ((bounds.h - panel_h) / 2)
    ; w = panel_w
    ; h = panel_h
    }
  ;;

  let prompt_y bounds = (panel bounds).y + panel_h - 30
  let problem_y bounds = (panel bounds).y + 100
  let feedback_y bounds = (panel bounds).y + 20

  let input_box bounds : Geometry.Rect.t =
    let panel = panel bounds in
    { x = panel.x + 25; y = panel.y + 45; w = 180; h = 30 }
  ;;

  let enter_button bounds : Geometry.Rect.t =
    let panel = panel bounds in
    { x = panel.x + 225; y = panel.y + 45; w = 110; h = 30 }
  ;;

  (* Wide enough that the logo column on the right clears the "I'm not a
     robot" label on the left; the longest string in it is "Privacy - Terms". *)
  let box_w = 360
  let box_h = 76

  let box (bounds : Geometry.Rect.t) : Geometry.Rect.t =
    { x = bounds.x + ((bounds.w - box_w) / 2)
    ; y = bounds.y + ((bounds.h - box_h) / 2)
    ; w = box_w
    ; h = box_h
    }
  ;;

  let checkbox_size = 28

  let checkbox bounds : Geometry.Rect.t =
    let box = box bounds in
    { x = box.x + 20
    ; y = box.y + ((box_h - checkbox_size) / 2)
    ; w = checkbox_size
    ; h = checkbox_size
    }
  ;;
end

let create ~random ~bounds =
  { problem = Problem.generate ~random
  ; bounds
  ; phase = Solving_math { typed = ""; wrong_attempts = 0 }
  }
;;

let is_solved t =
  match t.phase with Solved -> true | Solving_math _ | Clicking _ -> false
;;

(* Answers run to 20, and a wrong guess is worth letting the player type in
   full, so two digits is the whole field. *)
let max_digits = 2

(* Long enough to see, short enough that it is gone before the next click. *)
let fill_duration = Time_ns.Span.of_int_ms 400

let apply_key typed key =
  match key with
  | '0' .. '9' when String.length typed < max_digits ->
    typed ^ String.of_char key
  (* X11 sends DEL for BackSpace on some setups. *)
  | '\b' | '\127' ->
    (match String.is_empty typed with
     | true -> typed
     | false -> String.drop_suffix typed 1)
  | _ -> typed
;;

let update_solving t ~typed ~wrong_attempts ~(input : Input.t) =
  (* Take the keystroke first, so a digit and a click on Enter landing in the
     same frame still submit that digit. *)
  let typed =
    match input.key with None -> typed | Some key -> apply_key typed key
  in
  let submitted =
    (input.mouse_clicked
     && Geometry.Rect.contains (Layout.enter_button t.bounds) input.mouse)
    ||
    match input.key with
    | Some ('\r' | '\n') -> true
    | Some (_ : char) | None -> false
  in
  let still_typing =
    { t with phase = Solving_math { typed; wrong_attempts } }
  in
  match submitted && not (String.is_empty typed) with
  | false -> still_typing
  | true ->
    (* [typed] holds nothing but digits, so this cannot raise. *)
    (match Int.of_string typed = Problem.answer t.problem with
     | true ->
       { t with
         phase =
           Clicking
             { clicks_remaining = Problem.answer t.problem
             ; fill_remaining = Time_ns.Span.zero
             }
       }
     | false ->
       { t with
         phase =
           Solving_math { typed = ""; wrong_attempts = wrong_attempts + 1 }
       })
;;

let update_clicking
  t
  ~clicks_remaining
  ~fill_remaining
  ~(input : Input.t)
  ~elapsed
  =
  let fill_remaining =
    Time_ns.Span.max
      Time_ns.Span.zero
      (Time_ns.Span.( - ) fill_remaining elapsed)
  in
  match
    input.mouse_clicked
    && Geometry.Rect.contains (Layout.checkbox t.bounds) input.mouse
  with
  | false -> { t with phase = Clicking { clicks_remaining; fill_remaining } }
  | true ->
    let clicks_remaining = clicks_remaining - 1 in
    (match clicks_remaining <= 0 with
     | true -> { t with phase = Solved }
     | false ->
       { t with
         phase =
           Clicking { clicks_remaining; fill_remaining = fill_duration }
       })
;;

let update t ~input ~elapsed =
  match t.phase with
  | Solved -> t
  | Solving_math { typed; wrong_attempts } ->
    update_solving t ~typed ~wrong_attempts ~input
  | Clicking { clicks_remaining; fill_remaining } ->
    update_clicking t ~clicks_remaining ~fill_remaining ~input ~elapsed
;;

let grey level = Graphics.rgb level level level

let fill_rect (rect : Geometry.Rect.t) ~color =
  Graphics.set_color color;
  Graphics.fill_rect rect.x rect.y rect.w rect.h
;;

let outline_rect (rect : Geometry.Rect.t) ~color =
  Graphics.set_color color;
  Graphics.draw_rect rect.x rect.y rect.w rect.h
;;

let draw_string_centered label ~x ~y =
  let text_w, (_ : int) = Graphics.text_size label in
  Graphics.moveto (x - (text_w / 2)) y;
  Graphics.draw_string label
;;

let draw_solving t ~typed ~wrong_attempts =
  let panel = Layout.panel t.bounds in
  let { Geometry.Point.x = center_x; y = (_ : int) } =
    Geometry.Rect.center panel
  in
  fill_rect panel ~color:(grey 245);
  outline_rect panel ~color:(grey 160);
  Graphics.set_color Graphics.black;
  draw_string_centered
    "Solve this to prove you are human"
    ~x:center_x
    ~y:(Layout.prompt_y t.bounds);
  (* Overdrawn a pixel to the right to fake a bold face: [Graphics.set_font]
     takes an X-specific font name and is not portable. *)
  let problem = Problem.to_string t.problem in
  let problem_y = Layout.problem_y t.bounds in
  draw_string_centered problem ~x:center_x ~y:problem_y;
  draw_string_centered problem ~x:(center_x + 1) ~y:problem_y;
  let input_box = Layout.input_box t.bounds in
  fill_rect input_box ~color:Graphics.white;
  outline_rect input_box ~color:(grey 120);
  Graphics.set_color Graphics.black;
  Graphics.moveto (input_box.x + 8) (input_box.y + 9);
  Graphics.draw_string [%string "%{typed}_"];
  let enter = Layout.enter_button t.bounds in
  fill_rect enter ~color:(grey 220);
  outline_rect enter ~color:Graphics.black;
  let { Geometry.Point.x = enter_x; y = enter_y } =
    Geometry.Rect.center enter
  in
  Graphics.set_color Graphics.black;
  draw_string_centered "Enter" ~x:enter_x ~y:(enter_y - 6);
  match wrong_attempts > 0 with
  | false -> ()
  | true ->
    Graphics.set_color Graphics.red;
    draw_string_centered
      "Try again"
      ~x:center_x
      ~y:(Layout.feedback_y t.bounds)
;;

(* A stand-in for the reCAPTCHA mark, stacked in the corner the real widget
   uses: swirl on top, brand beneath it, fine print at the bottom. The
   strings are right-aligned by measuring them rather than by assuming a
   character width — guessing overflowed the card. *)
let draw_logo (box : Geometry.Rect.t) =
  let right = box.x + box.w - 14 in
  let brand = "reCAPTCHA" in
  let fine_print = "Privacy - Terms" in
  let brand_w, (_ : int) = Graphics.text_size brand in
  let fine_print_w, (_ : int) = Graphics.text_size fine_print in
  let swirl_x = right - (brand_w / 2) in
  let swirl_y = box.y + 56 in
  Graphics.set_color (Graphics.rgb 28 58 169);
  Graphics.set_line_width 3;
  Graphics.draw_arc swirl_x swirl_y 11 11 30 300;
  Graphics.set_line_width 1;
  Graphics.fill_poly
    [| swirl_x + 7, swirl_y + 3
     ; swirl_x + 15, swirl_y + 7
     ; swirl_x + 5, swirl_y + 13
    |];
  Graphics.set_color (grey 120);
  Graphics.moveto (right - brand_w) (box.y + 26);
  Graphics.draw_string brand;
  Graphics.moveto (right - fine_print_w) (box.y + 10);
  Graphics.draw_string fine_print
;;

(* [is_filled] acknowledges the click that just landed. It says nothing about
   how many clicks are left: the count is the player's to remember. *)
let draw_recaptcha t ~is_filled =
  let box = Layout.box t.bounds in
  (* The whole card darkens for the life of the fill, like a button being
     held: far harder to miss mid-race than the check mark alone. *)
  let card_grey = match is_filled with true -> 228 | false -> 249 in
  fill_rect box ~color:(grey card_grey);
  outline_rect box ~color:(grey 211);
  let checkbox = Layout.checkbox t.bounds in
  fill_rect checkbox ~color:Graphics.white;
  outline_rect checkbox ~color:(grey 140);
  (match is_filled with
   | false -> ()
   | true ->
     let { Geometry.Point.x; y } = Geometry.Rect.center checkbox in
     Graphics.set_color (Graphics.rgb 66 133 244);
     Graphics.set_line_width 3;
     Graphics.moveto (x - 8) y;
     Graphics.lineto (x - 2) (y - 6);
     Graphics.lineto (x + 8) (y + 7);
     (* [set_line_width] is global [Graphics] state: left at 3 it would bleed
        into the HUD divider and the next game's [draw]. *)
     Graphics.set_line_width 1);
  Graphics.set_color Graphics.black;
  Graphics.moveto (checkbox.x + checkbox.w + 18) (box.y + 34);
  Graphics.draw_string "I'm not a robot";
  draw_logo box
;;

let draw t =
  match t.phase with
  | Solving_math { typed; wrong_attempts } ->
    draw_solving t ~typed ~wrong_attempts
  | Clicking { clicks_remaining = (_ : int); fill_remaining } ->
    draw_recaptcha
      t
      ~is_filled:(Time_ns.Span.( > ) fill_remaining Time_ns.Span.zero)
  (* Barely ever seen: the runner moves on the same frame the last click
     lands. Drawn filled so the final click looks like all the others. *)
  | Solved -> draw_recaptcha t ~is_filled:true
;;

module For_testing = struct
  let answer t = Problem.answer t.problem
  let problem t = Problem.to_string t.problem
  let operands t = t.problem.left, t.problem.right
  let enter_button t = Layout.enter_button t.bounds
  let checkbox t = Layout.checkbox t.bounds
end
