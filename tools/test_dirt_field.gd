extends SceneTree
## Headless load / play check of the 200 x 200 dirt field m4_dirt_field (task-071): the file is exactly 200 x 200 with a
## `#` border, `D` on every inner cell but the centre spawn `@`; it boots in the main scene (load time printed), plays a
## few hundred frames of digging in several directions without errors (process / physics cost printed) and eating works
## across the map (cells far from the spawn, corner chunks). Prints the average destroy cost.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_dirt_field.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "dirt_field"
const M4 := "res://data/maps/m4_dirt_field.txt"
const SIZE := 200
const PHASE_PLAYING := 1
const KEYBOARD: StringName = &"keyboard"
## Frames dug per direction.
const DIG_FRAMES := 75
const DIRECTIONS: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
## Cells destroyed directly across the map (eating far from the spawn and in every corner chunk).
const FAR_CELLS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(198, 1), Vector2i(1, 198), Vector2i(198, 198), Vector2i(57, 143), Vector2i(150, 20)]
## Generous budget for one physics + process frame of game logic in a headless run (milliseconds).
const FRAME_BUDGET_MS := 33.0

var _failures: PackedStringArray = []
## Script time of the current frame (process + physics callbacks), microseconds, from the two Stamp nodes.
var _frame_us: int = 0
var _t0: int = 0


## Runs first (start = true) or last in every process / physics step and adds the callbacks' time in between.
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
	_check_file()
	await _check_scene()
	if _failures.is_empty():
		print("PASS test_dirt_field")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_dirt_field")
		quit(1)


func _check_file() -> void:
	var text: String = FileAccess.get_file_as_string(M4)
	var lines: PackedStringArray = text.replace("\r", "").strip_edges(false, true).split("\n")
	_check(lines.size() == SIZE, "m4 has %d rows (want %d)" % [lines.size(), SIZE])
	var centre: int = SIZE / 2
	var bad: int = 0
	for y in lines.size():
		var line: String = lines[y]
		if line.length() != SIZE:
			bad += 1
			continue
		for x in SIZE:
			var want: String = "D"
			if x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1:
				want = "#"
			elif x == centre and y == centre:
				want = "@"
			if line[x] != want:
				bad += 1
	_check(bad == 0, "m4 layout: %d wrong cells / rows" % bad)


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _press_world(rig: Node, world_dir: Vector3) -> void:
	var yaw: float = deg_to_rad(float(rig.call("current_yaw_degrees")))
	var screen: Vector3 = world_dir.rotated(Vector3.UP, -yaw)
	_release_all()
	if screen.x > 0.01:
		Input.action_press(&"move_right", screen.x)
	elif screen.x < -0.01:
		Input.action_press(&"move_left", -screen.x)
	if screen.z > 0.01:
		Input.action_press(&"move_down", screen.z)
	elif screen.z < -0.01:
		Input.action_press(&"move_up", -screen.z)


func _release_all() -> void:
	for a in [&"move_right", &"move_left", &"move_up", &"move_down"]:
		Input.action_release(a)


func _check_scene() -> void:
	var t0: int = Time.get_ticks_usec()
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = M4
	loader.use_cmdline_map = false
	root.add_child(main)
	var load_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("[m4] main scene with m4_dirt_field ready in %.0f ms (parse, world mesh, dirt chunks, collision, reveal, lights)" % load_ms)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 5.0:
		await create_timer(0.1).timeout
		guard += 0.1
	_check(runs.get("phase") == PHASE_PLAYING, "m4 run is playing")
	var map: MapData = loader.data
	_check(map.errors.is_empty() and map.warnings.is_empty(), "m4 parses cleanly: %s %s" % [map.errors, map.warnings])
	_check(map.width == SIZE and map.height == SIZE, "m4 is %dx%d" % [map.width, map.height])
	_check(map.spawn_cell == Vector2i(SIZE / 2, SIZE / 2), "spawn at the centre (%s)" % map.spawn_cell)
	_check(map.large_objects.is_empty() and map.teleports.is_empty() and map.objects.is_empty(), "m4 is walls + dirt + player only")
	var dirt = main.get_node("DirtWalls")
	_check(dirt.home_count() == (SIZE - 2) * (SIZE - 2) - 1, "m4 dirt cells: %d" % dirt.home_count())
	var player: CharacterBody3D = main.get_node("Player")
	var rig: Node = main.get_node("CameraRig")
	runs.get("state").set("input_scheme", KEYBOARD)
	var left_before: int = dirt.count_left()
	_add_stamps()
	await process_frame
	_frame_us = 0

	# Dig in four directions; measure the logic cost of every frame.
	var worst_ms: float = 0.0
	var total_ms: float = 0.0
	var frames: int = 0
	for dir in DIRECTIONS:
		_press_world(rig, dir)
		for i in DIG_FRAMES:
			await process_frame
			var ms: float = _frame_us / 1000.0
			_frame_us = 0
			total_ms += ms
			worst_ms = maxf(worst_ms, ms)
			frames += 1
	_release_all()
	var eaten: int = left_before - dirt.count_left()
	print("[m4] %d frames digging: script logic avg %.2f ms, worst %.2f ms per frame (process + physics callbacks); %d cells eaten" % [frames, total_ms / frames, worst_ms, eaten])
	_check(eaten >= 8, "digging eats dirt on m4 (%d cells)" % eaten)
	_check(total_ms / frames < FRAME_BUDGET_MS, "average logic frame within %.0f ms (%.2f)" % [FRAME_BUDGET_MS, total_ms / frames])

	# Eating works anywhere on the map (corner chunks, far cells).
	var cost: int = 0
	for c in FAR_CELLS:
		var s: int = Time.get_ticks_usec()
		var ok: bool = dirt.destroy(c)
		cost += Time.get_ticks_usec() - s
		_check(ok and map.type_at(c) == MapLegend.FLOOR, "far dirt cell %s destroyed" % c)
	print("[m4] destroy() far across the map: %d us average (collision chunk, chunk meshes, light, reveal)" % (cost / FAR_CELLS.size()))
	await process_frame
	await process_frame
	# A run restart restores everything.
	dirt.restore()
	_check(dirt.count_left() == dirt.home_count(), "m4 dirt restored")
	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
