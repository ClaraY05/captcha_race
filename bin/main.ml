(** Captcha Race entry point: owns the window and the event loop.

    Run with: dune exec bin/main.exe (needs a graphical display).

    The loop is a non-blocking poll rather than a blocking [wait_next_event],
    so that animated mini-games keep moving between input events. Input and
    rendering run at different rates: input is polled every {!poll_interval}
    (~1ms) and each poll immediately produces an {!Captcha_race.Input.t} and
    runs the pure transitions in {!Captcha_race_app.App_state}, while
    {!Captcha_race_app.Render} draws only every {!frame_duration} (~60fps).

    Polling far faster than we draw is what makes fast clicking work. The
    [Graphics] poll reports whether the button is down {e right now} — clicks
    are not queued — so a click is only seen if a poll happens to land
    between the press and the release. At one poll per rendered frame, a
    press and release inside the same 16ms would leave no trace at all, and a
    player racing through a game that counts clicks would silently lose them.
    A human click holds the button for tens of milliseconds, so sampling
    every millisecond catches every one, and acts on it within a millisecond
    rather than up to a frame later. Drawing is the expensive part, and it
    stays at 60fps.

    This file (plus [Render] and each game's [draw]) is the only place
    [Graphics] is touched; everything else is display-free and covered by
    expect tests. To add a mini-game, implement
    {!Captcha_race_engine.Mini_game_intf.S} in the [captcha_race.mini_games]
    library and add it to [pool] below. *)

open! Core
open Captcha_race
open Captcha_race_engine
open Captcha_race_app
open Captcha_race_mini_games

(* The mini-games a race can be built from. Register new games here. *)
let pool =
  [ Mini_game.pack (module Placeholder_game)
  ; Mini_game.pack (module Math_game)
  ; Mini_game.pack (module Moving_puzzle)
  ]
;;

let leaderboard_path =
  match Sys.getenv "HOME" with
  | Some home -> home ^/ ".captcha_race_scores.sexp"
  | None -> ".captcha_race_scores.sexp"
;;

(* How often the screen is redrawn: ~60fps. *)
let frame_duration = Time_ns.Span.of_int_ms 16

(* How often the mouse and keyboard are sampled. Far shorter than
   [frame_duration] so that no click falls between two polls; see the header
   comment. *)
let poll_interval = Time_ns.Span.of_int_ms 1

let load_leaderboard () =
  match Leaderboard.load ~path:leaderboard_path with
  | Ok leaderboard -> leaderboard
  | Error error ->
    eprint_s
      [%message
        "failed to load leaderboard; starting empty" (error : Error.t)];
    Leaderboard.empty
;;

let save_leaderboard leaderboard =
  match Leaderboard.save leaderboard ~path:leaderboard_path with
  | Ok () -> ()
  | Error error ->
    eprint_s [%message "failed to save leaderboard" (error : Error.t)]
;;

let poll_input ~prev_mouse_down =
  let status = Graphics.wait_next_event [ Poll ] in
  let key =
    match Graphics.key_pressed () with
    | true -> Some (Graphics.read_key ())
    | false -> None
  in
  { Input.mouse = { x = status.mouse_x; y = status.mouse_y }
  ; mouse_down = status.button
  ; mouse_clicked = status.button && not prev_mouse_down
  ; key
  }
;;

let step (model : App_state.Model.t) ~input ~random ~now ~elapsed =
  let model = App_state.record_click model ~input ~now in
  match
    ( input.Input.mouse_clicked
    , Button.hit_many (App_state.buttons model.view) input.Input.mouse )
  with
  | true, Some action ->
    ok_exn (App_state.apply_action model action ~pool ~random ~now)
  | true, None | false, (_ : App_state.Action.t option) ->
    App_state.advance model ~input ~now ~elapsed
;;

let () =
  (match
     Graphics.open_graph
       [%string " %{Layout.window_width#Int}x%{Layout.window_height#Int}"]
   with
   | () -> ()
   | exception Graphics.Graphic_failure message ->
     eprint_s
       [%message "Captcha Race needs a graphical display" (message : string)];
     exit 1);
  Graphics.set_window_title "Captcha Race";
  Graphics.auto_synchronize false;
  let random = Random.State.make_self_init () in
  let model =
    ref
      { App_state.Model.view = Menu
      ; leaderboard = load_leaderboard ()
      ; ripple = None
      }
  in
  let prev_mouse_down = ref false in
  let prev_poll = ref (Time_ns.now ()) in
  let next_frame = ref (Time_ns.now ()) in
  (* The loop ends when the player closes the window, which surfaces as
     [Graphic_failure]. *)
  try
    while true do
      let input = poll_input ~prev_mouse_down:!prev_mouse_down in
      prev_mouse_down := input.mouse_down;
      let now = Time_ns.now () in
      let elapsed = Time_ns.diff now !prev_poll in
      prev_poll := now;
      let previous = !model in
      (* Every poll steps the model, so a click takes effect on the poll that
         sees it — not at the next frame boundary. *)
      let next = step previous ~input ~random ~now ~elapsed in
      if not (phys_equal next.leaderboard previous.leaderboard)
      then save_leaderboard next.leaderboard;
      model := next;
      (match Time_ns.( >= ) now !next_frame with
       | false -> ()
       | true ->
         Render.draw next ~now;
         Graphics.synchronize ();
         next_frame := Time_ns.add now frame_duration);
      ignore
        (Core_unix.nanosleep (Time_ns.Span.to_sec poll_interval) : float)
    done
  with
  | Graphics.Graphic_failure (_ : string) -> ()
;;
