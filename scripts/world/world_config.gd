class_name WorldConfig
extends Resource
## Dimensions and look of the 3D world. Gameplay plane is XZ, y is up.
## Colours are unshaded albedo: their luminance decides which ASCII glyph the post-process picks.

## World units per map cell.
@export var cell_size: float = 1.0
## Height of wall boxes.
@export var wall_height: float = 1.0
## Thickness of the floor slab (its top surface sits at y = 0).
@export var floor_thickness: float = 0.2

@export_group("Colours")
@export var wall_color: Color = Color(0.42, 0.5, 0.62)
@export var floor_color: Color = Color(0.05, 0.06, 0.05)
@export var item_color: Color = Color(1.0, 0.85, 0.3)
@export var spike_color: Color = Color(1.0, 0.3, 0.25)
@export var corrupt_color: Color = Color(0.85, 0.25, 0.95)

@export_group("Items and hazards")
## Edge length of an item cube as a fraction of cell_size.
@export_range(0.05, 1.0) var item_size_ratio: float = 0.35
## Height of an item above the floor, in world units.
@export var item_height: float = 0.4
## Spikes are drawn as a grid of cones: cones per axis.
@export_range(1, 6) var spike_grid: int = 3
## Spike cone height in world units.
@export var spike_height: float = 0.5
## Spike cone base radius as a fraction of one sub-cell.
@export_range(0.1, 1.0) var spike_radius_ratio: float = 0.4
## Height of the corrupting-glyph plane above the floor.
@export var corrupt_height: float = 0.02
## Pulse speed (radians per second) and depth (0..1) of the corrupting patches' brightness.
@export var corrupt_pulse_speed: float = 3.0
@export_range(0.0, 1.0) var corrupt_pulse_depth: float = 0.5
