class_name WorldConfig
extends Resource
## Dimensions and look of the 3D world. Gameplay plane is XZ, y is up.
## Geometry values feed WorldMeshBuilder (glyph-surface world, task-031). The luminance values and
## the cone/plane spike and corruption values are legacy (post-process world), removed with task-035.

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

@export_group("Glyph world geometry")
## Item pillar: half width as a fraction of cell_size, and height.
@export_range(0.05, 0.5) var item_pillar_half: float = 0.16
@export var item_pillar_height: float = 0.95
## Spike pyramids: grid per axis, half base as a fraction of cell_size, and height.
@export_range(1, 4) var spike_pyramid_grid: int = 2
@export_range(0.02, 0.25) var spike_pyramid_half: float = 0.13
@export var spike_pyramid_height: float = 0.38
## Corruption columns: grid per axis, half width as a fraction of cell_size.
@export_range(1, 4) var corrupt_grid: int = 2
@export_range(0.02, 0.25) var corrupt_column_half: float = 0.19
## Chance (0..1) that a corruption sub-cell stays empty.
@export_range(0.0, 1.0) var corrupt_gap_chance: float = 0.25
## Corruption column height: min + random(0..1) * random(0..1) * span.
@export var corrupt_column_min: float = 0.12
@export var corrupt_column_span: float = 0.55
