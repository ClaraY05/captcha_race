(* Throwaway: render one frame of the moving-puzzle (mid-drag, so the slot
   has fled) into an X window for an offscreen screenshot. Not committed. *)
open! Core
open Captcha_race
open Captcha_race_engine
open Captcha_race_app
open Captcha_race_mini_games

let () =
  Graphics.open_graph " 800x600";
  let runner =
    Or_error.ok_exn
      (Game_runner.create
         ~pool:[ Mini_game.pack (module Moving_puzzle) ]
         ~random:(Random.State.make [| 3 |])
         ~bounds:Layout.play_bounds
         ~now:Time_ns.epoch
         ~count:3)
  in
  let pb = Layout.play_bounds in
  let hx = pb.x + 16 + (48 / 2) in
  let hy = pb.y + 16 + (22 / 2) in
  let feed ~mouse ~down ~clicked =
    match
      Game_runner.advance
        runner
        ~input:
          { Input.idle with
            mouse
          ; mouse_down = down
          ; mouse_clicked = clicked
          }
        ~now:Time_ns.epoch
        ~elapsed:Time_ns.Span.zero
    with
    | `Running | `Finished (_ : Time_ns.Span.t) -> ()
  in
  feed ~mouse:{ x = hx; y = hy } ~down:true ~clicked:true;
  feed ~mouse:{ x = hx + 120; y = hy } ~down:true ~clicked:false;
  let model =
    { App_state.Model.view = App_state.Playing runner
    ; leaderboard = Leaderboard.empty
    ; ripple = None
    }
  in
  Render.draw model ~now:Time_ns.epoch;
  Graphics.synchronize ();
  ignore (Core_unix.nanosleep 30.0 : float)
;;
