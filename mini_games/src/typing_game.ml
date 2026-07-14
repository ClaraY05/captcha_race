open! Core
open Captcha_race

module Dictionary = struct
  (* Common words, 5-7 letters: long enough that a smeared word is genuinely
     unreadable, short enough to still fit the card once each glyph has
     drifted off its baseline. No plurals or near-anagrams of each other, so
     a player who can half-read the word is not left guessing between two
     candidates. *)
  let words =
    [| "anchor"
     ; "basket"
     ; "candle"
     ; "canyon"
     ; "carpet"
     ; "cinder"
     ; "clover"
     ; "copper"
     ; "cradle"
     ; "dagger"
     ; "dolphin"
     ; "ember"
     ; "fabric"
     ; "falcon"
     ; "forest"
     ; "garden"
     ; "gravel"
     ; "hammer"
     ; "harbor"
     ; "helmet"
     ; "hollow"
     ; "island"
     ; "jacket"
     ; "kettle"
     ; "ladder"
     ; "lantern"
     ; "marble"
     ; "meadow"
     ; "mirror"
     ; "orchid"
     ; "pebble"
     ; "pillar"
     ; "planet"
     ; "pocket"
     ; "puzzle"
     ; "quartz"
     ; "ribbon"
     ; "saddle"
     ; "signal"
     ; "silver"
     ; "socket"
     ; "sparrow"
     ; "syrup"
     ; "temple"
     ; "thimble"
     ; "timber"
     ; "tunnel"
     ; "velvet"
     ; "walnut"
     ; "willow"
    |]
  ;;

  let choose ~random = words.(Random.State.int random (Array.length words))
end

(* The word is set in the game's chunky display face rather than the small
   [Graphics] font. A 13px letter has no room to be distorted: any drift or
   noise that is strong enough to obscure it also destroys it, leaving
   nothing for the player to read. A blocky letter three times that size
   takes a beating and is still a letter, which is what makes reading the
   smear early a skill rather than a guess. *)
module Pixel_font = Captcha_race_engine.Pixel_font

(* Pixels per font cell: the word is drawn at [Pixel_font.cell_w] x
   [Pixel_font.cell_h] cells of this size, i.e. 15x21 pixels a letter. *)
let glyph_scale = 3

(* One blank cell between letters, as {!Pixel_font.width} lays them out. *)
let letter_advance = (Pixel_font.cell_w + 1) * glyph_scale
let glyph_h = Pixel_font.cell_h * glyph_scale

(* The distorted word and the noise on top of it are both drawn from the
   injected [Random.State.t] once, at [create], and then merely {e scaled} by
   the current distortion in [draw]. Rolling fresh randomness every frame
   would make the word strobe, and would need an RNG inside [update]; fixing
   the shape up front means the letters slide steadily back onto their
   baseline as the distortion decays, which is the effect we want — an
   illegible smear resolving into a word. *)

module Glyph = struct
  (* Where a letter sits at full distortion, relative to where it belongs.
     [smear] is a second copy of the letter, offset from the first and only
     slightly lighter: two overlapping copies read as motion blur, which no
     single offset can. *)
  type t =
    { drift : Geometry.Point.t
    ; smear : Geometry.Point.t
    }
  [@@deriving sexp_of]

  (* Vertical drift is the big one — a letter thrown a full line off the
     baseline stops reading as part of the word at all. It is bounded so the
     tallest drift still sits inside {!Layout.word_area}. *)
  let max_drift_x = 3
  let max_drift_y = 8
  let max_smear = 3

  (* How far the letters pile onto each other at full distortion: each
     advance is cut by this fraction, so neighbouring glyphs overlap and the
     word loses its letter boundaries. Collapsing the spacing is what makes
     the word unreadable even when a player can make out the individual
     shapes. *)
  let max_crowding = 0.12

  let generate ~random =
    let between bound = Random.State.int_incl random (-bound) bound in
    { drift =
        { Geometry.Point.x = between max_drift_x; y = between max_drift_y }
    ; smear = { Geometry.Point.x = between max_smear; y = between max_smear }
    }
  ;;
