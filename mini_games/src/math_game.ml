open! Core
open Captcha_race

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

module Term = struct
  (* The multiplicative half of a problem. It binds tighter than the [+]/[-]
     around it, and that precedence is the whole point: [20 - 3 x 5] comes to
     5, not to 85. A single-operator problem could not ask that. *)
  type t =
    { left : int
    ; operator : Operator.t
    ; right : int
    }
  [@@deriving sexp_of]

  let value { left; operator; right } = Operator.apply operator ~left ~right

  let to_string { left; operator; right } =
    [%string "%{left#Int} %{Operator.symbol operator} %{right#Int}"]
  ;;

  let min_factor = 2
  let max_factor = 9

  (* Keeps [number - term] (the widest case) to two digits. *)
  let max_value = 60

  (* Every tidy [b x c] and [b / c]: factors in [2, 9] so both stay inside
     the times table, division exact by construction, and no product so large
     that the [+]/[-] step needs a three-digit number. Enumerated once, at
     module init, rather than sampled and rejected. *)
  let all =
    let factors = List.range min_factor max_factor ~stop:`inclusive in
    let products =
      List.concat_map factors ~f:(fun left ->
        List.filter_map factors ~f:(fun right ->
          match left * right <= max_value with
          | false -> None
          | true -> Some { left; operator = Operator.Multiply; right }))
    in
    (* Built from the quotient outwards, so the division always comes out
       even: [quotient * divisor / divisor]. *)
    let quotients =
      List.concat_map factors ~f:(fun quotient ->
        List.map factors ~f:(fun divisor ->
          { left = quotient * divisor
          ; operator = Operator.Divide
          ; right = divisor
          }))
    in
    products @ quotients
  ;;
end

module Problem = struct
  module Shape = struct
    (* Where the loose number sits relative to the term. Both orders appear
       so the player cannot just evaluate left to right and be right by luck. *)
    type t =
      | Term_first (* 7 x 3 - 6 *)
      | Number_first (* 20 - 3 x 5 *)
    [@@deriving sexp_of]
  end

  type t =
    { term : Term.t
    ; add_operator : Operator.t (* always [Add] or [Subtract] *)
    ; number : int
    ; shape : Shape.t
    }
  [@@deriving sexp_of]

  (* Derived rather than stored, so it cannot drift out of sync with the
     problem the player is looking at. Mirrors the precedence the player is
     expected to apply: the term resolves first. *)
  let answer { term; add_operator; number; shape } =
    let term = Term.value term in
    match shape with
    | Term_first -> Operator.apply add_operator ~left:term ~right:number
    | Number_first -> Operator.apply add_operator ~left:number ~right:term
  ;;

  let to_string { term; add_operator; number; shape } =
    let term = Term.to_string term in
    let symbol = Operator.symbol add_operator in
    match shape with
    | Term_first -> [%string "%{term} %{symbol} %{number#Int} = ?"]
    | Number_first -> [%string "%{number#Int} %{symbol} %{term} = ?"]
  ;;

  let min_answer = 1
  let max_answer = 20
  let max_number = 99

  (* Every two-step problem that evaluates to [answer], built by construction
     rather than by guessing and retrying: for each term, solve the [+]/[-]
     step for the one number that lands on [answer], and keep it if that
     number is a sane positive int.

     Never empty — [number - term] is always available, since
     [answer + Term.max_value] can never exceed [max_number]. *)
  let candidates ~answer =
    List.concat_map Term.all ~f:(fun term ->
      let value = Term.value term in
      let sum = answer - value in
      let difference = value - answer in
      let minuend = answer + value in
      List.filter_opt
        [ (* term + number *)
          (match sum >= 1 with
           | false -> None
           | true ->
             Some
               { term
               ; add_operator = Operator.Add
               ; number = sum
               ; shape = Shape.Term_first
               })
        ; (* number + term *)
          (match sum >= 1 with
           | false -> None
           | true ->
             Some
               { term
               ; add_operator = Operator.Add
               ; number = sum
               ; shape = Shape.Number_first
               })
        ; (* term - number *)
          (match difference >= 1 with
           | false -> None
           | true ->
             Some
               { term
               ; add_operator = Operator.Subtract
               ; number = difference
               ; shape = Shape.Term_first
               })
        ; (* number - term *)
          (match minuend <= max_number with
           | false -> None
           | true ->
             Some
               { term
               ; add_operator = Operator.Subtract
               ; number = minuend
               ; shape = Shape.Number_first
               })
        ])
  ;;

  (* Pick the answer first, then a problem that reaches it. That makes "the
     answer is in [1, 20]" true by construction — which matters for more than
     the arithmetic, since the answer is also how many times the player has
     to click the checkbox in phase two. *)
  let generate ~random =
    let answer = Random.State.int_incl random min_answer max_answer in
    List.random_element_exn ~random_state:random (candidates ~answer)
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
   headless.

   [bounds] is {!Captcha_race_engine.Layout.play_bounds} — the interior of
   the captcha card {!Captcha_race_app.Render} draws, which is short (152px)
   and wide, so everything here is laid out in a single centred column with
   the field and its button side by side. *)
module Layout = struct
  let input_w = 170
  let button_w = 100
  let field_h = 30
  let field_gap = 14

  (* The field and the [Enter] button, centred as a pair. *)
  let field_left (bounds : Geometry.Rect.t) =
    bounds.x + ((bounds.w - (input_w + field_gap + button_w)) / 2)
  ;;

  let prompt_y (bounds : Geometry.Rect.t) = bounds.y + bounds.h - 22
  let problem_y (bounds : Geometry.Rect.t) = bounds.y + 88
  let feedback_y (bounds : Geometry.Rect.t) = bounds.y + 10

  let input_box (bounds : Geometry.Rect.t) : Geometry.Rect.t =
    { x = field_left bounds; y = bounds.y + 34; w = input_w; h = field_h }
  ;;

  let enter_button (bounds : Geometry.Rect.t) : Geometry.Rect.t =
    { x = field_left bounds + input_w + field_gap
    ; y = bounds.y + 34
    ; w = button_w
    ; h = field_h
    }
  ;;

  (* Wide enough that the logo column on the right clears the "I'm not a
     robot" label on the left; the longest string in it is "Privacy - Terms". *)
  let box_w = 356
  let box_h = 80

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

(* A blink, not a state: the check must be gone well before the next click
   lands, so a fast run reads as a string of distinct flashes rather than one
   long fill. Two rendered frames is enough to be seen. *)
let fill_duration = Time_ns.Span.of_int_ms 100

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

(* Palette — the captcha card's tokens, matching [Placeholder_game] and the
   card {!Captcha_race_app.Render} draws underneath: dark ink on a warm beige
   card, with a gold accent. The game draws {e on} that card, so it paints no
   background of its own. *)
let c_ink = Graphics.rgb 38 36 31
let c_ink_dim = Graphics.rgb 120 113 98
let c_accent = Graphics.rgb 203 171 99
let c_field = Graphics.rgb 217 212 200
let c_field_shade = Graphics.rgb 195 188 171
let c_widget = Graphics.rgb 243 240 232
let c_widget_pressed = Graphics.rgb 214 208 194
let c_shadow = Graphics.rgb 20 17 22
let c_error = Graphics.rgb 176 96 74
let line_h = 13

let fill_rect (rect : Geometry.Rect.t) ~color =
  Graphics.set_color color;
  Graphics.fill_rect rect.x rect.y rect.w rect.h
;;

let outline_rect (rect : Geometry.Rect.t) ~color =
  Graphics.set_color color;
  Graphics.draw_rect rect.x rect.y rect.w rect.h
;;

(* A recessed field: flat fill with a hard shade along the top-left, the
   flat-pixel stand-in for an inset shadow. *)
let sunken_rect (rect : Geometry.Rect.t) ~color =
  fill_rect rect ~color;
  Graphics.set_color c_field_shade;
  Graphics.fill_rect rect.x (rect.y + rect.h - 3) rect.w 3;
  Graphics.fill_rect rect.x rect.y 3 rect.h
;;

let draw_string_centered label ~x ~y ~color =
  let text_w, (_ : int) = Graphics.text_size label in
  Graphics.set_color color;
  Graphics.moveto (x - (text_w / 2)) y;
  Graphics.draw_string label
;;

let center_x (bounds : Geometry.Rect.t) = bounds.x + (bounds.w / 2)

let draw_solving t ~typed ~wrong_attempts =
  let cx = center_x t.bounds in
  draw_string_centered
    "Solve this to prove you are human"
    ~x:cx
    ~y:(Layout.prompt_y t.bounds)
    ~color:c_ink_dim;
  (* Overdrawn a pixel to the right to fake a bold face: [Graphics.set_font]
     takes an X-specific font name and is not portable. *)
  let problem = Problem.to_string t.problem in
  let problem_y = Layout.problem_y t.bounds in
  draw_string_centered problem ~x:cx ~y:problem_y ~color:c_ink;
  draw_string_centered problem ~x:(cx + 1) ~y:problem_y ~color:c_ink;
  let input_box = Layout.input_box t.bounds in
  sunken_rect input_box ~color:c_field;
  Graphics.set_color c_ink;
  Graphics.moveto (input_box.x + 10) (input_box.y + ((30 - line_h) / 2));
  Graphics.draw_string [%string "%{typed}_"];
  (* The [Enter] button echoes the accent buttons [Render] draws, hard drop
     shadow and all. *)
  let enter = Layout.enter_button t.bounds in
  fill_rect { enter with x = enter.x + 3; y = enter.y - 3 } ~color:c_shadow;
  fill_rect enter ~color:c_accent;
  draw_string_centered
    "ENTER"
    ~x:(enter.x + (enter.w / 2))
    ~y:(enter.y + ((enter.h - line_h) / 2))
    ~color:c_ink;
  match wrong_attempts > 0 with
  | false -> ()
  | true ->
    draw_string_centered
      "Try again"
      ~x:cx
      ~y:(Layout.feedback_y t.bounds)
      ~color:c_error
;;

(* A stand-in for the reCAPTCHA mark, stacked in the corner the real widget
   uses: swirl on top, brand beneath it, fine print at the bottom. The
   strings are right-aligned by measuring them rather than by assuming a
   character width — guessing overflowed the widget. *)
let draw_logo (box : Geometry.Rect.t) =
  let right = box.x + box.w - 14 in
  let brand = "reCAPTCHA" in
  let fine_print = "Privacy - Terms" in
  let brand_w, (_ : int) = Graphics.text_size brand in
  let fine_print_w, (_ : int) = Graphics.text_size fine_print in
  let swirl_x = right - (brand_w / 2) in
  let swirl_y = box.y + 56 in
  Graphics.set_color c_accent;
  Graphics.set_line_width 3;
  Graphics.draw_arc swirl_x swirl_y 11 11 30 300;
  Graphics.set_line_width 1;
  Graphics.fill_poly
    [| swirl_x + 7, swirl_y + 3
     ; swirl_x + 15, swirl_y + 7
     ; swirl_x + 5, swirl_y + 13
    |];
  Graphics.set_color c_ink_dim;
  Graphics.moveto (right - brand_w) (box.y + 26);
  Graphics.draw_string brand;
  Graphics.moveto (right - fine_print_w) (box.y + 10);
  Graphics.draw_string fine_print
;;

(* [is_filled] acknowledges the click that just landed. It says nothing about
   how many clicks are left: the count is the player's to remember. *)
let draw_recaptcha t ~is_filled =
  let box = Layout.box t.bounds in
  (* The whole widget presses in for the life of the fill, like a button
     being held: far harder to miss mid-race than the check mark alone. *)
  let widget_color =
    match is_filled with true -> c_widget_pressed | false -> c_widget
  in
  fill_rect box ~color:widget_color;
  outline_rect box ~color:c_field_shade;
  let checkbox = Layout.checkbox t.bounds in
  (match is_filled with
   | false -> sunken_rect checkbox ~color:c_widget
   | true ->
     fill_rect checkbox ~color:c_accent;
     let { Geometry.Point.x; y } = Geometry.Rect.center checkbox in
     Graphics.set_color c_ink;
     Graphics.set_line_width 3;
     Graphics.moveto (x - 8) y;
     Graphics.lineto (x - 2) (y - 6);
     Graphics.lineto (x + 8) (y + 7);
     (* [set_line_width] is global [Graphics] state: left at 3 it would bleed
        into whatever draws next. *)
     Graphics.set_line_width 1);
  outline_rect checkbox ~color:c_ink;
  Graphics.set_color c_ink;
  Graphics.moveto
    (checkbox.x + checkbox.w + 18)
    (box.y + ((box.h - line_h) / 2));
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

  let numbers t =
    let { Problem.term; add_operator = (_ : Operator.t); number; shape } =
      t.problem
    in
    match shape with
    | Term_first -> [ term.left; term.right; number ]
    | Number_first -> [ number; term.left; term.right ]
  ;;

  let division t =
    let { Term.left; operator; right } = t.problem.term in
    match operator with
    | Divide -> Some (left, right)
    | Add | Subtract | Multiply -> None
  ;;

  let enter_button t = Layout.enter_button t.bounds
  let checkbox t = Layout.checkbox t.bounds
end
