(** A captcha that starts unreadable and resolves as the clock runs.

    A word is drawn from a small dictionary and rendered {e wrecked}: every
    letter is thrown off its baseline and trailed by a smear copy, decoy
    letters are scattered around it, and lines and specks are ruled across
    the whole band. The player types what they think the word is into the
    field below and submits it with the [Enter] button or the Return key; a
    wrong guess clears the field and lets them look again.

    The catch is time. The distortion decays from 1.0 to 0.0 over 20 seconds
    and every effect above is scaled by it, so the word slides steadily back
    onto its baseline and the noise thins out speck by speck: illegible at
    first, plain text at the end. Guessing early is the whole game — a player
    who can read the smear finishes in seconds, one who waits for it to clear
    pays for the wait in race time.

    Like every {!Captcha_race_engine.Mini_game_intf.S} this is display-free
    outside [draw], and takes all its randomness from the injected
    [Random.State.t] and all its timing from [~elapsed]: the distortion is a
    pure function of the time handed to [update], never of the wall clock.

    {[
      let game = Typing_game.create ~random ~bounds in
      (* type the word, then press Return *)
      Typing_game.is_solved game
    ]} *)

open! Core
open Captcha_race
open Captcha_race_engine

type t

include Mini_game_intf.S with type t := t

module For_testing : sig
  (** The word the player has to read: what they must type to solve the game. *)
  val word : t -> string

  (** What the player has typed into the field so far, always lowercase. *)
  val typed : t -> string

  (** How distorted the word is right now: 1.0 at [create], 0.0 once
      {!clear_after} has passed. *)
  val distortion : t -> float

  (** How many wrong guesses have been submitted. *)
  val wrong_attempts : t -> int

  (** The band the word and its noise are drawn in, for asserting the game
      stays inside its bounds. *)
  val word_area : t -> Geometry.Rect.t

  (** Where the text field sits. *)
  val input_box : t -> Geometry.Rect.t

  (** Where the [Enter] button sits, so tests know where to aim. *)
  val enter_button : t -> Geometry.Rect.t

  (** How long the word takes to become perfectly legible. *)
  val clear_after : Time_ns.Span.t
end