end

module Speck = struct
  (* A fleck of noise over the word. [threshold] is the distortion at which it
     disappears: specks are drawn only while [threshold < distortion], so as
     the distortion decays the noise thins out speck by speck instead of all at
     once. Each speck's threshold is uniform in [0, 1), so the count falls off
     linearly with the distortion.

     Half the specks are [Bite]s — the card's own colour, punched {e out} of
     the letters rather than laid on top of them. Ink alone only ever adds to a
     glyph, and a letter with ink on it is still that letter; a letter with
     holes in it could be several. *)
  type kind =
    | Ink
    | Bite
  [@@deriving sexp_of]

  type t =
    { at : Geometry.Point.t
    ; size : int
    ; kind : kind
    ; threshold : float
    }
  [@@deriving sexp_of]

  let count = 300
  let max_size = 3

  let generate ~random ~(area : Geometry.Rect.t) =
    { at =
        { Geometry.Point.x =
            Random.State.int_incl random area.x (area.x + area.w)
        ; y = Random.State.int_incl random area.y (area.y + area.h)
        }
    ; size = Random.State.int_incl random 1 max_size
    ; kind =
        (match Random.State.bool random with true -> Ink | false -> Bite)
    ; threshold = Random.State.float random 1.0
    }
  ;;
end

module Strike = struct
  (* A line ruled across the word, the way a real captcha scores its text.
     Fades out by [threshold] exactly as {!Speck} does. *)
  type t =
    { from : Geometry.Point.t
    ; to_ : Geometry.Point.t
    ; threshold : float
    }
  [@@deriving sexp_of]

  let count = 7

  let generate ~random ~(area : Geometry.Rect.t) =
    let y () = Random.State.int_incl random area.y (area.y + area.h) in
    { from = { Geometry.Point.x = area.x; y = y () }
    ; to_ = { Geometry.Point.x = area.x + area.w; y = y () }
    ; threshold = Random.State.float random 1.0
    }
  ;;
end

type t =
  { word : string
  ; typed : string
  ; bounds : Geometry.Rect.t
  ; glyphs : Glyph.t array
  ; specks : Speck.t array
  ; strikes : Strike.t array
  ; distortion : float
  (** 1.0 at [create], falling to 0.0 over {!clear_after}; every distortion
      effect is scaled by it, so the word is unreadable at first and clean at
      the end *)
  ; wrong_attempts : int
  ; is_solved : bool
  }
[@@deriving sexp_of]

let name = "read the word"

(* Pure arithmetic on [bounds] ({!Captcha_race_engine.Layout.play_bounds} —
   the short, wide interior of the captcha card), so [update], [draw] and
   [For_testing] cannot disagree about where anything is. No [Graphics] here,
   not even [text_size], which is what lets [update] and the tests run
   headless: the word's own width is the one thing that needs measuring, and
   that happens inside [draw]. *)
module Layout = struct
  let input_w = 200
  let button_w = 100
  let field_h = 30
  let field_gap = 14

  let field_left (bounds : Geometry.Rect.t) =
    bounds.x + ((bounds.w - (input_w + field_gap + button_w)) / 2)
  ;;

  let prompt_y (bounds : Geometry.Rect.t) = bounds.y + bounds.h - 20

  let input_box (bounds : Geometry.Rect.t) : Geometry.Rect.t =
    { x = field_left bounds; y = bounds.y + 14; w = input_w; h = field_h }
  ;;

  let enter_button (bounds : Geometry.Rect.t) : Geometry.Rect.t =
    { x = field_left bounds + input_w + field_gap
    ; y = bounds.y + 14
    ; w = button_w
    ; h = field_h
    }
  ;;

  (* The band the word lives in, and the only place noise is drawn. Tall
     enough to hold a glyph that has drifted a full {!Glyph.max_drift_y} off
     its baseline without escaping [bounds]. *)
  let word_area (bounds : Geometry.Rect.t) : Geometry.Rect.t =
    { x = bounds.x + 12
    ; y = bounds.y + 56
    ; w = bounds.w - 24
    ; h = bounds.h - 56 - 30
    }
  ;;

  (* The bottom of the letters once they have resolved, so that a glyph box
     sits centred in the band. *)
  let baseline_y bounds =
    let area = word_area bounds in
    area.y + ((area.h - glyph_h) / 2)
  ;;
