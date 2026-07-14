(** The contract every mini-game ("captcha") implements.

    This is the plug-in point of the whole game: to add a new captcha, write
    a module satisfying {!S}, then register it in the pool in [bin/main.ml]
    with {!Mini_game.pack}. {!Game_runner} picks 10 games from that pool per
    run and drives each one through [update]/[draw]/[is_solved] until the
    player solves it.

    Rules of the house:
    - [create] and [update] must be display-free — no [Graphics] calls
      anywhere except [draw]. Tests (and CI, which has no X server) exercise
      games by feeding synthetic {!Captcha_race.Input.t} values and never
      call [draw].
    - Randomized layout must come from the injected [Random.State.t] so a
      fixed seed reproduces the same game in tests.

    See [Placeholder_game] (in the [captcha_race.mini_games] library) for a
    minimal example implementation. *)

open! Core
open Captcha_race

module type S = sig
  (** The game's own state. Abstract to everyone else; each game controls its
      own representation and derives [sexp_of] so state is inspectable in
      tests. *)
  type t [@@deriving sexp_of]

  (** Human-readable name, shown in the HUD while the game is active. *)
  val name : string

  (** [create ~random ~bounds] builds a fresh instance. [bounds] is the
      region the game may draw in
      ({!Captcha_race_engine.Layout.play_bounds}); [random] drives any
      randomized layout. *)
  val create : random:Random.State.t -> bounds:Geometry.Rect.t -> t

  (** [update t ~input ~elapsed] advances the game by one frame and returns
      its next state. [input] is this frame's snapshot of the player's
      pointer and keyboard; [elapsed] is the time since the previous frame.
      Purely event-driven games ignore [elapsed]; animated games integrate
      it. *)
  val update : t -> input:Input.t -> elapsed:Time_ns.Span.t -> t

  (** [draw t] renders the current state — the only place a game may issue
      [Graphics] commands. *)
  val draw : t -> unit

  (** [is_solved t] is [true] once the player has completed this game; the
      runner then moves on to the next one. *)
  val is_solved : t -> bool
end
