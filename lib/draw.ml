open Graphics

type sprite = {
  pixels : int list;
  width : int;
  height : int;
  mutable color_palette : color list;
  base_palette : color list;
  dpi : int;
}

type folder =
  | Creature_Folder
  | GUI_Folder
  | Tile_Folder
  | Item_Folder

let font_size = ref 50
let text_color = rgb 68 68 68

let empty_sprite =
  {
    pixels = [];
    width = 0;
    height = 0;
    color_palette = [];
    base_palette = [];
    dpi = 1;
  }

let text_bg1 =
  ref
    {
      pixels = [];
      width = 0;
      height = 0;
      color_palette = [];
      base_palette = [];
      dpi = 1;
    }

let text_bg2 =
  ref
    {
      pixels = [];
      width = 0;
      height = 0;
      color_palette = [];
      base_palette = [];
      dpi = 1;
    }

let is_sticky = ref false
let erase_mode = ref false
let synced_mode = ref true

(* let blue = rgb 200 200 240 *)
let width = 800
let height = 720
let sync flag () = auto_synchronize flag
let usync flag () = if synced_mode.contents then auto_synchronize flag

let set_text_bg bg1 bg2 =
  text_bg1.contents <- bg1;
  text_bg2.contents <- bg2

let set_font_size size () =
  font_size.contents <- size;
  set_font
    ("-*-fixed-bold-r-semicondensed--" ^ string_of_int size
   ^ "-*-*-*-*-*-iso8859-1")

let get_dimension sprite = (sprite.width, sprite.height)
let get_font_size = font_size.contents
let set_sticky_text flag () = is_sticky.contents <- flag
let set_erase_mode flag () = erase_mode.contents <- flag
let set_synced_mode flag = synced_mode.contents <- flag

let sync_draw draw () =
  usync false ();
  draw ();
  usync true ()

let draw_pixel size x y () =
  fill_rect (x - (size / 2)) (y - (size / 2)) size size

let draw_from_pixels sprite x y min_w min_h max_w max_h () =
  let rec draw_from_pixels_rec pixels x y tx ty =
    match pixels with
    | [] -> set_color text_color
    | h :: t ->
        if h <> 0 && tx >= min_w && ty >= min_h then begin
          if erase_mode.contents then set_color (point_color 0 0)
          else set_color (List.nth sprite.color_palette (h - 1));

          draw_pixel sprite.dpi (x + tx) (y + ty) ()
        end;
        if ty < max_h then
          if tx < max_w - sprite.dpi then
            draw_from_pixels_rec t x y (tx + sprite.dpi) ty
          else draw_from_pixels_rec t x y 0 (ty + sprite.dpi)
        else set_color text_color
  in

  draw_from_pixels_rec sprite.pixels x y 0 0

let color_to_rgb color =
  let r = (color land 0xFF0000) asr 0x10
  and g = (color land 0x00FF00) asr 0x8
  and b = color land 0x0000FF in
  (r, g, b)

let rec find x lst =
  match lst with
  | [] -> -1
  | h :: t -> if x = h then 0 else 1 + find x t

let image_to_sprite (image : Image.image) =
  let rec pixel_map i j sprite =
    if i < image.height then
      let new_i, new_j =
        if j = 0 then (i + 1, image.width - 1) else (i, j - 1)
      in

      let pixels, palette = sprite in

      let color, alpha =
        Image.read_rgba image j i (fun r g b a () -> (rgb r g b, a)) ()
      in

      let new_pallette =
        if List.mem color palette = false then palette @ [ color ]
        else palette
      in

      if alpha > 0 then
        let index = find color new_pallette in
        pixel_map new_i new_j ((index + 1) :: pixels, new_pallette)
      else pixel_map new_i new_j (0 :: pixels, new_pallette)
    else sprite
  in
  pixel_map 0 (image.width - 1) ([], [])

(* no function for converting color back to rgb in Graphics *)

let load_image (image : Image.image) dpi =
  let pixels, palette = image_to_sprite image in
  let new_pallette = palette in

  {
    pixels;
    width = image.width * dpi;
    height = image.height * dpi;
    color_palette = new_pallette;
    base_palette = new_pallette;
    dpi;
  }

let load_sprite name folder dpi () =
  let filename =
    match folder with
    | Creature_Folder -> "assets/creature_sprites/" ^ name ^ ".png"
    | GUI_Folder -> "assets/gui_sprites/" ^ name ^ ".png"
    | Item_Folder -> "assets/item_sprites/" ^ name ^ ".png"
    | Tile_Folder -> "assets/tile_sprites/" ^ name ^ ".png"
  in
  let image = ImageLib_unix.openfile filename in
  load_image image dpi

let load_sprite_from_file filename dpi () =
  let image = ImageLib_unix.openfile filename in
  load_image image dpi

let load_creature name () =
  let filename = "assets/creature_sprites/" ^ name ^ ".png" in
  load_sprite_from_file filename 3 ()

let clear_sprite sprite x y () =
  usync false ();
  set_erase_mode true ();
  draw_from_pixels sprite x y 0 0 sprite.width sprite.height ();
  set_erase_mode false ();
  usync true ()

let draw_sprite_crop
    sprite
    x
    y
    (width_min, width_max)
    (height_min, height_max)
    () =
  usync false ();
  draw_from_pixels sprite x y width_min height_min width_max height_max
    ();
  usync true ()

let draw_sprite sprite x y () =
  usync false ();
  draw_from_pixels sprite x y 0 0 sprite.width sprite.height ();
  usync true ()