end

(* How long the word takes to become perfectly legible. Long enough that
   reading it early is a real edge in a race, short enough that a player who
   simply cannot read it is not stuck for long. *)
let clear_after = Time_ns.Span.of_int_sec 20

let create ~random ~bounds =
  let area = Layout.word_area bounds in
  let word = Dictionary.choose ~random in
  { word
  ; typed = ""
  ; bounds
  ; glyphs =
      Array.init (String.length word) ~f:(fun (_ : int) ->
        Glyph.generate ~random)
  ; specks =
      Array.init Speck.count ~f:(fun (_ : int) ->
        Speck.generate ~random ~area)
  ; strikes =
      Array.init Strike.count ~f:(fun (_ : int) ->
        Strike.generate ~random ~area)
  ; distortion = 1.0
  ; wrong_attempts = 0
  ; is_solved = false
  }
;;

let is_solved t = t.is_solved

(* The longest word is 7 letters; the slack is room to mistype and back up
   rather than an invitation to keep typing. *)
let max_typed = 12

let apply_key typed key =
  match key with
  | ('a' .. 'z' | 'A' .. 'Z') when String.length typed < max_typed ->
    typed ^ String.of_char (Char.lowercase key)
  (* X11 sends DEL for BackSpace on some setups. *)
  | '\b' | '\127' ->
    (match String.is_empty typed with
     | true -> typed
     | false -> String.drop_suffix typed 1)
  | _ -> typed
;;

(* The word keeps resolving while the player types: the distortion is a pure
   function of how long the game has been on screen, and a wrong guess
   neither sets it back nor speeds it up. *)
let decay distortion ~elapsed =
  let step =
    Time_ns.Span.to_sec elapsed /. Time_ns.Span.to_sec clear_after
  in
  Float.max 0.0 (distortion -. step)
;;

let update t ~(input : Input.t) ~elapsed =
  match t.is_solved with
  | true -> t
  | false ->
    let t = { t with distortion = decay t.distortion ~elapsed } in
    (* Take the keystroke first, so a letter and a click on [Enter] landing
       in the same frame still submit that letter. *)
    let typed =
      match input.key with
      | None -> t.typed
      | Some key -> apply_key t.typed key
    in
    let submitted =
      (input.mouse_clicked
       && Geometry.Rect.contains (Layout.enter_button t.bounds) input.mouse)
      ||
      match input.key with
      | Some ('\r' | '\n') -> true
      | Some (_ : char) | None -> false
    in
    (match submitted && not (String.is_empty typed) with
     | false -> { t with typed }
     | true ->
       (match String.equal typed t.word with
        | true -> { t with typed; is_solved = true }
        | false ->
          { t with typed = ""; wrong_attempts = t.wrong_attempts + 1 }))
;;

(* Palette — the captcha card's tokens, matching [Math_game] and the card
   {!Captcha_race_app.Render} draws underneath: dark ink on a warm beige
   card, with a gold accent. The game draws {e on} that card, so it paints no
   background of its own. *)
let c_ink = Graphics.rgb 38 36 31
let c_ink_dim = Graphics.rgb 120 113 98
let c_accent = Graphics.rgb 203 171 99
let c_card = Graphics.rgb 232 228 217
let c_field = Graphics.rgb 217 212 200
let c_field_shade = Graphics.rgb 195 188 171
let c_shadow = Graphics.rgb 20 17 22
let c_error = Graphics.rgb 176 96 74
let line_h = 13

