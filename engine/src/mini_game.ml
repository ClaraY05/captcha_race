open! Core
open Captcha_race

type t =
  | T :
      { game : (module Mini_game_intf.S with type t = 's)
      ; state : 's
      }
      -> t

type factory = random:Random.State.t -> bounds:Geometry.Rect.t -> t

let pack (module M : Mini_game_intf.S) : factory =
  fun ~random ~bounds ->
  T { game = (module M); state = M.create ~random ~bounds }
;;

let name (T { game = (module M); state = _ }) = M.name

let sexp_of_t (T { game = (module M); state }) =
  [%sexp (M.name : string), (state : M.t)]
;;

let update (T { game = (module M); state }) ~input ~elapsed =
  T { game = (module M); state = M.update state ~input ~elapsed }
;;

let draw (T { game = (module M); state }) = M.draw state
let is_solved (T { game = (module M); state }) = M.is_solved state
