open! Core

let clear () =
  Graphics.set_color Graphics.white;
  Graphics.fill_rect 0 0 App_state.window_width App_state.window_height
;;

let draw_string_centered label ~x ~y =
  let text_w, (_ : int) = Graphics.text_size label in
  Graphics.moveto (x - (text_w / 2)) y;
  Graphics.draw_string label
;;

let draw_button (button : App_state.Action.t Button.t) =
  let { Geometry.Rect.x; y; w; h } = button.rect in
  Graphics.set_color (Graphics.rgb 230 230 230);
  Graphics.fill_rect x y w h;
  Graphics.set_color Graphics.black;
  Graphics.draw_rect x y w h;
  let text_w, text_h = Graphics.text_size button.label in
  Graphics.moveto (x + ((w - text_w) / 2)) (y + ((h - text_h) / 2));
  Graphics.draw_string button.label
;;

let center_x = App_state.window_width / 2

let draw_menu () =
  Graphics.set_color Graphics.black;
  draw_string_centered "CAPTCHA RACE" ~x:center_x ~y:450;
  draw_string_centered
    [%string
      "Solve %{App_state.games_per_run#Int} captchas as fast as you can"]
    ~x:center_x
    ~y:420
;;

let draw_leaderboard leaderboard =
  Graphics.set_color Graphics.black;
  draw_string_centered "LEADERBOARD - fastest runs" ~x:center_x ~y:520;
  match Leaderboard.entries leaderboard with
  | [] -> draw_string_centered "No completed runs yet" ~x:center_x ~y:480
  | entries ->
    List.iteri
      (List.take entries 10)
      ~f:(fun i (entry : Leaderboard.Entry.t) ->
        let label =
          [%string
            "%{i + 1#Int}. %{Time_ns.Span.to_string_hum ~decimals:2 \
             entry.completion_time}"]
        in
        draw_string_centered label ~x:center_x ~y:(480 - (i * 30)))
;;

let draw_playing runner ~now =
  (* HUD strip along the top, above [App_state.play_bounds]. *)
  let hud_y = App_state.window_height - 40 in
  Graphics.set_color Graphics.black;
  Graphics.moveto 10 hud_y;
  (match Game_runner.current runner with
   | None -> ()
   | Some game -> Graphics.draw_string (Mini_game.name game));
  Graphics.moveto 250 hud_y;
  Graphics.draw_string
    [%string
      "%{Game_runner.current_index runner + 1#Int}/%{Game_runner.count \
       runner#Int}"];
  Graphics.moveto 350 hud_y;
  Graphics.draw_string
    (Time_ns.Span.to_string_hum
       ~decimals:1
       (Game_runner.elapsed_so_far runner ~now));
  let { Geometry.Rect.x = _; y = _; w = _; h = play_h } =
    App_state.play_bounds
  in
  Graphics.moveto 0 play_h;
  Graphics.lineto App_state.window_width play_h;
  match Game_runner.current runner with
  | None -> ()
  | Some game -> Mini_game.draw game
;;

(* Drawn last so it rides on top of buttons and mini-games alike. *)
let draw_ripple ripple ~now =
  match Click_ripple.radius ripple ~now with
  | None -> ()
  | Some radius ->
    let { Geometry.Point.x; y } = Click_ripple.center ripple in
    (* Fade by thinning the ring as it grows, since [Graphics] has no alpha. *)
    let width =
      match radius * 2 <= Click_ripple.end_radius with
      | true -> 3
      | false -> 2
    in
    Graphics.set_color (Graphics.rgb 90 120 200);
    Graphics.set_line_width width;
    Graphics.draw_circle x y radius;
    Graphics.set_line_width 1
;;

let draw (model : App_state.Model.t) ~now =
  clear ();
  (match model.view with
   | Menu -> draw_menu ()
   | Leaderboard -> draw_leaderboard model.leaderboard
   | Playing runner -> draw_playing runner ~now);
  List.iter (App_state.buttons model.view) ~f:draw_button;
  match model.ripple with
  | None -> ()
  | Some ripple -> draw_ripple ripple ~now
;;
