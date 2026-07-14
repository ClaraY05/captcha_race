(** A two-phase captcha: solve the arithmetic, then remember the answer.

    Phase one draws a two-step problem — ["7 x 3 - 6 = ?"],
    ["20 - 3 x 5 = ?"] — with a text field and an [Enter] button. The player
    types the answer and submits it with the button or the Return key. A
    wrong answer clears the field and asks again.

    The multiplication or division binds tighter than the [+]/[-] around it,
    so evaluating left to right gets it wrong: ["20 - 3 x 5"] is 5, not 85.
    That precedence trap is what makes these worth pausing over. The answer
    is nonetheless always between 1 and 20, which is a hard constraint rather
    than a stylistic one — see phase two.

    Phase two {e replaces} the problem with an "I'm not a robot" reCAPTCHA
    box. The problem is no longer on screen, so the player must have
    memorized their answer: the game is solved only once the checkbox has
    been clicked exactly that many times. The checkbox blinks a check on each
    click to confirm the click landed and clears again immediately, so a fast
    run reads as a string of distinct flashes; it never shows the running
    count.

    This is why the answer is capped at 20 no matter how hard the arithmetic
    gets: it doubles as the click count, and a harder problem with a bigger
    answer would only make phase two longer, not harder.

    Like every {!Captcha_race_engine.Mini_game_intf.S} this is display-free
    outside [draw], and takes all its randomness from the injected
    [Random.State.t] and all its timing from [~elapsed].

    {[
      (* shown "7 x 3 - 6 = ?" *)
      let game = Math_game.create ~random ~bounds in
      (* type "15", press Return, then click the checkbox 15 times *)
      Math_game.is_solved game
    ]} *)

open! Core
open Captcha_race
open Captcha_race_engine

type t

include Mini_game_intf.S with type t := t

module For_testing : sig
  (** The answer to this game's problem: what the player must type in phase
      one, and how many times they must click the checkbox in phase two. *)
  val answer : t -> int

  (** The problem as it is drawn, e.g. ["7 x 3 - 6 = ?"]. *)
  val problem : t -> string

  (** The three integers, in the order they are drawn, for asserting that
      generated problems stay small enough to do in one's head. *)
  val numbers : t -> int list

  (** [Some (dividend, divisor)] when the problem's term is a division, so a
      test can assert it comes out even. [None] otherwise. *)
  val division : t -> (int * int) option

  (** Where the [Enter] button sits, so tests know where to aim. *)
  val enter_button : t -> Geometry.Rect.t

  (** Where the reCAPTCHA checkbox sits, so tests know where to aim. *)
  val checkbox : t -> Geometry.Rect.t
end
