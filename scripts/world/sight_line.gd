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
	var span: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	return can_see_in(GridMask.around(map, from, span, blocker_set(blockers)), from, to, spread)


## The same test on a prebuilt GridMask around `from` (MapReveal builds one per sweep for all cells in reach).
static func can_see_in(mask: GridMask, from: Vector2i, to: Vector2i, spread: float) -> bool:
	if from == to:
		return true
	var a := Vector2(from) + Vector2(0.5, 0.5)
	var b := Vector2(to) + Vector2(0.5, 0.5)
	if mask.sight_clear(a, b, to):
		return true
	var side: Vector2 = (b - a).orthogonal().normalized() * spread
	return mask.sight_clear(a, b + side, to) or mask.sight_clear(a, b - side, to)


## Blocker list -> set for GridMask.around.
static func blocker_set(blockers: Array[StringName]) -> Dictionary:
	var out: Dictionary = {}
	for t in blockers:
		out[t] = true
	return out
