open! Core

module Entry = struct
  type t =
    { completion_time : Time_ns.Span.t
    ; achieved_at : Time_ns.Alternate_sexp.t
    }
  [@@deriving sexp]
end

(* Invariant: sorted by [completion_time], fastest first. *)
type t = Entry.t list

let sort =
  List.sort
    ~compare:
      (Comparable.lift Time_ns.Span.compare ~f:(fun (entry : Entry.t) ->
         entry.completion_time))
;;

let sexp_of_t t = [%sexp (t : Entry.t list)]

(* Re-sort on read: the file is human-editable, so we validate the ordering
   invariant rather than trust it. *)
let t_of_sexp sexp = sort ([%of_sexp: Entry.t list] sexp)
let empty = []
let add t entry = sort (entry :: t)
let entries t = t
let best t = List.hd t

let load ~path =
  match Sys_unix.file_exists path with
  | `No -> Ok empty
  | `Unknown ->
    Or_error.error_s
      [%message "Leaderboard.load: cannot stat file" (path : string)]
  | `Yes ->
    Or_error.try_with (fun () ->
      In_channel.read_all path |> Sexp.of_string |> t_of_sexp)
;;

let save t ~path =
  Or_error.try_with (fun () ->
    Out_channel.write_all path ~data:(Sexp.to_string_hum (sexp_of_t t)))
;;
