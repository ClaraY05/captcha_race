(** A slider-puzzle captcha with a fleeing slot: drag the handle to chase a
    shape into a matching slot that keeps sliding away.

    A shape starts at the left of the play area; an empty slot sits at a
    random offset to its right. The player grabs the handle on the track at
    the bottom and drags horizontally — the shape slides by the same amount.
    As the shape approaches, the slot flees, staying a fixed gap ahead, but
    only ever forward and never past the right wall — so the shape can still
    be cornered there. Releasing the handle with the shape lined up with the
    slot (within a small tolerance) solves the game; releasing it short snaps
    the shape back to the start, as the familiar "slide to verify" captcha
    does.

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
  (** The offset (in pixels) the shape must reach to line up with the slot. *)
  val target_offset : t -> int

  (** The current shape/handle offset from the start, in pixels. *)
  val offset : t -> int

  (** The handle's rectangle, so tests know where to grab and how far it has
      travelled. *)
  val handle_rect : t -> Geometry.Rect.t

  (** The target slot's rectangle, for checking it stays inside the play
      area. *)
  val slot_rect : t -> Geometry.Rect.t
end
