class_name SightLine
extends RefCounted
## Line of sight on the map grid (task-053): can the player in cell `from` see cell `to`? Cells of a blocking type
## (RevealConfig.sight_blockers: walls, items) hide what is behind them, but are themselves seen. The test casts
## RAY_COUNT grid rays from the centre of `from` to the centre of `to` and to two points displaced sideways by
## `spread` cells; the cell is seen when any of them gets through, so corners do not swallow whole rows. Pure data.

const RAY_COUNT: int = 3
## Safety bound on grid steps per ray beyond |dx| + |dy|.
const EXTRA_STEPS: int = 2


static func can_see(map: MapData, from: Vector2i, to: Vector2i, blockers: Array[StringName], spread: float) -> bool:
	if from == to:
		return true
	var a := Vector2(from) + Vector2(0.5, 0.5)
	var b := Vector2(to) + Vector2(0.5, 0.5)
	var side: Vector2 = (b - a).orthogonal().normalized() * spread
	return _ray_clear(map, a, b, to, blockers) or _ray_clear(map, a, b + side, to, blockers) \
			or _ray_clear(map, a, b - side, to, blockers)


## True when the line a -> b (cell units) crosses no blocking cell other than `target` itself.
static func _ray_clear(map: MapData, a: Vector2, b: Vector2, target: Vector2i, blockers: Array[StringName]) -> bool:
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
		if cell == target:
			return true
		if blockers.has(map.type_at(cell)):
			return false
	return true
