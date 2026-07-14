(** Turns an {!App_state.Model.t} into pixels.

    This is the only module in the library that issues [Graphics] drawing
    commands (mini-games draw themselves, but only when their [draw] is
    called from here). It never opens the window or reads input —
    [bin/main.ml] owns the display and the event loop — so merely linking
    against this module is safe on a headless machine.

    Nothing here is covered by expect tests: drawing needs an X server, which
    CI does not have. Keep logic out of this module. *)

open! Core

(** [draw model ~now] renders one frame of the current view. [now] feeds the
    elapsed-time HUD while a race is being played. Assumes double buffering:
    the caller clears via drawing and then calls [Graphics.synchronize]. *)
val draw : App_state.Model.t -> now:Time_ns.t -> unit
