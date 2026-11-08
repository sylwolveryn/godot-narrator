extends SceneTree
## Headless load / perf check of the generated-shapes map m5_shapes (task-074) with its enemies (task-075):
##  - the file: 200 x 200, `#` border, `@` at the centre, every walkable cell (floor, spawn, enemies, black holes)
##    4-connected to the spawn, enemies of all three types (L, R, H, W), hunters far from the spawn, cannons next to it;
##  - it boots in the main scene (load time printed), every enemy is in EnemySystem, and a few hundred frames with all
##    enemies moving run without errors: the script time per frame and the EnemySystem step cost are printed, once
##    with the hunters idle (player out of their window) and once with every hunter searching a path across the map
##    (search window widened to the whole map, the worst case).
## Usage: godot --headless --max-fps 30 --path . -s tools/test_shapes_map.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "shapes_map"
const M5 := "res://data/maps/m5_shapes.txt"
const SIZE := 200
const PHASE_PLAYING := 1
const FRAMES := 300
## Hunters must start at least this far (cells) from the spawn so the start is safe.
const SAFE_DIST := 40.0
## Generous budget for one frame of game logic in a headless run (milliseconds).
const FRAME_BUDGET_MS := 33.0
## Search window of the worst-case phase (cells): the whole map.
const WIDE_RADIUS := 100

var _failures: PackedStringArray = []
var _frame_us: int = 0
var _t0: int = 0
var _ended: Array[StringName] = []


class Stamp extends Node:
	var start: bool = true
	var on_start: Callable
	var on_end: Callable

	func _process(_d: float) -> void:
		(on_start if start else on_end).call()

	func _physics_process(_d: float) -> void:
		(on_start if start else on_end).call()


func _add_stamps() -> void:
	var first := Stamp.new()
	first.process_priority = -1000000
	first.process_physics_priority = -1000000
	first.on_start = func() -> void: _t0 = Time.get_ticks_usec()
	var last := Stamp.new()
	last.start = false
	last.process_priority = 1000000
	last.process_physics_priority = 1000000
	last.on_end = func() -> void: _frame_us += Time.get_ticks_usec() - _t0
	root.add_child(first)
	root.add_child(last)


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	root.get_node("SignalBus").connect("run_end_requested", func(c: StringName) -> void: _ended.append(c))
	_check_file()
	await _check_scene()
	if _failures.is_empty():
		print("PASS test_shapes_map")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_shapes_map")
		quit(1)


func _check_file() -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(M5).replace("\r", "").strip_edges(false, true).split("\n")
	_check(lines.size() == SIZE, "m5 has %d rows" % lines.size())
	var bad_rows: int = 0
	var bad_border: int = 0
	for y in lines.size():
		if lines[y].length() != SIZE:
			bad_rows += 1
			continue
		for x in SIZE:
			if (x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1) and lines[y][x] != "#":
				bad_border += 1
	_check(bad_rows == 0 and bad_border == 0, "m5 is %d x %d with a # border (%d bad rows, %d border cells)" % [SIZE, SIZE, bad_rows, bad_border])
	@warning_ignore("integer_division")
	var c: int = SIZE / 2
	_check(lines[c][c] == "@", "spawn at the centre")
	var walkable := ".@LRHWO"
	var counts: Dictionary = {}
	var total: int = 0
	var near_hunter: int = 0
	for y in SIZE:
		for x in SIZE:
			var ch: String = lines[y][x]
			counts[ch] = int(counts.get(ch, 0)) + 1
			if walkable.contains(ch):
				total += 1
			if ch == "H" and Vector2(x - c, y - c).length() < SAFE_DIST:
				near_hunter += 1
	# 4-connected flood from the spawn.
	var seen: Dictionary[Vector2i, bool] = {Vector2i(c, c): true}
	var queue: Array[Vector2i] = [Vector2i(c, c)]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cell + d
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= SIZE or n.y >= SIZE or not walkable.contains(lines[n.y][n.x]):
				continue
			seen[n] = true
			queue.append(n)
	print("[m5] %d walkable cells, %d reached from the spawn; L %d R %d H %d W %d O %d C %d" % [total, seen.size(),
			counts.get("L", 0), counts.get("R", 0), counts.get("H", 0), counts.get("W", 0), counts.get("O", 0), counts.get("C", 0)])
	_check(seen.size() == total, "every route is connected to the spawn (%d of %d)" % [seen.size(), total])
	_check(total > 3000, "plenty of carved routes (%d cells)" % total)
	for ch in ["L", "R", "H", "W"]:
		_check(int(counts.get(ch, 0)) >= 3, "several %s enemies (%d)" % [ch, counts.get(ch, 0)])
	_check(near_hunter == 0, "no hunter within %.0f cells of the spawn" % SAFE_DIST)
	_check(int(counts.get("C", 0)) >= 2, "cannons near the centre")


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _measure(label: String, enemies: Node) -> void:
	enemies.set("step_count", 0)
	enemies.set("step_usec", 0)
	var steps0: int = enemies.get("steps")
	var searches0: int = enemies.get("searches")
	var total_ms: float = 0.0
	var worst_ms: float = 0.0
	_frame_us = 0
	for i in FRAMES:
		await process_frame
		var ms: float = _frame_us / 1000.0
		_frame_us = 0
		total_ms += ms
		worst_ms = maxf(worst_ms, ms)
	print("[m5] %s: %d frames, script logic avg %.2f ms, worst %.2f ms per frame; EnemySystem step avg %.3f ms (%d steps), %d cells entered, %d path searches, %d alive" % [
		label, FRAMES, total_ms / FRAMES, worst_ms, float(enemies.call("average_step_usec")) / 1000.0, enemies.get("step_count"),
		int(enemies.get("steps")) - steps0, int(enemies.get("searches")) - searches0, enemies.call("alive_count")])
	_check(total_ms / FRAMES < FRAME_BUDGET_MS, "%s: average logic frame within %.0f ms (%.2f)" % [label, FRAME_BUDGET_MS, total_ms / FRAMES])
	_check(int(enemies.get("steps")) - steps0 > 0, "%s: enemies move" % label)


func _check_scene() -> void:
	var t0: int = Time.get_ticks_usec()
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = M5
	loader.use_cmdline_map = false
	root.add_child(main)
	print("[m5] main scene with m5_shapes ready in %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	_check(runs.get("phase") == PHASE_PLAYING, "m5 run is playing")
	var map: MapData = loader.data
	_check(map.errors.is_empty() and map.warnings.is_empty(), "m5 parses cleanly: %s %s" % [map.errors, map.warnings])
	_check(map.spawn_cell == Vector2i(100, 100), "spawn at (100, 100)")
	var enemies: Node = main.get_node("EnemySystem")
	_check(enemies.call("count") == map.enemies.size() and map.enemies.size() > 0, "EnemySystem has all %d enemies" % map.enemies.size())
	_check(main.get_node("EnemyRemains").call("holes").size() == map.black_holes.size(), "the map's black holes are there")
	_check(main.get_node("CannonSystem").call("cannon_count") >= 2, "cannons on m5")
	_add_stamps()
	await process_frame
	await _measure("hunters idle", enemies)
	enemies.call("_on_tables_loaded", {"enemy_def": [{"kind": "hunter", "search_radius": WIDE_RADIUS, "repath_seconds": 0.6}]})
	await _measure("every hunter searching across the map", enemies)
	_check(_ended.is_empty() or _ended.all(func(c: StringName) -> bool: return String(c).begins_with("enemy_")), "only enemies end the run: %s" % [_ended])
	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
