(** The stand-in captcha used until real mini-games exist.

    A single "I am not a robot" box appears at a random spot inside the
    game's bounds; clicking it solves the game. It exists so the whole app
    runs end-to-end today, and it doubles as the reference implementation of
    {!Mini_game_intf.S} for future games to copy.

    {[
      let game = Placeholder_game.create ~random ~bounds in
      Placeholder_game.is_solved game = false
    ]} *)

open! Core

type t

include Mini_game_intf.S with type t := t

module For_testing : sig
  (** Where the clickable box was placed, so tests know where to aim. *)
  val target : t -> Geometry.Rect.t
end