(* [Graphics] has no alpha, so a weakened colour has to be mixed by hand:
   [mix color ~toward ~by:0.0] is [color] and [~by:1.0] is [toward]. *)
let mix color ~toward ~by =
  let by = Float.clamp_exn by ~min:0.0 ~max:1.0 in
  let channel channel_of =
    let from = Float.of_int (channel_of color) in
    let toward = Float.of_int (channel_of toward) in
    Float.iround_nearest_exn (from +. ((toward -. from) *. by))
  in
  let red rgb = (rgb lsr 16) land 0xff in
  let green rgb = (rgb lsr 8) land 0xff in
  let blue rgb = rgb land 0xff in
  Graphics.rgb (channel red) (channel green) (channel blue)
;;

(* Fading means mixing toward the card underneath: this is how the smear
   copies, the specks and the decoys thin out as the word resolves, instead
   of vanishing at full strength. *)
let fade color ~by = mix color ~toward:c_card ~by

let fill_rect (rect : Geometry.Rect.t) ~color =
  Graphics.set_color color;
  Graphics.fill_rect rect.x rect.y rect.w rect.h
;;

(* A recessed field: flat fill with a hard shade along the top-left, the
   flat-pixel stand-in for an inset shadow. *)
let sunken_rect (rect : Geometry.Rect.t) ~color =
  fill_rect rect ~color;
  Graphics.set_color c_field_shade;
  Graphics.fill_rect rect.x (rect.y + rect.h - 3) rect.w 3;
  Graphics.fill_rect rect.x rect.y 3 rect.h
;;

let draw_string_centered label ~x ~y ~color =
  let text_w, (_ : int) = Graphics.text_size label in
  Graphics.set_color color;
  Graphics.moveto (x - (text_w / 2)) y;
  Graphics.draw_string label
;;

let draw_string_at string ~(at : Geometry.Point.t) ~color =
  Graphics.set_color color;
  Graphics.moveto at.x at.y;
  Graphics.draw_string string
;;

let scale offset ~by = Float.iround_nearest_exn (Float.of_int offset *. by)

(* One blocky letter: {!Pixel_font} says where the lit pixels of the glyph
   fall, and each becomes a filled square. The font is uppercase-only, so the
   word is shown in capitals even though the player types it in lower case. *)
let draw_letter char ~(at : Geometry.Point.t) ~color =
  Graphics.set_color color;
  Pixel_font.foreach_pixel
    (String.of_char (Char.uppercase char))
    ~scale:glyph_scale
    ~x:at.x
    ~y:at.y
    ~f:(fun ~x ~y ~size -> Graphics.fill_rect x y size size)
;;

(* The word itself: each letter on its baseline, pushed off it by its own
   drift, with a smear copy either side of it. Every offset is scaled by the
   distortion, so at 1.0 the letters are strewn across the band in a blur,
   and at 0.0 each has collapsed onto the baseline into plain, evenly spaced
   text. *)
let draw_word t =
  (* Crowding shortens every advance, so the word is narrower than its
     resolved width and has to be re-centred on the crowded one. *)
  let crowding = 1.0 -. (Glyph.max_crowding *. t.distortion) in
  let advance = scale letter_advance ~by:crowding in
  let letter_w = Pixel_font.cell_w * glyph_scale in
  let word_w = (advance * (String.length t.word - 1)) + letter_w in
  let baseline_y = Layout.baseline_y t.bounds in
  let center = Geometry.Rect.center t.bounds in
  let left = center.x - (word_w / 2) in
  String.iteri t.word ~f:(fun index char ->
    let { Glyph.drift; smear } = t.glyphs.(index) in
    let x = left + (index * advance) + scale drift.x ~by:t.distortion in
    let y = baseline_y + scale drift.y ~by:t.distortion in
    (* The smear trails the letter on both sides — one copy either way, so a
       glyph at full distortion is a three-deep blur with no obvious middle. *)
    let smear_color = fade c_ink ~by:(0.45 -. (t.distortion *. 0.2)) in
    List.iter [ 1; -1 ] ~f:(fun direction ->
      draw_letter
        char
        ~at:
          { x = x + scale (smear.x * direction) ~by:t.distortion
          ; y = y + scale (smear.y * direction) ~by:t.distortion
          }
        ~color:smear_color);
    draw_letter char ~at:{ x; y } ~color:c_ink)
