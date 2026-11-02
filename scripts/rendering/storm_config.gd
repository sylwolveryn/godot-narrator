class_name StormConfig
extends Resource
## Tuning of the glyph storm (task-030, from Spike B moment 4): the glyphs of the floor and walls around the player lift
## off at once, swirl around the player and settle back. Instance: resources/config/storm_config.tres, built by
## tools/build_storm.gd. Used by GlyphStormView; nothing here is read per frame.

@export_group("Trigger")
## Default reach of the storm (world units) and its duration in seconds (lift, swirl and settle of the last glyph).
@export var radius: float = 6.5
@export var duration: float = 2.6
## Glyphs closer than this to the centre are left alone (keeps the player readable).
@export var inner_radius: float = 1.1
## Instances drawn at the default radius (scaled with the area for other radii) and the capacity allocated up front.
## The MultiMesh is built once with `glyph_cap` instances; starting a storm only sets uniforms.
@export_range(1, 800) var glyph_count: int = 640
@export_range(1, 800) var glyph_cap: int = 800
## Tint of the storm per struck nature (the mood of the line that plays meanwhile) and the one used otherwise.
@export var nature_tints: Dictionary[StringName, Color] = {
	&"demonic": Color(1.0, 0.36, 0.26),
	&"ai": Color(0.38, 0.88, 1.0),
	&"angelic": Color(1.0, 0.9, 0.55),
	&"alien": Color(0.72, 0.5, 1.0),
}
@export var default_tint: Color = Color(0.85, 0.8, 1.0)

@export_group("Timeline")
## Shares of the duration: how long the take-off wave takes to cross the disc, the lift and the settle of one glyph
## (shares of its own flight).
@export_range(0.0, 0.6) var stagger_fraction: float = 0.3
@export_range(0.05, 0.6) var lift_fraction: float = 0.3
@export_range(0.05, 0.6) var settle_fraction: float = 0.34

@export_group("Swirl")
## Whole orbits around the player in one flight at the rim, plus extra ones at the inner edge (rounded per glyph so each
## lands where it started).
@export var swirl_turns: float = 1.0
@export var inner_turn_boost: float = 1.0
## 1 = all glyphs orbit one way, -1 = the other.
@export_range(-1.0, 1.0) var swirl_direction: float = 1.0
## How far the orbit widens at the top of the flight (fraction of the start radius).
@export var spiral_out: float = 0.3
## How far the storm centre follows the player at the top of the flight (0 = stays where it started, 1 = follows).
@export_range(0.0, 1.0) var follow: float = 1.0
## Vertical wave along the orbit (world units).
@export var wobble: float = 0.3
## Partial turn of each glyph in flight (fraction of a turn, back to upright when it lands).
@export var spin_amount: float = 0.35

@export_group("Height and size")
## Highest point of the flight above the ground (world units) and the random share taken off it per glyph.
@export var peak_height: float = 2.6
@export_range(0.0, 1.0) var height_variation: float = 0.5
## Height of a glyph lying on the floor, above it.
@export var ground_lift: float = 0.03
## Half size of a glyph on the ground and in the air (world units), and the scale pop on the way.
@export var size_ground: float = 0.1
@export var size_air: float = 0.28
@export_range(0.0, 1.0) var size_variation: float = 0.4
@export var pop: float = 0.25

@export_group("Look")
## Fonts the storm glyphs are rasterised with (first available), weight.
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
@export_range(100, 900) var font_weight: int = 700
@export_range(0.2, 1.0) var glyph_fill: float = 0.8
@export_range(0.0, 0.2) var outline_width: float = 0.08
@export var outline_color: Color = Color(0.01, 0.005, 0.03, 1.0)
## Glyphs borrowed from the floor and the walls, and the ones the storm turns them into.
@export var floor_source_glyphs: String = ".,:;'`"
@export var wall_source_glyphs: String = "#=%"
@export var storm_glyphs: String = "*+x~o:;<>^"
## Colour while on the ground (floor, wall) and in the air; `tint_mix` is how much of the nature tint the air colour takes.
@export var floor_color: Color = Color(0.36, 0.4, 0.62)
@export var wall_color: Color = Color(0.45, 0.58, 0.9)
@export var air_color: Color = Color(0.82, 0.88, 1.0)
@export_range(0.0, 1.0) var tint_mix: float = 0.6
## Brightness of a remembered (not currently seen) cell's glyphs relative to a seen one.
@export_range(0.0, 1.0) var memory_brightness: float = 0.55
## Soft glow around airborne glyphs (kept low, it never flickers).
@export_range(0.0, 1.5) var glow_strength: float = 0.35
@export_range(0.0, 1.0) var air_alpha: float = 0.95

@export_group("Surroundings")
## The floor and walls within the storm dim to this fraction while their glyphs are away; ramp in and out (seconds) and the
## extra radius of the dim beyond the storm radius.
@export_range(0.0, 1.0) var dim_amount: float = 0.7
@export var dim_in: float = 0.45
@export var dim_out: float = 0.8
@export var dim_radius_extra: float = 1.0
