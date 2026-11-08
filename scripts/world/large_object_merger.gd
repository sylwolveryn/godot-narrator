class_name LargeObjectMerger
extends RefCounted
## Merges adjacent cells of a mergeable (large object) type into rectangles (task-058). Row-major scan: an unassigned
## cell starts a rectangle, which grows right while the cells have the same type, then down while the whole row
## segment matches; its cells are then assigned. `GG` -> one 2x1, `GG\nGG` -> one 2x2; an L-shape becomes two
## rectangles; different types never merge. Pure data.


## Rectangles (in cells) of every mergeable type of the map, row-major by their top-left cell.
static func merge(map: MapData, mergeable: Dictionary) -> Array[LargeObjectPlacement]:
	var out: Array[LargeObjectPlacement] = []
	if map.is_empty() or mergeable.is_empty():
		return out
	var assigned := PackedByteArray()
	assigned.resize(map.width * map.height)
	assigned.fill(0)
	for y in map.height:
		for x in map.width:
			var type: StringName = map.type_at(Vector2i(x, y))
			if not mergeable.has(type) or assigned[y * map.width + x] != 0:
				continue
			var w: int = 1
			while _free(map, assigned, Vector2i(x + w, y), type):
				w += 1
			var h: int = 1
			while _row_free(map, assigned, x, y + h, w, type):
				h += 1
			for dy in h:
				for dx in w:
					assigned[(y + dy) * map.width + x + dx] = 1
			out.append(LargeObjectPlacement.new(type, Rect2i(x, y, w, h)))
	return out


static func _free(map: MapData, assigned: PackedByteArray, cell: Vector2i, type: StringName) -> bool:
	return map.in_bounds(cell) and map.type_at(cell) == type and assigned[cell.y * map.width + cell.x] == 0


static func _row_free(map: MapData, assigned: PackedByteArray, x: int, y: int, w: int, type: StringName) -> bool:
	for dx in w:
		if not _free(map, assigned, Vector2i(x + dx, y), type):
			return false
	return true
