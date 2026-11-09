class_name DeathMarksConfig
extends Resource
## Death marks (task-093): the purple / red stains a death sprays over the floor and walls, the invulnerability item
## they pay out, the invulnerability itself and the energy-shield aura drawn while it lasts.
## Instance: resources/config/death_marks_config.tres (tools/build_resources.gd).

@export_group("Stain")
## Cells within this distance (in cells, from the death cell's centre) are sprayed: floor and walls alike.
@export_range(0.5, 8.0, 0.1) var stain_radius: float = 1.5
## Stain added to a cell by one death at its centre (fading towards the edge of the radius); a cell holds at most 1.
@export_range(0.05, 1.0, 0.01) var stain_strength: float = 0.75
## Share of the strength kept at the edge of the radius.
@export_range(0.0, 1.0, 0.01) var stain_edge: float = 0.45
@export var stain_purple: Color = Color(0.62, 0.18, 1.0)
@export var stain_red: Color = Color(1.0, 0.12, 0.2)
## How much a stain takes the glyphs over (0 = invisible, 1 = fully the stain hue at full strength).
@export_range(0.0, 1.0, 0.01) var stain_mix: float = 0.85
## Extra glyph density on a stained cell at full strength (the spray makes the cell busier).
@export_range(0.0, 1.0, 0.01) var stain_density: float = 0.35
## Slow shimmer of the stain hue between purple and red, cycles per second.
@export_range(0.0, 2.0, 0.01) var stain_shimmer_hz: float = 0.12

@export_group("Invulnerability item")
## Every time the stained-tile count passes another multiple of this, the death that did it drops an item.
@export_range(1, 1000, 1) var tiles_per_item: int = 10
## The item is placed on a free walkable, harmless cell within this many steps of the death cell.
@export_range(0, 10, 1) var item_scatter_radius: int = 3
@export var item_glyph: String = "⚛"
@export var item_color: Color = Color(0.55, 0.9, 1.0)
@export var item_size: float = 0.24
@export var item_hover: float = 0.4
@export var item_bob: float = 0.07
@export var item_bob_hz: float = 0.9
@export var item_glow: float = 0.8
## Seconds the item takes to fly out of the death spot to its cell.
@export var item_throw_seconds: float = 0.6
@export var item_throw_height: float = 1.0

@export_group("Invulnerability")
## Seconds of invulnerability one item gives (counted while a run is being played). Another item adds to it.
@export_range(1.0, 3600.0, 1.0) var invulnerable_seconds: float = 600.0
## Cause recorded on an enemy that touched an invulnerable player.
@export var enemy_kill_cause: StringName = &"invulnerable"

@export_group("Shield aura")
## The glyphs of one ring, in order around it. Two rings are drawn.
@export var ring_text: String = "⋆˖⁺‧₊☽◯☾₊‧⁺˖⋆"
@export var ring_radii: PackedFloat32Array = PackedFloat32Array([0.62, 0.74])
## Tilt of each ring's plane from the floor, degrees (opposite tilts cross like an atom's orbits).
@export var ring_tilts: PackedFloat32Array = PackedFloat32Array([62.0, -62.0])
## Spin of each ring inside its plane, degrees per second.
@export var ring_speeds: PackedFloat32Array = PackedFloat32Array([75.0, -95.0])
## The planes themselves turn around the up axis (degrees per second), so the shield rolls in 3D.
@export var precession_speed: float = 24.0
## Centre of the rings above the player's feet.
@export var shield_height: float = 0.38
## Half-size of one shield glyph (smaller than the world glyphs).
@export var shield_glyph_size: float = 0.15
@export var shield_color: Color = Color(0.55, 0.85, 1.0)
@export_range(0.0, 1.0, 0.01) var shield_glow: float = 0.95
## Glyphs on the far side of the player are dimmed and shrunk to this share (depth cue).
@export_range(0.0, 1.0, 0.01) var shield_back_alpha: float = 0.5
@export_range(0.0, 1.0, 0.01) var shield_back_size: float = 0.75
## Brightness breathing of the shield.
@export var shield_pulse: float = 0.18
@export var shield_pulse_hz: float = 0.8
## In the last seconds of invulnerability the shield flickers as a warning.
@export var shield_warn_seconds: float = 10.0
@export var shield_warn_hz: float = 4.0

@export_group("Glyph atlas")
@export var glyph_font_names: PackedStringArray = PackedStringArray(["Segoe UI Symbol", "Segoe UI", "DejaVu Sans", "monospace"])
@export var glyph_tile_px: int = 48
@export var glyph_font_px: int = 40
