class_name MapData
extends RefCounted
## A parsed map: a rectangular grid of cell types plus the spawn cell and any
## problems found while parsing. Pure data; contains no nodes.

var width: int = 0
var height: int = 0
## Row-major cell types, length width * height.
var types: Array[StringName] = []
var spawn_cell: Vector2i = Vector2i.ZERO
var has_spawn: bool = false
## Start cells of the small pushable objects (legend OBJECT), row-major; the object id is the index. The cells hold floor in `types`.
var objects: Array[Vector2i] = []
## Merged multi-cell props (task-058), row-major by top-left cell. Their cells hold the prop type in `types`.
var large_objects: Array[LargeObjectPlacement] = []
## Working teleports (task-068), row-major by top-left cell; their cells (ring and centre) hold floor in `types`.
var teleports: Array[TeleportPad] = []
## Broken teleport groups (T cells that do not form an exact ring with a channel centre); their cells hold floor.
var broken_teleports: Array[TeleportPad] = []
## Cell types that block light besides walls and void (large props with LargeObjectDef.blocks_light).
var light_blocking_types: Dictionary[StringName, bool] = {}
## Errors make the map unusable or degrade it (e.g. missing file, no spawn).
var errors: PackedStringArray = PackedStringArray()
## Warnings are recoverable oddities (unknown char, ragged rows).
var warnings: PackedStringArray = PackedStringArray()


func is_empty() -> bool:
	return width <= 0 or height <= 0


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func type_at(cell: Vector2i) -> StringName:
	if not in_bounds(cell):
		return MapLegend.VOID
	return types[cell.y * width + cell.x]


func set_type(cell: Vector2i, type: StringName) -> void:
	types[cell.y * width + cell.x] = type


## The merged prop covering a cell, null when there is none (destroyed props cover nothing).
func large_object_at(cell: Vector2i) -> LargeObjectPlacement:
	for placement in large_objects:
		if not placement.destroyed and placement.has_cell(cell):
			return placement
	return null


## Index (into `teleports`) of the working (not destroyed) pad whose centre is `cell`, -1 when none.
func teleport_at_centre(cell: Vector2i) -> int:
	for i in teleports.size():
		if teleports[i].centre == cell and not teleports[i].destroyed:
			return i
	return -1
