(** A live, type-erased mini-game instance.

    Any module implementing {!Mini_game_intf.S} can be turned into a
    {!factory} with {!pack}; the factory pairs the module with a freshly
    [create]d state, hiding the state's type. That lets {!Game_runner} hold
    an arbitrary mix of games and drive them uniformly through {!update},
    {!draw} and {!is_solved} without knowing which game is which. No functors
    involved — packing is a plain first-class-module value.

    {[
      let pool = [ Mini_game.pack (module Placeholder_game) ] in
      let game = (List.hd_exn pool) ~random ~bounds in
      Mini_game.name game (* the game's [name] *)
    ]} *)

open! Core

type t [@@deriving sexp_of]

(** Given randomness and drawable bounds, produce a packed live game. The
    runner's pool is a list of these. *)
type factory = random:Random.State.t -> bounds:Geometry.Rect.t -> t

(** [pack (module M)] turns a mini-game module into a {!factory}. This is the
    sole place packing happens. *)
val pack : (module Mini_game_intf.S) -> factory

val name : t -> string

(** [update t ~input ~elapsed] is [t] one frame later; see
    {!Mini_game_intf.S.update}. *)
val update : t -> input:Input.t -> elapsed:Time_ns.Span.t -> t

(** Renders the game; the only function here that touches [Graphics]. *)
val draw : t -> unit

val is_solved : t -> bool
