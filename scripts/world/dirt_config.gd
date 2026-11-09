class_name DirtConfig
extends Resource
## Dirt walls `D` (task-070): data (chunks, eating, the devour milestones), look (palette, crumble, dust fragments) and
## the crunch sound. Instance: resources/config/dirt_config.tres (tools/build_resources.gd).

@export_group("Data")
## Dirt is kept in square chunks of this many cells per side: removing a cell rebuilds only the collision of its chunk
## and the meshes of its chunk (and of a neighbouring chunk when the cell is on a chunk edge).
@export_range(4, 64) var chunk_size: int = 16
## The persistent eaten counter fires WALLS_DEVOURED every random gap in [milestone_min, milestone_max] eaten cells
## (the gap is re-rolled after every milestone and stored in the save).
@export var milestone_min: int = 100
@export var milestone_max: int = 200

@export_group("Look")
## Earthy palette of the dirt glyphs (replaces the wall palette on dirt faces), dark (unlit) to bright (lit).
@export var palette_dark: Color = Color(0.20, 0.12, 0.06)
@export var palette_bright: Color = Color(0.66, 0.42, 0.20)
## Static brightness variation per glyph cell (+- this fraction): lumpy earth instead of masonry blocks.
@export_range(0.0, 1.0) var variation: float = 0.38
## Seconds an eaten cell takes to sink into the floor.
@export var crumble_duration: float = 0.35
## Crumbling blocks drawn at the same time (pool size; the oldest is cut short when more are eaten at once).
@export_range(1, 32) var crumble_capacity: int = 8
## Share of its height a crumbling block keeps at the start (it sinks from here to 0).
@export_range(0.1, 1.0) var crumble_start_scale: float = 0.96

@export_group("Dust fragments")
## Glyph fragments thrown up and falling per eaten cell, and the pool size.
@export var fragments_per_eat: int = 10
@export var fragment_capacity: int = 64
@export var fragment_chars: String = ".,:;'`%#"
@export var fragment_lifetime: float = 0.65
## Half-size of a fragment glyph (world units), sideways speed, upward start speed and gravity (units/s, units/s^2).
@export var fragment_size: float = 0.24
@export var fragment_spread: float = 1.3
@export var fragment_rise: float = 1.8
@export var fragment_gravity: float = 9.0
## Height the fragments start at, as a share of the wall height (above 1: they burst out over the dirt tops).
@export_range(0.0, 2.0) var fragment_start_height: float = 1.1
@export var fragment_color: Color = Color(0.95, 0.68, 0.38)
@export var fragment_rim: Color = Color(1.0, 0.85, 0.6)
@export var fragment_tile_px: int = 48
@export var fragment_font_px: int = 40
@export var fragment_font_names: PackedStringArray = PackedStringArray(["Consolas", "Courier New", "monospace"])

@export_group("Sound")
## Override file: <override folder>/<path>, else <game folder>/<path>, else res://<path>; none = the synthesized crunch.
@export var crunch_file: String = "sfx/dirt_crunch.mp3"
@export var crunch_volume_db: float = -35.0
## Random pitch per eat: 1 +- this.
@export_range(0.0, 0.5) var crunch_pitch_jitter: float = 0.12
## Crunches closer together than this (seconds) are skipped.
@export var crunch_min_interval: float = 0.07
## Synthesis: length (s), number of noise grains, decay of a grain (s), low-pass smoothing (0 = none, near 1 = dull).
@export var crunch_duration: float = 0.18
@export var crunch_grains: int = 9
@export var crunch_grain_decay: float = 0.012
@export_range(0.0, 0.95) var crunch_lowpass: float = 0.45
@export var crunch_sample_rate: int = 22050
@export var crunch_bus: StringName = &"Master"
