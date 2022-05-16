(** The executor of the overworld

    This module orchestrates the gameplay in the overworld*)

val tile_dpi : int
val load_assets : unit -> unit

val run_overworld : Saves.save_preview -> unit
(** [run_overworld _] runs the overworld. *)
