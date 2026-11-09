class_name DeathMarksConfig
extends Resource
## Death marks (task-093, task-104): the crimson stains a death sprays over the floor and walls, the invulnerability item
## they pay out, the invulnerability itself and the energy-shield aura drawn while it lasts.
## Instance: resources/config/death_marks_config.tres (tools/build_resources.gd).

@export_group("Stain")
## Fallback splat radius range in tiles, used only when the DB table `death_splat` has neither a row for the form nor
## a "default" row (task-104; the DB is authoritative). Cells within the picked radius of the death cell's centre are
## sprayed: floor and walls alike.
@export_range(0.5, 12.0, 0.1) var fallback_radius_min: float = 2.0
@export_range(0.5, 12.0, 0.1) var fallback_radius_max: float = 4.0
## Stain added to a cell by one death at its centre (fading towards the edge of the radius); a cell holds at most 1.
@export_range(0.05, 1.0, 0.01) var stain_strength: float = 0.75
## Share of the strength kept at the edge of the radius.
@export_range(0.0, 1.0, 0.01) var stain_edge: float = 0.45
## Death stains and blood trail marks (task-104: crimson, readable on the floor).
@export var stain_blood: Color = Color(0.92, 0.03, 0.14)
## Black hole trail marks (task-104).
@export var stain_void: Color = Color(0.42, 0.08, 0.78)
## How much a stain takes the glyphs over (0 = invisible, 1 = fully the stain hue at full strength).
@export_range(0.0, 1.0, 0.01) var stain_mix: float = 1.0
## Extra glyph density on a stained cell at full strength (the spray makes the cell busier).
@export_range(0.0, 1.0, 0.01) var stain_density: float = 0.5
## Slow brightness shimmer of the stain, cycles per second.
@export_range(0.0, 2.0, 0.01) var stain_shimmer_hz: float = 0.12
## Flat wash of the stain hue over the whole cell (not only its glyphs), at full strength: sparse floors still read.
@export_range(0.0, 1.0, 0.01) var stain_fill: float = 0.28

@export_group("Trail tint")
## Seconds the trail stays tinted after the player left the last stained cell / black hole.
@export_range(0.0, 30.0, 0.1) var trail_tint_linger: float = 3.0
## Stain strength a tinted trail leaves on a cell it enters (a cell holds at most 1).
@export_range(0.0, 1.0, 0.01) var trail_mark_strength: float = 0.55
## Chance that a step also spatters a random neighbour cell, at trail_spatter_share of the strength.
@export_range(0.0, 1.0, 0.01) var trail_spatter_chance: float = 0.4
@export_range(0.0, 1.0, 0.01) var trail_spatter_share: float = 0.6
## Ink colours of the trail drops while tinted (InkTrailView); the rim is a lighter shade of the same hue.
@export var trail_blood_ink: Color = Color(0.95, 0.05, 0.16)
@export var trail_void_ink: Color = Color(0.5, 0.1, 0.9)

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
