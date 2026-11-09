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
	var span: int = maxi(absi(target.x - origin.x), absi(target.y - origin.y))
	return visibility_in(mask_around(map, origin, span), origin, target, penumbra)


## The same on a prebuilt mask around `origin` (compute builds one per call).
static func visibility_in(mask: GridMask, origin: Vector2i, target: Vector2i, penumbra: float) -> float:
	if origin == target:
		return 1.0
	var a := Vector2(origin) + Vector2(0.5, 0.5)
	var b := Vector2(target) + Vector2(0.5, 0.5)
	var side: Vector2 = (b - a).orthogonal().normalized() * penumbra
	var clear: int = 0
	if mask.light_clear(a, b):
		clear += 1
	if mask.light_clear(a, b + side):
		clear += 1
	if mask.light_clear(a, b - side):
		clear += 1
	return float(clear) / float(RAY_COUNT)


## Light-blocking cells (walls, void and the map's light-blocking props) within `span` of `origin`.
static func mask_around(map: MapData, origin: Vector2i, span: int) -> GridMask:
	return GridMask.around(map, origin, span, {MapLegend.WALL: true, MapLegend.VOID: true}, map.light_blocking_types)


## Visibility of every open (non-wall, drawn) cell within `radius_cells` of `origin`; cells with
## visibility 0 are left out.
static func compute(map: MapData, origin: Vector2i, radius_cells: float, penumbra: float) -> Dictionary[Vector2i, float]:
	var job: Job = start(map, origin, radius_cells, penumbra)
	job.run(0)
	return job.result


## The same computation as a job that can be spread over frames (Job.run with a time budget).
static func start(map: MapData, origin: Vector2i, radius_cells: float, penumbra: float) -> Job:
	var job := Job.new()
	var span: int = ceili(radius_cells)
	job.map = map
	job.origin = origin
	job.reach_sq = radius_cells * radius_cells
	job.penumbra = penumbra
	job.mask = mask_around(map, origin, span)
	job.offsets = GridMask.offsets(span)
	return job


## An occlusion field being computed, nearest cells first.
class Job:
	extends RefCounted
	var map: MapData
	var origin: Vector2i
	var reach_sq: float
	var penumbra: float
	var mask: GridMask
	var offsets: Array
	var index: int = 0
	var result: Dictionary[Vector2i, float] = {}

	## Works until done or until `budget_usec` microseconds have passed (0 = no limit). True when done.
	func run(budget_usec: int) -> bool:
		var t0: int = Time.get_ticks_usec()
		var n: int = offsets.size()
		while index < n:
			var off: Vector2i = offsets[index]
			index += 1
			if float(off.length_squared()) > reach_sq:
				index = n
				break
			var cell: Vector2i = origin + off
			if not mask.blocks(cell) or cell == origin:
				var v: float = GlyphLightOcclusion.visibility_in(mask, origin, cell, penumbra)
				if v > 0.0 and map.type_at(cell) != MapLegend.VOID:
					result[cell] = v
			if budget_usec > 0 and index % GridMask.CLOCK_EVERY == 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				return index >= n
		return true


## True for cells light cannot pass.
static func blocks(map: MapData, cell: Vector2i) -> bool:
	var type: StringName = map.type_at(cell)
	return type == MapLegend.WALL or type == MapLegend.VOID or map.light_blocking_types.has(type)
