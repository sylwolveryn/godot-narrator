class_name GlyphAnimConfig
extends Resource
## Fixed layout of the DB-driven glyph animation (task-054). The animation values themselves (characters, palette,
## intensities, speeds) live in the DB table `glyph_anim`, one row per surface. Instance: resources/config/glyph_anim_config.tres.

## DB `surface` id per GlyphSurfaceType (index = surface type id).
@export var surface_ids: PackedStringArray = PackedStringArray(["wall", "floor", "spikes", "corruption", "item"])
## Characters per surface baked into the animation atlas (the shader's ANIM_COLS); extra characters are ignored.
@export var max_chars: int = 8
## Palette colours per surface (the shader's ANIM_PAL); extra colours are ignored.
@export var max_palette: int = 6
## Atlas cell and font size in pixels, and the baseline drop as a share of the font size (as in GlyphAtlasSpec).
@export var cell_px: int = 32
@export var font_px: int = 28
@export var baseline_drop: float = 0.34
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
## Brightness of an animated glyph: lerps from `dim` (unlit) to `bright` (fully lit) with the cell's light.
@export var brightness_dim: float = 0.55
@export var brightness_bright: float = 1.25
