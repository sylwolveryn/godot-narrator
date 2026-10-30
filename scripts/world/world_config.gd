class_name WorldConfig
extends Resource
## Dimensions and look of the 3D world. Gameplay plane is XZ, y is up.
## The world materials encode data for the ASCII post-process (see shaders/world_encode.gdshader).

## World units per map cell.
@export var cell_size: float = 1.0
## Height of wall boxes.
@export var wall_height: float = 1.0
## Thickness of the floor slab (its top surface sits at y = 0).
@export var floor_thickness: float = 0.2

@export_group("Luminance")
## Lit materials (walls, floor) use this luminance in full light; the palette gradient turns it into a colour.
@export_range(0.0, 1.0) var wall_luminance: float = 0.75
@export_range(0.0, 1.0) var floor_luminance: float = 0.55
## Emissive items keep a fixed luminance whatever the light. Spikes and corruption pulse around
## the values in HazardFxConfig.
@export_range(0.0, 1.0) var item_luminance: float = 0.85

@export_group("Structure look")
## Face shading of walls (task-026): luminance factor of top faces, of side faces turned toward
## the player and of side faces turned away.
@export_range(0.0, 1.5) var face_top: float = 1.0
@export_range(0.0, 1.5) var face_side_lit: float = 0.9
@export_range(0.0, 1.5) var face_side_dark: float = 0.4
## Side faces darken toward the foot of the wall: factor at the foot (1 at the top).
@export_range(0.0, 1.0) var foot_shade: float = 0.55
## Box edges: width in world units and the luminance they add.
@export var edge_width: float = 0.14
@export_range(0.0, 1.0) var edge_boost: float = 0.5
## Per-glyph detail noise: frequency per world unit (about one glyph cell) and palette-offset amplitude.
@export var detail_scale: float = 7.0
@export var detail_amp: float = 0.45

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
