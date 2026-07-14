(** A drag-puzzle captcha with a fleeing slot, in two dimensions: drag a
    shape to chase a matching slot that keeps dodging away on both axes.

    A shape starts at the bottom-left of the play area; an empty slot sits at
    a random offset up and to its right. The player grabs the shape and drags
    it freely on both the x and y axes. As the shape approaches, the slot
    flees, staying a fixed gap ahead on each axis, but only ever forward (up
    and to the right) and never past the far corner — so the shape can still
    be cornered there. Releasing with the shape lined up with the slot on
    both axes (within a small tolerance) solves the game; releasing it short
    snaps the shape back to the start. Having to corner a target that dodges
    diagonally, on both axes at once, is the challenge.

    This is a second reference implementation of
    {!Captcha_race_engine.Mini_game_intf.S} alongside
    {!Captcha_race_mini_games.Placeholder_game}: all state lives in [t],
    randomness comes from the injected [Random.State.t], and only [draw]
    touches [Graphics].

    {[
      let game = Moving_puzzle.create ~random ~bounds in
      Moving_puzzle.is_solved game = false
    ]} *)

open! Core
open Captcha_race
open Captcha_race_engine

type t

include Mini_game_intf.S with type t := t

module For_testing : sig
  (** The [(x, y)] offset (in pixels) the shape must reach to line up with
      the slot. *)
  val target_offset : t -> int * int

  (** The current shape [(x, y)] offset from the start, in pixels. *)
  val offset : t -> int * int

  (** The draggable shape's rectangle, so tests know where to grab and how
      far it has travelled. *)
  val piece_rect : t -> Geometry.Rect.t

  (** The target slot's rectangle, for checking it stays inside the play
      area. *)
  val slot_rect : t -> Geometry.Rect.t
end
