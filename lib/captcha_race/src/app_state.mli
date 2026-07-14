(** The three-screen view state machine at the heart of the app.

    The view is one of [Menu], [Leaderboard], or [Playing] (which owns the
    live {!Game_runner.t} for the current race). A {!Model.t} pairs the view
    with the persistent {!Leaderboard.t} carried across screens.

    Everything here is a pure transition — no drawing, no I/O. Each frame the
    event loop:
    + hit-tests clicks against {!buttons} and feeds any hit to
      {!apply_action};
    + otherwise calls {!advance}, which forwards input to the runner and,
      when the race finishes, records the time on the leaderboard and returns
      to the menu.

    {!Render.draw} turns a model into pixels; [bin/main.ml] saves the
    leaderboard whenever a transition changed it. *)

open! Core

module Action : sig
  (** What clicking a button asks the app to do. *)
  type t =
    | Play (** menu: start a race *)
    | View_leaderboard (** menu: show past times *)
    | Back_to_menu (** leaderboard: return to the menu *)
    | Quit_run (** playing: abandon the race (nothing is recorded) *)
  [@@deriving sexp_of, equal]
end

type t =
  | Menu
  | Leaderboard
  | Playing of Game_runner.t
[@@deriving sexp_of]

module Model : sig
  type nonrec t =
    { view : t
    ; leaderboard : Leaderboard.t
    }
  [@@deriving sexp_of]
end

val window_width : int
val window_height : int

(** How many mini-games make up one race. *)
val games_per_run : int

(** The region a mini-game may draw in: the window minus the HUD strip along
    the top. Passed as [bounds] to every game's [create]. *)
val play_bounds : Geometry.Rect.t

(** The clickable buttons for the given view. {!Render} draws exactly these
    and the event loop hit-tests against them, so the two can never disagree
    about where buttons are. *)
val buttons : t -> Action.t Button.t list

(** [apply_action model action ~pool ~random ~now] is the model after a
    button click. Errors only if [Play] is clicked with a broken
    configuration (empty [pool]) — see {!Game_runner.create}. *)
val apply_action
  :  Model.t
  -> Action.t
  -> pool:Mini_game.factory list
  -> random:Random.State.t
  -> now:Time_ns.t
  -> Model.t Or_error.t

(** Advance the current view by one frame. [Menu] and [Leaderboard] are
    inert; [Playing] forwards [input] to the runner and, on the frame the
    last game is solved, adds the total time to the leaderboard and returns
    to [Menu]. *)
val advance
  :  Model.t
  -> input:Input.t
  -> now:Time_ns.t
  -> elapsed:Time_ns.Span.t
  -> Model.t