;;

(* Everything laid over the word: ruled lines and specks, each drawn only
   while the distortion is still above its own threshold and each dimming as
   it nears it. Drawn after the word, so at full distortion they genuinely
   obscure it.

   The noise is deliberately letterless. Scattering stray glyphs around the
   word obscures it well, but it also puts letters on screen that are not in
   the answer, and a player who has half-read the word cannot tell which of
   them to type. Ink that is plainly not a letter takes nothing away from the
   player's ability to trust what they can read. *)
let draw_noise t =
  let is_showing threshold = Float.( < ) threshold t.distortion in
  (* Each piece of noise dims as the distortion closes in on its own
     threshold, so it thins away rather than blinking out. *)
  let nearness threshold = threshold /. t.distortion in
  Array.iter t.strikes ~f:(fun { Strike.from; to_; threshold } ->
    match is_showing threshold with
    | false -> ()
    | true ->
      Graphics.set_color (fade c_ink_dim ~by:(nearness threshold *. 0.6));
      Graphics.set_line_width 2;
      Graphics.moveto from.x from.y;
      Graphics.lineto to_.x to_.y;
      (* [set_line_width] is global [Graphics] state: left at 2 it would
         bleed into whatever draws next. *)
      Graphics.set_line_width 1);
  Array.iter t.specks ~f:(fun { Speck.at; size; kind; threshold } ->
    match is_showing threshold with
    | false -> ()
    | true ->
      let color =
        match kind with
        | Ink -> fade c_ink ~by:(nearness threshold *. 0.5)
        (* A bite is the card's own colour punched out of a letter, and it
           fades the other way — toward the ink it is eating — so it stops
           taking chunks out of the word as the word resolves. *)
        | Bite -> mix c_card ~toward:c_ink ~by:(nearness threshold *. 0.5)
      in
      Graphics.set_color color;
      Graphics.fill_rect at.x at.y size size)
;;

let draw t =
  let center = Geometry.Rect.center t.bounds in
  (let prompt, color =
     match t.wrong_attempts > 0 with
     | false -> "Type the word you see", c_ink_dim
     | true -> "Not the word - look again", c_error
   in
   draw_string_centered
     prompt
     ~x:center.x
     ~y:(Layout.prompt_y t.bounds)
     ~color);
  draw_word t;
  draw_noise t;
  let input_box = Layout.input_box t.bounds in
  sunken_rect input_box ~color:c_field;
  draw_string_at
    [%string "%{t.typed}_"]
    ~at:
      { x = input_box.x + 10
      ; y = input_box.y + ((Layout.field_h - line_h) / 2)
      }
    ~color:c_ink;
  (* The [Enter] button echoes the accent buttons [Render] draws, hard drop
     shadow and all. *)
  let enter = Layout.enter_button t.bounds in
  fill_rect { enter with x = enter.x + 3; y = enter.y - 3 } ~color:c_shadow;
  fill_rect enter ~color:c_accent;
  draw_string_centered
    "ENTER"
    ~x:(enter.x + (enter.w / 2))
    ~y:(enter.y + ((enter.h - line_h) / 2))
    ~color:c_ink
;;

module For_testing = struct
  let word t = t.word
  let typed t = t.typed
  let distortion t = t.distortion
  let wrong_attempts t = t.wrong_attempts
  let word_area t = Layout.word_area t.bounds
  let input_box t = Layout.input_box t.bounds
  let enter_button t = Layout.enter_button t.bounds
  let clear_after = clear_after
end
