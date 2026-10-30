class_name AsciiConfig
extends Resource
## Tunables for the ASCII post-process (docs/visual_direction.md section 7).
## Instance: resources/config/ascii_config.tres.

## Master switch. When false the post shader is hidden (the raw 3D render holds encoded data,
## so this is a debug aid only).
@export var enabled: bool = true
## Size of one glyph cell in pixels at the DisplayConfig reference resolution (scaled at runtime).
@export var cell_size: Vector2i = Vector2i(10, 14)

@export_group("Glyph atlas")
## Preferred monospace system fonts (drawn bold), first available wins.
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Courier New", "monospace"])
## Atlas tile width in pixels. The tile height follows the cell aspect ratio.
@export var atlas_glyph_px: int = 32
## Distance (atlas px) over which the signed distance field is stored around the glyph edge.
@export var sdf_spread_px: int = 4
## Font size as a multiple of the atlas tile width.
@export var atlas_font_scale: float = 1.1
## The atlas is rasterised at this multiple of its final size before the distance pass (corner quality).
@export_range(1, 4) var atlas_supersample: int = 2

@export_group("Glyph ramps")
## Ramps are ordered sparse to dense; the type is readable from the shape alone.
@export var ramp_floor: String = " .·:;"
@export var ramp_wall: String = ".:=+*#%@"
@export var ramp_item: String = ".:o*$"
@export var ramp_spikes: String = ".,'^A"
@export var ramp_corruption: String = ".~?§&%"
## Abstract set used by morphing effects (narration, death). A circle SDF is always added.
@export var abstract_glyphs: String = "·-~°"

@export_group("Morph and edge")
## Half-width of the ramp blend around a step: glyphs stay crisp outside it.
@export_range(0.01, 0.5) var morph_band: float = 0.25
## SDF edge softness near the player and far from it (0..1 of the SDF range).
@export var edge_soft_near: float = 0.06
@export var edge_soft_far: float = 0.22
## Distance from the player (glyph cells) where the depth-of-field softening starts.
@export var dof_start_cells: float = 8.0
## Share of the colour that slides toward the background at full depth of field.
@export_range(0.0, 1.0) var dof_color_slide: float = 0.2

@export_group("Glow")
## Own-cell halo falloff (SDF units) and strength.
@export var glow_radius: float = 0.35
@export var glow_strength: float = 0.8
## Cross-cell bloom from the 4 neighbouring cell centres.
@export var bloom_enabled: bool = true
@export var bloom_radius_cells: float = 1.2
@export var bloom_strength: float = 0.2
## Glow weight per material id (0 void, 1 wall, 2 floor, 3 item, 4 spikes, 5 corruption, 6-7 unused).
## Walls use the rim rule instead; remembered cells never glow.
@export var glow_weights: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0])
## Rim glow on walls inside the player light (0 disables it).
@export var wall_rim_strength: float = 0.5

@export_group("Depth")
@export var vignette_strength: float = 0.35
@export_range(0.0, 1.0) var vignette_radius: float = 0.75

@export_group("Colour variation")
## Static world-space value noise that drifts the palette position.
@export var hue_noise_scale: float = 0.08
@export var hue_noise_amp: float = 0.15
## Extra noise octave (ten times finer) as a fraction of hue_noise_amp, for texture inside a wall.
@export var hue_noise_detail: float = 1.0
@export var height_amp: float = 0.2

@export_group("Memory")
## Remembered cells use at most this share of their glyph ramp.
@export_range(0.0, 1.0) var memory_density_cap: float = 0.45
## Share of the type colour mixed into the memory colour.
@export_range(0.0, 1.0) var memory_type_mix: float = 0.15
