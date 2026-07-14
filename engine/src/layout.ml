open! Core
open Captcha_race

let window_width = 800
let window_height = 600
let hud_height = 60

let play_bounds =
  { Geometry.Rect.x = 0
  ; y = 0
  ; w = window_width
  ; h = window_height - hud_height
  }
;;
