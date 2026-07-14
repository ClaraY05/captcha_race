open! Core

type t =
  { games : Mini_game.t array
  ; mutable index : int
  ; started_at : Time_ns.t
  }

let count t = Array.length t.games
let current_index t = t.index

let current t =
  match t.index < count t with
  | true -> Some t.games.(t.index)
  | false -> None
;;

let started_at t = t.started_at
let elapsed_so_far t ~now = Time_ns.diff now t.started_at

(* Summarize rather than serialize game internals: index, names and start
   time are what sequencing tests care about. *)
let sexp_of_t t =
  [%message
    ""
      ~index:(t.index : int)
      ~count:(count t : int)
      ~games:(Array.map t.games ~f:Mini_game.name : string array)
      ~started_at:(t.started_at : Time_ns.Alternate_sexp.t)]
;;

let create ~pool ~random ~bounds ~now ~count =
  match pool, count > 0 with
  | [], _ ->
    Or_error.error_s [%message "Game_runner.create: empty mini-game pool"]
  | _ :: _, false ->
    Or_error.error_s
      [%message "Game_runner.create: count must be positive" (count : int)]
  | _ :: _, true ->
    let pool = Array.of_list pool in
    let games =
      Array.init count ~f:(fun (_ : int) ->
        let factory = pool.(Random.State.int random (Array.length pool)) in
        factory ~random ~bounds)
    in
    Ok { games; index = 0; started_at = now }
;;

let advance t ~input ~now ~elapsed =
  match current t with
  | None -> `Finished (elapsed_so_far t ~now)
  | Some game ->
    let game = Mini_game.update game ~input ~elapsed in
    t.games.(t.index) <- game;
    (match Mini_game.is_solved game with
     | false -> `Running
     | true ->
       t.index <- t.index + 1;
       (match t.index >= count t with
        | false -> `Running
        | true -> `Finished (elapsed_so_far t ~now)))
;;
