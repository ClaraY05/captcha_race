open! Core
open Captcha_race_engine

module Action = struct
  type t =
    | Play
    | View_leaderboard
    | Back_to_menu
    | Quit_run
  [@@deriving sexp_of, equal]
end

type t =
  | Menu
  | Leaderboard
  | Playing of Game_runner.t
[@@deriving sexp_of]

module Model = struct
  type nonrec t =
    { view : t
    ; leaderboard : Leaderboard.t
    }
  [@@deriving sexp_of]
end

let games_per_run = 10

(* Button rectangles are laid out inside {!Layout.screen}; {!Render} draws
   exactly these, so hit-testing and pixels can never disagree. The button's
   visual style (primary / ghost / quit) is inferred from its [action] in
   [Render], so no style lives here. *)
let buttons view =
  match view with
  | Menu ->
    [ { Button.label = "PLAY"
      ; rect = { x = 290; y = 350; w = 220; h = 44 }
      ; action = Action.Play
      }
    ; { label = "LEADERBOARD"
      ; rect = { x = 290; y = 292; w = 220; h = 44 }
      ; action = View_leaderboard
      }
    ]
  | Leaderboard ->
    [ { Button.label = "PLAY AGAIN"
      ; rect = { x = 180; y = 200; w = 205; h = 40 }
      ; action = Action.Play
      }
    ; { label = "MENU"
      ; rect = { x = 405; y = 200; w = 125; h = 40 }
      ; action = Back_to_menu
      }
    ]
  | Playing (_ : Game_runner.t) ->
    [ { Button.label = "QUIT"
      ; rect = { x = 582; y = 494; w = 72; h = 26 }
      ; action = Action.Quit_run
      }
    ]
;;

let apply_action (model : Model.t) (action : Action.t) ~pool ~random ~now =
  match action with
  | View_leaderboard -> Ok { model with Model.view = Leaderboard }
  | Back_to_menu | Quit_run -> Ok { model with Model.view = Menu }
  | Play ->
    let%map.Or_error runner =
      Game_runner.create
        ~pool
        ~random
        ~bounds:Layout.play_bounds
        ~now
        ~count:games_per_run
    in
    { model with Model.view = Playing runner }
;;

let advance (model : Model.t) ~input ~now ~elapsed =
  match model.view with
  | Menu | Leaderboard -> model
  | Playing runner ->
    (match Game_runner.advance runner ~input ~now ~elapsed with
     | `Running -> model
     | `Finished completion_time ->
       let entry =
         { Leaderboard.Entry.completion_time; achieved_at = now }
       in
       { Model.view = Menu
       ; leaderboard = Leaderboard.add model.leaderboard entry
       })
;;
