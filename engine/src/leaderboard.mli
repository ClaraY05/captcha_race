(** The player's completion times, fastest first, persisted as a sexp file
    between runs.

    A leaderboard is a plain value threaded through [App_state.Model];
    finishing a race {!add}s an entry, and [bin/main.ml] {!save}s whenever
    the leaderboard changes. Tests use scratch paths (or skip persistence
    entirely) so they never touch the real score file.

    {[
      let leaderboard = Leaderboard.add Leaderboard.empty entry in
      Leaderboard.best leaderboard = Some entry
    ]} *)

open! Core

module Entry : sig
  (** One finished race. *)
  type t =
    { completion_time : Time_ns.Span.t
    (** start of the first game to the end of the last *)
    ; achieved_at : Time_ns.Alternate_sexp.t (** when the race finished *)
    }
  [@@deriving sexp]
end

type t [@@deriving sexp]

val empty : t

(** [add t entry] records a finished race, keeping entries sorted fastest
    first. *)
val add : t -> Entry.t -> t

(** Entries, fastest [completion_time] first. *)
val entries : t -> Entry.t list

(** The fastest entry, if any race has been completed. *)
val best : t -> Entry.t option

(** [load ~path] reads a previously {!save}d leaderboard. A missing file is
    an empty leaderboard, not an error; entries are re-sorted on load since
    the file is human-editable. *)
val load : path:string -> t Or_error.t

val save : t -> path:string -> unit Or_error.t
