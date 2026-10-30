class_name MapCell
extends Area3D
## Placeholder trigger volume for an item or hazard cell. Later tasks (reveal, hazard death)
## hook onto `cell_type` and `cell`; this class holds no gameplay logic.

## One of the MapLegend cell type constants (item, spikes, corrupt).
@export var cell_type: StringName = &""
## Grid coordinates of the cell in the map.
@export var cell: Vector2i = Vector2i.ZERO
