extends SceneTree
## Benchmark (not a test): CPU cost of the per-move sight work at normal and at large run-only sight scales (task-098
## --sight). Times MapReveal's line-of-sight sweep and the player-light occlusion (GlyphLightOcclusion.compute) on a
## real 200x200 map from the spawn-ish centre. Prints milliseconds per call.
## Usage: godot --headless --path . --max-fps 30 -s tools/bench_sight.gd -- [map_name]

const REVEAL_RADIUS := 5.5
const LIGHT_RADIUS := 11.0
const SCALES: Array[float] = [1.0, 2.0, 4.0, 10.0]
const RUNS := 3


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _load(name: String) -> MapData:
	var rows: PackedStringArray = FileAccess.get_file_as_string("res://data/maps/%s.txt" % name).replace("\r", "").split("\n", false)
	var map := MapData.new()
	map.height = rows.size()
	for row in rows:
		map.width = maxi(map.width, row.length())
	for row in rows:
		for x in map.width:
			var ch: String = row[x] if x < row.length() else " "
			map.types.append(MapLegend.WALL if ch == "#" else (MapLegend.VOID if ch == " " else MapLegend.FLOOR))
	return map


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var map: MapData = _load(args[0] if not args.is_empty() else "m5_shapes")
	var centre := Vector2i(map.width / 2, map.height / 2)
	var blockers: Array[StringName] = [MapLegend.WALL, MapLegend.ITEM, MapLegend.VOID, MapLegend.DIRT]
	print("map %dx%d centre %s" % [map.width, map.height, centre])
	for scale in SCALES:
		var reveal_ms: float = _time(func() -> void: _reveal_sweep(map, centre, REVEAL_RADIUS * scale, blockers))
		var light_ms: float = _time(func() -> void: GlyphLightOcclusion.compute(map, centre, LIGHT_RADIUS * scale, 0.35))
		print("sight %4.0f%%  reveal radius %5.1f: sweep %8.1f ms   light radius %5.1f: occlusion %8.1f ms" % [
				scale * 100.0, REVEAL_RADIUS * scale, reveal_ms, LIGHT_RADIUS * scale, light_ms])
	quit()


func _time(f: Callable) -> float:
	var best: float = INF
	for i in RUNS:
		var t0: int = Time.get_ticks_usec()
		f.call()
		best = minf(best, float(Time.get_ticks_usec() - t0) / 1000.0)
	return best


## The MapReveal.reveal_around loop for a cell that has seen nothing yet (every cell in reach is tested).
func _reveal_sweep(map: MapData, centre: Vector2i, radius: float, blockers: Array[StringName]) -> int:
	var span: int = ceili(radius) + 1
	var seen: int = 0
	var mask: GridMask = GridMask.around(map, centre, span, SightLine.blocker_set(blockers))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := centre + Vector2i(dx, dy)
			if not map.in_bounds(cell) or Vector2(dx, dy).length() > radius:
				continue
			if SightLine.can_see_in(mask, centre, cell, 0.35):
				seen += 1
	return seen
