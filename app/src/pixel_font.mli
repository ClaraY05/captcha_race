(** A chunky 5x7 uppercase bitmap font: a stand-in for Press Start 2P, the
    display face of the {!Render} CRT design.

    [Graphics] can only draw its own small fixed font, so the design's Press
    Start 2P text (titles, HUD labels, buttons, ranks) is reproduced here as
    pure pixel geometry: each glyph is a {!cell_w}x{!cell_h} grid of lit
    cells. This module computes {e where} a string's lit pixels fall;
    {!Render} draws them as filled rectangles, one per pixel, at whatever
    scale it likes. Keeping the geometry here (and the drawing in [Render])
    leaves [Graphics] confined to [Render] and makes the font exercisable by
    headless tests. Unknown characters render as blank space, so callers can
    pass arbitrary strings.

    {[
      Pixel_font.foreach_pixel "GO" ~scale:4 ~x ~y ~f:(fun ~x ~y ~size ->
        Graphics.fill_rect x y size size)
    ]} *)

open! Core

(** Glyph grid size, in cells: {!cell_w} wide by {!cell_h} tall. *)
val cell_w : int

val cell_h : int

(** [width s ~scale] is the pixel width of [s] rendered at [scale] pixels per
    cell, with one blank cell between characters and none trailing. Use it to
    centre or right-align text. *)
val width : string -> scale:int -> int

(** [foreach_pixel s ~scale ~x ~y ~f] calls [f] once for each lit pixel of
    [s], left to right. [x], [y] is the bottom-left corner of the text box
    (matching [Graphics]' bottom-left origin); each pixel is a [scale]-by-
    [scale] square whose bottom-left corner is passed as [~x] [~y] with
    [~size:scale]. The function itself draws nothing — [f] does. *)
val foreach_pixel
  :  string
  -> scale:int
  -> x:int
  -> y:int
  -> f:(x:int -> y:int -> size:int -> unit)
  -> unit
