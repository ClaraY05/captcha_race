open! Core

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
    ; ripple : Click_ripple.t option
    }
  [@@deriving sexp_of]
end

let window_width = 800
let window_height = 600
let games_per_run = 10
let hud_height = 60

let play_bounds =
  { Geometry.Rect.x = 0
  ; y = 0
  ; w = window_width
  ; h = window_height - hud_height
  }
;;

let menu_button_w = 200
let menu_button_h = 50
let menu_button_x = (window_width - menu_button_w) / 2

let buttons view =
  match view with
  | Menu ->
    [ { Button.label = "Play"
      ; rect =
          { x = menu_button_x
          ; y = 320
          ; w = menu_button_w
          ; h = menu_button_h
          }
      ; action = Action.Play
      }
    ; { label = "Leaderboard"
      ; rect =
          { x = menu_button_x
          ; y = 240
          ; w = menu_button_w
          ; h = menu_button_h
          }
      ; action = View_leaderboard
      }
    ]
  | Leaderboard ->
    [ { Button.label = "Back"
      ; rect =
          { x = menu_button_x; y = 60; w = menu_button_w; h = menu_button_h }
      ; action = Action.Back_to_menu
      }
    ]
  | Playing (_ : Game_runner.t) ->
    [ { Button.label = "Quit"
      ; rect =
          { x = window_width - 110; y = window_height - 50; w = 100; h = 40 }
      ; action = Action.Quit_run
      }
    ]
;;

(* Every click leaves a ripple, whatever the click landed on and whatever
   view we are in — including clicks a mini-game ignores. *)
let record_click (model : Model.t) ~(input : Input.t) ~now =
  match input.mouse_clicked with
  | false -> model
  | true ->
    { model with
      Model.ripple = Some (Click_ripple.create ~center:input.mouse ~now)
    }
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
        ~bounds:play_bounds
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
       { model with
         Model.view = Menu
       ; leaderboard = Leaderboard.add model.leaderboard entry
       })
;;