let draw_creature sprite player () =
  if player then draw_sprite sprite 50 166 ()
  else
    draw_sprite sprite
      (width - sprite.width - 50)
      (height - 50 - sprite.height)
      ()

let string_to_char_list s =
  let rec exp i l = if i < 0 then l else exp (i - 1) (s.[i] :: l) in
  exp (String.length s - 1) []

let remove_space text =
  if String.length text > 0 && String.sub text 0 1 = " " then
    String.sub text 1 (String.length text - 1)
  else text

let rec wait timer () =
  if is_sticky.contents = true || timer = 0 then ()
  else if Graphics.key_pressed () then begin
    if Graphics.read_key () = 'e' then ()
  end
  else wait (timer - 1) ()

let clear_text () =
  draw_sprite text_bg1.contents 3 0 ();
  draw_sprite text_bg2.contents 400 0 ()

let text_char_cap = ref 28
let auto_text_time = 175000
let set_text_char_cap cap = text_char_cap.contents <- cap

let draw_text text font_size auto () =
  set_font_size font_size ();
  let wait_time = if auto then auto_text_time else -1 in
  let char_cap = text_char_cap.contents in
  clear_text ();
  set_color text_color;
  let start_x = 35 in
  let start_y = 132 in
  moveto start_x start_y;
  let len = String.length text in
  let levels = len / char_cap in
  let rec scroll_text text start max =
    if start mod 2 = 0 then
      if start <> 0 && is_sticky.contents = false then begin
        wait wait_time ();
        clear_text ();
        set_color text_color
      end;
    if start <> max + 1 then begin
      let text = remove_space text in
      let short_text =
        if String.length text > char_cap then String.sub text 0 char_cap
        else text
      in
      let rest_text =
        if String.length text > char_cap then
          String.sub text char_cap
            (String.length text - String.length short_text)
        else ""
      in
      let char_list = string_to_char_list short_text in
      let rec draw_chars chars =
        match chars with
        | [] -> ()
        | h :: t ->
            set_color text_color;
            draw_char h;
            rmoveto (-15) 4;
            set_color white;
            draw_char h;
            rmoveto 2 (-4);
            set_color text_color;
            Input.sleep 0.025 ();
            draw_chars t
      in

      moveto start_x (start_y - (60 * (start mod 2)));
      draw_chars char_list;

      scroll_text rest_text (start + 1) max
    end
  in
  scroll_text text 0 levels;
  if levels <= 0 then wait wait_time ()

(* create a gradient of colors from black at 0,0 to white at w-1,h-1 *)
let gradient arr w h =
  for y = 0 to h - 1 do
    for x = 0 to w - 1 do
      let s = 255 * (x + y) / (w + h - 2) in
      arr.(y).(x) <- rgb s s s
    done
  done

let draw_gradient w h =
  (* w and h are flipped from perspective of the matrix *)
  let arr = Array.make_matrix h w white in
  gradient arr w h;
  draw_image (make_image arr) 0 0

let draw_string_colored x y dif text custom_color () =
  moveto x y;
  set_color text_color;
  draw_string text;
  moveto (x + dif - 1) (y + dif);
  set_color custom_color;
  draw_string text;
  set_color text_color

let damage_render sprite player () =
  let rec damage_render_rec c creature_pixels player () =
    if c = 0 then draw_creature creature_pixels player ()
    else begin
      if c mod 2 = 0 then draw_creature creature_pixels player ()
      else begin
        set_color blue;

        set_erase_mode true ();
        draw_creature creature_pixels player ();
        set_erase_mode false ()
      end;
      Input.sleep 0.1 ();
      damage_render_rec (c - 1) creature_pixels player ()
    end
  in
  damage_render_rec 7 sprite player ();
  set_color text_color

let add_rgb sprite red green blue () =
  let rec add_rgb_rec = function
    | [] -> []
    | h :: t ->
        let r, g, b = color_to_rgb h in
        rgb
          (Util.bound (r + red) 0 255)
          (Util.bound (g + green) 0 255)
          (Util.bound (b + blue) 0 255)
        :: add_rgb_rec t
  in
  sprite.color_palette <- add_rgb_rec sprite.color_palette

let reset_rgb sprite () = sprite.color_palette <- sprite.base_palette

(* let draw_creature_effect sprite player red green blue value () = let
   rec effect r g b = let rr = if r = 0 then 0 else if r > 1 then value
   else -value in let gg = if g = 0 then 0 else if g > 1 then value else
   -value in let bb = if b = 0 then 0 else if b > 1 then value else
   -value in add_rgb sprite rr gg bb (); draw_creature sprite player ();
   Input.sleep 0.05 (); if r > 0 || g > 0 || b > 0 then effect (r -
   value) (g - value) (b - value) else () in effect red green blue *)

let draw_creature_effect sprite player red green blue value () =
  let rec effect count =
    let rr = red / value in
    let gg = green / value in
    let bb = blue / value in
    add_rgb sprite rr gg bb ();
    draw_creature sprite player ();
    Input.sleep 0.025 ();
    if count > 0 then effect (count - 1) else ()
  in
  effect value

let lower_stat_effect sprite player () =
  for _ = 0 to 2 do
    draw_creature_effect sprite player (-100) (-100) 0 5 ();
    draw_creature_effect sprite player 80 80 0 5 ()
  done;
  reset_rgb sprite ();
  draw_creature sprite player ()

let raise_stat_effect sprite player () =
  for _ = 0 to 2 do
    draw_creature_effect sprite player 0 0 (-200) 5 ();
    draw_creature_effect sprite player 0 0 200 5 ()
  done;
  reset_rgb sprite ();
  draw_creature sprite player ()
