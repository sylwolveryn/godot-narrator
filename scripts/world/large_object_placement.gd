class_name LargeObjectPlacement
extends RefCounted
## One merged multi-cell map object (task-058): its type (MapLegend.large_objects key) and footprint in cells.

var type: StringName = &""
## Footprint in map cells (position = top-left cell, size = cells wide / deep).
var rect: Rect2i = Rect2i()


func _init(object_type: StringName = &"", footprint: Rect2i = Rect2i()) -> void:
	type = object_type
	rect = footprint


## True when the cell lies inside the footprint.
func has_cell(cell: Vector2i) -> bool:
	return rect.has_point(cell)
