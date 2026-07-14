(** The three-screen view state machine at the heart of the app.

    The view is one of [Menu], [Leaderboard], or [Playing] (which owns the
    live {!Captcha_race_engine.Game_runner.t} for the current race). A
    {!Model.t} pairs the view with the persistent
    {!Captcha_race_engine.Leaderboard.t} carried across screens.

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
open Captcha_race
open Captcha_race_engine

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
    ; ripple : Click_ripple.t option
    (** the player's most recent click, drawn as an expanding ring; [None]
        before the first click of the session *)
    }
  [@@deriving sexp_of]
end

(** How many mini-games make up one race. The play area and window size live
    in {!Captcha_race_engine.Layout}. *)
val games_per_run : int

(** The clickable buttons for the given view. {!Render} draws exactly these
    and the event loop hit-tests against them, so the two can never disagree
    about where buttons are. *)
val buttons : t -> Action.t Button.t list

(** [record_click model ~input ~now] starts a {!Click_ripple.t} at the
    pointer if [input] clicked this frame, so that every click gets visible
    acknowledgement no matter what it landed on. The event loop applies this
    to every input, alongside {!apply_action} or {!advance}. *)
val record_click : Model.t -> input:Input.t -> now:Time_ns.t -> Model.t

(** [apply_action model action ~pool ~random ~now] is the model after a
    button click. Errors only if [Play] is clicked with a broken
    configuration (empty [pool]) — see
    {!Captcha_race_engine.Game_runner.create}. *)
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
