class_name GlyphFxConfig
extends Resource
## Presentation tuning for the player's in-world glyph (PlayerGlyphView): how big it stands in the
## world, its halo, and how it looks under erosion and at death.
## Instance: resources/config/glyph_fx_config.tres.

@export_group("In-world glyph")
## Height of the glyph on screen, in world units (orthographic size scale).
@export var glyph_size: float = 1.3
## Fraction of the glyph's quad the glyph tile covers; the rest of the quad carries the halo.
@export_range(0.1, 1.0) var glyph_fill: float = 0.42
## The glyph quad is pushed this far towards the camera so the floor and low walls never clip it.
@export var lift: float = 0.9
## Edge of one tile of the runtime glyph atlas, in pixels.
@export var atlas_tile_px: int = 128
## Font size as a fraction of the atlas tile.
@export_range(0.1, 1.0) var font_fill: float = 0.72
## Dark backing around the glyph that keeps it readable on glyph-covered walls: width as a fraction of the glyph tile, colour.
@export_range(0.0, 0.2) var outline_width: float = 0.035
@export var outline_color: Color = Color(0.015, 0.01, 0.03, 0.9)

@export_group("Player halo")
## Peak brightness of the soft warm halo around the glyph (its colour is the player light colour).
@export var halo_intensity: float = 0.75
## 0 = round bloom around the glyph, 1 = the glow pools on the floor under it.
@export_range(0.0, 1.0) var halo_pool: float = 0.35
## The halo breathes by this fraction of its brightness, once per halo_breath_period seconds (keep slow: at most 0.5 Hz, +-0.25).
@export_range(0.0, 0.25) var halo_breath_amount: float = 0.08
@export var halo_breath_period: float = 4.0

@export_group("Erosion")
## Substitute glyphs the eroding identity morphs into (picked at random, one at a time).
@export var scramble_glyphs: String = "#%&@$?!/|<>=+*~^;:"
## Erosion fraction below which the glyph is still untouched.
@export_range(0.0, 1.0) var scramble_start: float = 0.05
## Share of the substitute glyph blended into the identity at erosion 1 (the blend is continuous).
@export_range(0.0, 1.0) var glyph_blend_max: float = 0.85
## Seconds a change of the substitute glyph takes (a crossfade, never a cut). Keep below erosion_retarget_min.
@export var corrupt_morph_time: float = 0.9
## Largest horizontal/vertical warp of the glyph at erosion 1, as a fraction of the glyph size.
@export var warp_max: float = 0.07
## Seconds of one slow warp wave.
@export var warp_period: float = 3.2
## Offset of the violet ghost image beside the glyph at erosion 1, as a fraction of the glyph size.
@export var ghost_offset: float = 0.09
## Glyph opacity at erosion 1 (1 at no erosion).
@export_range(0.0, 1.0) var fade_min_alpha: float = 0.6
## How strongly the hazard tint replaces the glyph colour at erosion 1.
@export_range(0.0, 1.0) var tint_strength: float = 0.85
## Seconds a shed fragment drifts and fades, and how far (in cells) it travels.
@export var shed_lifetime: float = 1.0
@export var shed_distance_cells: float = 1.0

@export_group("Death")
## Seconds the death presentation takes; keep at or below RunConfig.restart_delay.
@export var death_duration: float = 1.1
## Distance of a fragment from the centre varies by up to this fraction of death_spread_cells.
@export_range(0.0, 1.0) var shard_distance_spread: float = 0.5
## Fragment glyph size as a fraction of the identity glyph size.
@export var shard_size_ratio: float = 0.55
## Seconds the glyph shows its fully eroded look before it bursts.
@export var shatter_flash: float = 0.18

@export_group("Erosion and death (task-025)")
@export var erosion_tint: Color = Color("#B44DFF")
## A new substitute glyph is chosen at most this often (seconds).
@export var erosion_retarget_min: float = 1.5
## Above this erosion fraction the glyph sheds a fragment every erosion_shed_interval seconds.
@export_range(0.0, 1.0) var erosion_shed_threshold: float = 0.5
@export var erosion_shed_interval: float = 0.8
## Fragments the glyph breaks into at death, and how far they fly (cells).
@export var death_fragments: int = 10
@export var death_spread_cells: float = 1.5
@export_range(0.0, 1.0) var death_world_dim: float = 0.4
@export var death_dim_time: float = 0.8
@export var spike_death_flash: float = 0.3
## Seconds the displayed erosion level takes to travel its full range (smooths the pre-burst flash).
@export var flash_rise: float = 0.15
@export var flash_decay: float = 0.4
