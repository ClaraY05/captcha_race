open! Core
open Captcha_race
open Captcha_race_engine

(* Palette — the design's colour tokens (see the Captcha Race style guide).
   Kept small and flat so the whole scene is solid fills the [Graphics]
   module can draw. *)
let c_wall = Graphics.rgb 44 43 47
let c_lip = Graphics.rgb 122 85 64
let c_desk = Graphics.rgb 95 66 48
let c_bezel = Graphics.rgb 202 191 168
let c_bezel_hi = Graphics.rgb 224 214 194
let c_bezel_lo = Graphics.rgb 154 142 119
let c_well = Graphics.rgb 23 19 31
let c_well_dark = Graphics.rgb 13 10 20
let c_well_light = Graphics.rgb 36 29 49
let c_screen = Graphics.rgb 47 51 59
let c_scanline = Graphics.rgb 40 44 51
let c_text = Graphics.rgb 215 219 225
let c_text_dim = Graphics.rgb 138 144 152
let c_text_faint = Graphics.rgb 127 133 141
let c_title_shadow = Graphics.rgb 27 30 35
let c_accent = Graphics.rgb 203 171 99
let c_accent_dim = Graphics.rgb 174 159 123
let c_shadow = Graphics.rgb 20 17 22
let c_card = Graphics.rgb 233 228 216
let c_card_shadow = Graphics.rgb 26 22 18
let c_ink = Graphics.rgb 38 36 31
let c_ghost = Graphics.rgb 60 64 72
let c_ghost_text = Graphics.rgb 223 227 233
let c_quit = Graphics.rgb 176 96 74
let c_quit_text = Graphics.rgb 244 236 224
let c_led = Graphics.rgb 126 224 164
let c_pip_cur = Graphics.rgb 223 227 233
let c_pip_todo = Graphics.rgb 61 65 73
let c_medal_gold = Graphics.rgb 216 182 79
let c_medal_silver = Graphics.rgb 196 201 208
let c_medal_bronze = Graphics.rgb 192 138 86
let c_row_a = Graphics.rgb 63 67 75
let c_row_b = Graphics.rgb 52 56 64

(* [Graphics]' default font is a fixed ~13px-tall bitmap face; treat its
   height as a constant for vertical centring. *)
let line_h = 13

let fill color ~x ~y ~w ~h =
  Graphics.set_color color;
  Graphics.fill_rect x y w h
;;

let text ~color ~x ~y s =
  Graphics.set_color color;
  Graphics.moveto x y;
  Graphics.draw_string s
;;

let text_centered ~color ~cx ~y s =
  let w, (_ : int) = Graphics.text_size s in
  text ~color ~x:(cx - (w / 2)) ~y s
;;

let text_right ~color ~right ~y s =
  let w, (_ : int) = Graphics.text_size s in
  text ~color ~x:(right - w) ~y s
;;

