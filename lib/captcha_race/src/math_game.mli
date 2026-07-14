(** A two-phase captcha: solve the arithmetic, then remember the answer.

    Phase one draws a simple problem — ["7 + 6 = ?"], ["12 / 4 = ?"] — whose
    answer is always between 1 and 20, with a text field and an [Enter]
    button. The player types the answer and submits it with the button or the
    Return key. A wrong answer clears the field and asks again.

    Phase two {e replaces} the problem with an "I'm not a robot" reCAPTCHA
    box. The problem is no longer on screen, so the player must have
    memorized their answer: the game is solved only once the checkbox has
    been clicked exactly that many times. The checkbox fills briefly on each
    click to confirm the click landed, but never shows the running count.

    Like every {!Mini_game_intf.S} this is display-free outside [draw], and
    takes all its randomness from the injected [Random.State.t] and all its
    timing from [~elapsed].

    {[
      let game = Math_game.create ~random ~bounds in
      (* type "13", press Return, then click the checkbox 13 times *)
      Math_game.is_solved game
    ]} *)

open! Core

type t

include Mini_game_intf.S with type t := t

module For_testing : sig
  (** The answer to this game's problem: what the player must type in phase
      one, and how many times they must click the checkbox in phase two. *)
  val answer : t -> int

  (** The problem as it is drawn, e.g. ["7 + 6 = ?"]. *)
  val problem : t -> string

  (** The two operands, for asserting generated problems stay simple. *)
  val operands : t -> int * int

  (** Where the [Enter] button sits, so tests know where to aim. *)
  val enter_button : t -> Geometry.Rect.t

  (** Where the reCAPTCHA checkbox sits, so tests know where to aim. *)
  val checkbox : t -> Geometry.Rect.t
end
