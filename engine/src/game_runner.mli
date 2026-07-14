(** Runs one race: a randomized sequence of mini-games played back to back,
    timed from the start of the first to the end of the last.

    A runner is created when the player hits Play ([App_state] owns it while
    the view is [Playing]). Each frame the event loop calls {!advance}, which
    forwards input to the active game and moves to the next one once it's
    solved; after the final game it reports [`Finished] with the total time,
    which [App_state] records in the {!Leaderboard}.

    Sequencing and timing are pure: randomness and the clock are injected, so
    a fixed seed and synthetic [now]s make runs fully deterministic in tests
    (which never call [draw]).

    {[
      match Game_runner.advance t ~input ~now ~elapsed with
      | `Running -> (* keep playing *)
      | `Finished total -> (* record [total] on the leaderboard *)
    ]} *)

open! Core
open Captcha_race

type t [@@deriving sexp_of]

(** [create ~pool ~random ~bounds ~now ~count] samples [count] games from
    [pool] (repeats allowed — the pool may be smaller than [count]),
    instantiates them all, and stamps the start time [now]. Errors if [pool]
    is empty or [count] is not positive. *)
val create
  :  pool:Mini_game.factory list
  -> random:Random.State.t
  -> bounds:Geometry.Rect.t
  -> now:Time_ns.t
  -> count:int
  -> t Or_error.t

(** The game the player is currently solving; [None] once every game has been
    solved. *)
val current : t -> Mini_game.t option

(** 0-based index of the current game; equals {!count} when finished. *)
val current_index : t -> int

(** How many games this run consists of. *)
val count : t -> int

val started_at : t -> Time_ns.t

(** Time since the run started; shown in the HUD. *)
val elapsed_so_far : t -> now:Time_ns.t -> Time_ns.Span.t

(** Feed one frame to the active game; when it becomes solved, move to the
    next. [`Finished total] fires on the frame the last game is solved, with
    [total] measured from [create]'s [now] to this one. *)
val advance
  :  t
  -> input:Input.t
  -> now:Time_ns.t
  -> elapsed:Time_ns.Span.t
  -> [ `Running | `Finished of Time_ns.Span.t ]
