class_name GlyphFxConfig
extends Resource
## Presentation tuning for the player's overlay glyph under erosion and at death.
## Instance: resources/config/glyph_fx_config.tres.

@export_group("Erosion")
## Substitute glyphs the eroding identity flickers through.
@export var scramble_glyphs: String = "#%&@$?!/|<>=+*~^;:"
## Erosion fraction below which the glyph is still untouched.
@export_range(0.0, 1.0) var scramble_start: float = 0.05
## Substitution attempts per second at erosion 0 (just started) and 1 (about to die).
@export var scramble_rate_low: float = 4.0
@export var scramble_rate_high: float = 30.0
## Probability of showing a substitute glyph at erosion 1 (scales linearly from 0 at scramble_start).
@export_range(0.0, 1.0) var scramble_chance_max: float = 0.95
## Largest positional jitter in reference pixels (scaled at runtime), reached at erosion 1.
@export var jitter_max: float = 14.0
## Glyph opacity at erosion 1 (1 at no erosion).
@export_range(0.0, 1.0) var fade_min_alpha: float = 0.45
## How strongly the hazard tint replaces the glyph colour at erosion 1.
@export_range(0.0, 1.0) var tint_strength: float = 0.85

@export_group("Death")
## Seconds the death presentation takes; keep at or below RunConfig.restart_delay.
@export var death_duration: float = 1.1
## Fragments the glyph breaks into.
@export var shard_count: int = 14
## Distance in reference pixels a shard drifts, and the random spread around that.
@export var shard_distance: float = 180.0
@export_range(0.0, 1.0) var shard_distance_spread: float = 0.5
## Shard glyph size as a fraction of the identity glyph size.
@export var shard_size_ratio: float = 0.55
## Seconds the glyph flickers violently before it bursts.
@export var shatter_flash: float = 0.18