(* A hard 2px drop shadow: the flat-pixel echo of the design's [text-shadow]. *)
let text_shadow ~color ~x ~y s =
  text ~color:c_title_shadow ~x:(x + 2) ~y:(y - 2) s;
  text ~color ~x ~y s
;;

let text_centered_shadow ~color ~cx ~y s =
  let w, (_ : int) = Graphics.text_size s in
  text_shadow ~color ~x:(cx - (w / 2)) ~y s
;;

(* A raised beige panel: light along the top-left, shade along the
   bottom-right — the flat stand-in for the design's inset box-shadow bevels. *)
let bevel_raised ~x ~y ~w ~h ~t =
  fill c_bezel ~x ~y ~w ~h;
  fill c_bezel_hi ~x ~y:(y + h - t) ~w ~h:t;
  fill c_bezel_hi ~x ~y ~w:t ~h;
  fill c_bezel_lo ~x ~y ~w ~h:t;
  fill c_bezel_lo ~x:(x + w - t) ~y ~w:t ~h
;;

(* A recessed dark well: the inverse bevel — dark top-left, light
   bottom-right — so the screen reads as sunk into the bezel. *)
let bevel_inset ~x ~y ~w ~h ~t =
  fill c_well ~x ~y ~w ~h;
  fill c_well_light ~x ~y ~w ~h:t;
  fill c_well_light ~x:(x + w - t) ~y ~w:t ~h;
  fill c_well_dark ~x ~y:(y + h - t) ~w ~h:t;
  fill c_well_dark ~x ~y ~w:t ~h
;;

let button_colors (action : App_state.Action.t) =
  match action with
  | Play -> c_accent, c_ink
  | View_leaderboard | Back_to_menu -> c_ghost, c_ghost_text
  | Quit_run -> c_quit, c_quit_text
;;

let draw_button (button : App_state.Action.t Button.t) =
  let { Geometry.Rect.x; y; w; h } = button.rect in
  let bg, fg = button_colors button.action in
  fill c_shadow ~x:(x + 3) ~y:(y - 3) ~w ~h;
  fill bg ~x ~y ~w ~h;
  text_centered
    ~color:fg
    ~cx:(x + (w / 2))
    ~y:(y + ((h - line_h) / 2))
    button.label
;;

let draw_background () =
  fill
    c_wall
    ~x:0
    ~y:224
    ~w:Layout.window_width
    ~h:(Layout.window_height - 224);
  fill c_desk ~x:0 ~y:0 ~w:Layout.window_width ~h:220;
  fill c_lip ~x:0 ~y:220 ~w:Layout.window_width ~h:4
;;

let draw_stand () =
  fill c_bezel ~x:300 ~y:120 ~w:200 ~h:14;
  fill c_bezel_lo ~x:300 ~y:120 ~w:200 ~h:4;
  fill c_bezel ~x:372 ~y:132 ~w:56 ~h:20;
  fill c_bezel_lo ~x:418 ~y:132 ~w:10 ~h:20
;;

let draw_scanlines () =
  let { Geometry.Rect.x; y; w; h } = Layout.screen in
  Graphics.set_color c_scanline;
  let yy = ref y in
  while !yy < y + h do
    Graphics.fill_rect x !yy w 1;
    yy := !yy + 3
  done
;;

let draw_monitor () =
  bevel_raised ~x:100 ~y:150 ~w:600 ~h:410 ~t:6;
  bevel_inset ~x:122 ~y:172 ~w:556 ~h:366 ~t:5;
  let { Geometry.Rect.x; y; w; h } = Layout.screen in
  fill c_screen ~x ~y ~w ~h;
  draw_scanlines ();
  (* chin: model badge + power LED *)
  text ~color:c_bezel_lo ~x:132 ~y:154 "PIXL-9000";
  fill c_led ~x:636 ~y:154 ~w:9 ~h:9;
  text ~color:c_bezel_lo ~x:650 ~y:154 "PWR"
;;

let best_label (model : App_state.Model.t) =
  match Leaderboard.best model.leaderboard with
  | None -> "--"
  | Some entry ->
    Time_ns.Span.to_string_hum ~decimals:2 entry.completion_time
;;

let draw_menu (model : App_state.Model.t) =
  let cx = 400 in
  text_centered ~color:c_accent_dim ~cx ~y:490 "* SINGLE PLAYER *";
  text_centered_shadow ~color:c_text ~cx ~y:452 "CAPTCHA RACE";
  text_centered
    ~color:c_text_dim
    ~cx
    ~y:425
    "prove you're not a robot - fast.";
  text_centered
    ~color:c_text_faint
    ~cx
    ~y:245
    [%string "10 captchas - best time %{best_label model}"]
;;

let draw_hud_round ~round ~count =
  let x = 150 in
  let y = 502 in
  text ~color:c_text_dim ~x ~y "ROUND ";
  let w, (_ : int) = Graphics.text_size "ROUND " in
  let n = Int.to_string round in
  text ~color:c_accent ~x:(x + w) ~y n;
  let wn, (_ : int) = Graphics.text_size n in
  text ~color:c_text_dim ~x:(x + w + wn) ~y [%string "/%{count#Int}"]
;;

let draw_pips ~current ~count =
  let x0 = 150 in
  let y = 478 in
  let pip_w = 46 in
  let gap = 4 in
  for i = 0 to count - 1 do
    let color =
      match () with
      | () when i < current -> c_accent
      | () when i = current -> c_pip_cur
      | () -> c_pip_todo
    in
    fill color ~x:(x0 + (i * (pip_w + gap))) ~y ~w:pip_w ~h:7
  done
;;

let draw_card runner =
  let { Geometry.Rect.x = bx; y = by; w = bw; h = bh } =
    Layout.play_bounds
  in
  let pad = 16 in
  let header_h = 28 in
  let x = bx - pad in
  let w = bw + (2 * pad) in
  let y = by - pad in
  let h = bh + (2 * pad) + header_h in
  fill c_card_shadow ~x:(x + 4) ~y:(y - 4) ~w ~h;
  fill c_card ~x ~y ~w ~h;
  let hy = y + h - header_h in
  fill c_accent ~x ~y:hy ~w ~h:header_h;
  let ty = hy + ((header_h - line_h) / 2) in
  match Game_runner.current runner with
  | None -> ()
  | Some game ->
    text
      ~color:c_ink
      ~x:(x + 12)
      ~y:ty
      (String.uppercase (Mini_game.name game));
    text_right ~color:c_ink ~right:(x + w - 12) ~y:ty "v2.captcha";
    Mini_game.draw game
;;

let draw_playing runner ~now =
  let count = Game_runner.count runner in
  let current = Game_runner.current_index runner in
  draw_hud_round ~round:(Int.min (current + 1) count) ~count;
  let secs =
    Time_ns.Span.to_string_hum
      ~decimals:1
      (Game_runner.elapsed_so_far runner ~now)
  in
  text_centered ~color:c_accent ~cx:400 ~y:500 [%string "TIME %{secs}"];
  draw_pips ~current ~count;
  draw_card runner
;;

let draw_leaderboard (model : App_state.Model.t) =
  text_shadow ~color:c_accent ~x:160 ~y:495 "* LEADERBOARD";
  text_right ~color:c_text_faint ~right:640 ~y:497 "fastest 10-captcha runs";
  match Leaderboard.entries model.leaderboard with
  | [] ->
    text_centered ~color:c_text_dim ~cx:400 ~y:360 "No completed runs yet"
  | entries ->
    List.iteri
      (List.take entries 6)
      ~f:(fun i (entry : Leaderboard.Entry.t) ->
        let ry = 458 - (i * 32) in
        fill
          (if i % 2 = 0 then c_row_a else c_row_b)
          ~x:160
          ~y:ry
          ~w:480
          ~h:26;
        let medal =
          match i with
          | 0 -> c_medal_gold
          | 1 -> c_medal_silver
          | 2 -> c_medal_bronze
          | _ -> c_text_faint
        in
        let strong = i < 3 in
        text ~color:medal ~x:172 ~y:(ry + 7) [%string "#%{i + 1#Int}"];
        text
          ~color:(if strong then c_text else c_text_dim)
          ~x:220
          ~y:(ry + 7)
          "10-captcha run";
        text_right
          ~color:(if strong then c_text else c_text_dim)
          ~right:628
          ~y:(ry + 7)
          (Time_ns.Span.to_string_hum ~decimals:2 entry.completion_time))
;;

let draw (model : App_state.Model.t) ~now =
  draw_background ();
  draw_stand ();
  draw_monitor ();
  (match model.view with
   | Menu -> draw_menu model
   | Leaderboard -> draw_leaderboard model
   | Playing runner -> draw_playing runner ~now);
  List.iter (App_state.buttons model.view) ~f:draw_button
;;
