class_name GlyphLightOcclusion
extends RefCounted
## Cheap 2D light occlusion on the map grid (task-036): how much of a cell a light in another cell can "see".
## Walls (and anything outside the map) block; floor, items and hazards do not. A cell's visibility is the
## fraction of RAY_COUNT grid rays from the light cell's centre to the target cell (centre and two points
## displaced sideways by `penumbra` cells) that are not blocked. The cell holding the light and the target
## cell itself never block. Pure data, no nodes; GlyphVisibilityMap turns the result into shader textures.

const RAY_COUNT: int = 3
## Safety bound on grid steps per ray (a ray can never need more than |dx| + |dy| + 2).
const EXTRA_STEPS: int = 2


## Visibility 0..1 of `target` from the light in cell `origin`.
static func visibility(map: MapData, origin: Vector2i, target: Vector2i, penumbra: float) -> float:
	if origin == target:
		return 1.0
	var a := Vector2(origin) + Vector2(0.5, 0.5)
	var b := Vector2(target) + Vector2(0.5, 0.5)
	var side: Vector2 = (b - a).orthogonal().normalized() * penumbra
	var clear: int = 0
	if _ray_clear(map, a, b):
		clear += 1
	if _ray_clear(map, a, b + side):
		clear += 1
	if _ray_clear(map, a, b - side):
		clear += 1
	return float(clear) / float(RAY_COUNT)


## Visibility of every open (non-wall, drawn) cell within `radius_cells` of `origin`; cells with
## visibility 0 are left out.
static func compute(map: MapData, origin: Vector2i, radius_cells: float, penumbra: float) -> Dictionary[Vector2i, float]:
	var out: Dictionary[Vector2i, float] = {}
	var span: int = ceili(radius_cells)
	var reach_sq: float = radius_cells * radius_cells
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			if float(dx * dx + dy * dy) > reach_sq:
				continue
			var cell := origin + Vector2i(dx, dy)
			if not blocks(map, cell) or cell == origin:
				var v: float = visibility(map, origin, cell, penumbra)
				if v > 0.0 and map.type_at(cell) != MapLegend.VOID:
					out[cell] = v
	return out


## True for cells light cannot pass.
static func blocks(map: MapData, cell: Vector2i) -> bool:
	var type: StringName = map.type_at(cell)
	return type == MapLegend.WALL or type == MapLegend.VOID


## True when the straight line a -> b (cell units) crosses no blocking cell before reaching b's cell.
static func _ray_clear(map: MapData, a: Vector2, b: Vector2) -> bool:
	var cell := Vector2i(floori(a.x), floori(a.y))
	var end := Vector2i(floori(b.x), floori(b.y))
	var dir: Vector2 = b - a
	var step := Vector2i(int(signf(dir.x)), int(signf(dir.y)))
	var t_delta := Vector2(INF, INF)
	var t_max := Vector2(INF, INF)
	if step.x != 0:
		t_delta.x = absf(1.0 / dir.x)
		t_max.x = ((cell.x + (1 if step.x > 0 else 0)) - a.x) / dir.x
	if step.y != 0:
		t_delta.y = absf(1.0 / dir.y)
		t_max.y = ((cell.y + (1 if step.y > 0 else 0)) - a.y) / dir.y
	var guard: int = absi(end.x - cell.x) + absi(end.y - cell.y) + EXTRA_STEPS
	while cell != end and guard > 0:
		guard -= 1
		if t_max.x < t_max.y:
			cell.x += step.x
			t_max.x += t_delta.x
		else:
			cell.y += step.y
			t_max.y += t_delta.y
		if cell != end and blocks(map, cell):
			return false
	return true
