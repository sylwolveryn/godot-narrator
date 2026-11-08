class_name RemainsConfig
extends Resource
## Enemy remains (task-076): diamonds and black holes, their look and the pickup sound. Instance:
## resources/config/remains_config.tres (tools/build_resources.gd). How many diamonds an enemy bursts into and whether
## it leaves a black hole is per enemy kind (EnemyDef.diamonds / black_hole, DB enemy_def).

@export_group("Diamonds")
## Diamonds land on free cells (enemy-walkable, no diamond, no black hole) within this many steps of the enemy's cell.
@export var scatter_radius: int = 3
## Most diamonds lying on the map at once (older ones are kept, new ones beyond it are not spawned).
@export var max_diamonds: int = 256
@export var diamond_glyph: String = "◆"
@export var sparkle_glyph: String = "✦"
@export var diamond_color: Color = Color(0.45, 0.95, 1.0)
@export var sparkle_color: Color = Color(1.0, 1.0, 1.0)
## Half-size (world units), height above the floor, bob (world units) and bob speed (Hz).
@export var diamond_size: float = 0.2
@export var diamond_hover: float = 0.35
@export var diamond_bob: float = 0.06
@export var diamond_bob_hz: float = 1.1
## Glint: every `glint_period` seconds (per diamond phase) a short flash of `glint_seconds` with a sparkle glyph.
@export var glint_period: float = 2.2
@export var glint_seconds: float = 0.35
@export var sparkle_size: float = 0.14
## Burst: seconds a diamond flies from the destroyed enemy to its cell, and the arc height (world units).
@export var burst_seconds: float = 0.5
@export var burst_height: float = 0.9

@export_group("Black hole")
## Glyph rings around the dark core, inside out: glyphs per ring, ring radius (world units), turn speed (degrees per
## second; the sign alternates the direction), the ring's glyph characters (cycled) and its colour.
@export var ring_counts: PackedInt32Array = PackedInt32Array([6, 10, 14])
@export var ring_radii: PackedFloat32Array = PackedFloat32Array([0.24, 0.4, 0.58])
@export var ring_speeds: PackedFloat32Array = PackedFloat32Array([220.0, -140.0, 90.0])
@export var ring_chars: PackedStringArray = PackedStringArray(["@*", "+:", ".,'"])
@export var ring_colors: PackedColorArray = PackedColorArray([Color(1.0, 0.65, 1.0), Color(0.8, 0.45, 1.0), Color(0.55, 0.35, 1.0)])
## Ring glyph half-size (world units, shrinking outward by ring_size_falloff per ring) and height above the floor.
@export var ring_glyph_size: float = 0.15
@export var ring_size_falloff: float = 0.15
@export var ring_hover: float = 0.3
## Rings pulse in and out by this share of their radius at pulse_hz.
@export var ring_pulse: float = 0.12
@export var ring_pulse_hz: float = 0.7
@export var core_glyph: String = "●"
@export var core_color: Color = Color(0.0, 0.0, 0.01)
@export var core_size: float = 0.36
## Height of the core's centre: a camera-facing glyph must stand above the floor or the floor hides its lower half.
@export var core_hover: float = 0.5
## A wider, softer dark disc behind the core (half-size, opacity).
@export var core_shade_size: float = 0.6
@export var core_shade_alpha: float = 0.55
## Seconds a newly formed hole grows to full size.
@export var form_seconds: float = 0.6
## Most black holes drawn.
@export var max_holes: int = 48

@export_group("Look")
@export var glyph_font_names: PackedStringArray = PackedStringArray(["Segoe UI Symbol", "Consolas", "DejaVu Sans", "monospace"])
@export var glyph_tile_px: int = 48
@export var glyph_font_px: int = 40

@export_group("Pickup sound")
## Played when it exists (override folder, game folder, res://), else a short synthesized "ting".
@export var pickup_file: String = "sfx/diamond_pickup.mp3"
@export var pickup_bus: StringName = &"Master"
@export var pickup_volume_db: float = -8.0
@export var pickup_sample_rate: int = 22050
@export var pickup_duration: float = 0.28
## Two sine partials gliding from freq to freq * pickup_glide, decaying with pickup_decay seconds.
@export var pickup_freq: float = 1320.0
@export var pickup_freq_2: float = 1980.0
@export var pickup_glide: float = 1.25
@export var pickup_decay: float = 0.08
@export var pickup_pitch_jitter: float = 0.06
