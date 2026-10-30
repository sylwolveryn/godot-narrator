extends SceneTree
## Headless test of the reveal system (task-011) on the real main scene: everything hidden at
## run start, reveal radius, reveal sticks, memory persists into the next run in the memory
## style, and the revealed state is exposed through PersistentProgress.
## Usage: godot --headless --path . -s tools/test_reveal.gd

const PHASE_PLAYING := 1
## MapReveal.CellState values (not referenced by name: the script needs the SignalBus autoload at compile time).
const CELL_MEMORY := 1
const CELL_SEEN := 2
const Support := preload("res://tools/test_support.gd")
const MAP_ID := &"m1_awakening"
var _failures: PackedStringArray = []
var _signal_cells: Array[Vector2i] = []
var _reveal: Node


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _make_main() -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, "reveal")
	main.get_node("IntroSequence").set("config", _fast_intro())
	var run_cfg: RunConfig = main.get_node("RunManager").get("config").duplicate()
	run_cfg.restart_delay = 0.0
	main.get_node("RunManager").set("config", run_cfg)
	return main


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## True when every mesh of the cell is visible / hidden.
func _all_visible(loader: MapLoader, cell: Vector2i) -> bool:
	for m: MeshInstance3D in loader.visuals_at(cell):
		if not m.visible:
			return false
	return true


func _all_hidden(loader: MapLoader, cell: Vector2i) -> bool:
	for m: MeshInstance3D in loader.visuals_at(cell):
		if m.visible:
			return false
	return true


## A seen cell: meshes visible, and either still animating its reveal or settled at the full
## look (brightness 1, seen fraction 1, no glint) in the reveal mask.
func _normal(loader: MapLoader, cell: Vector2i) -> bool:
	for m: MeshInstance3D in loader.visuals_at(cell):
		if not m.visible:
			return false
	if _reveal.call("state_of", cell) != CELL_SEEN:
		return false
	var look: Vector3 = _reveal.call("cell_look", cell)
	return _reveal.call("is_animating", cell) or look.is_equal_approx(Vector3(1.0, 1.0, 0.0))


## A remembered cell: meshes visible, and in the mask fully remembered (brightness 1, seen fraction 0).
func _memory(loader: MapLoader, cell: Vector2i) -> bool:
	for m: MeshInstance3D in loader.visuals_at(cell):
		if not m.visible:
			return false
	if _reveal.call("state_of", cell) != CELL_MEMORY:
		return false
	return (_reveal.call("cell_look", cell) as Vector3).is_equal_approx(Vector3(1.0, 0.0, 0.0))


func _dist(loader: MapLoader, cell: Vector2i, pos: Vector3) -> float:
	var c: Vector3 = loader.cell_to_world(cell)
	return Vector2(c.x - pos.x, c.z - pos.z).length()


func _stored(progress: PersistentProgress) -> Dictionary:
	var out: Dictionary = {}
	for v: Vector2 in progress.revealed_cells.get(MAP_ID, PackedVector2Array()):
		out[Vector2i(int(v.x), int(v.y))] = true
	return out


func _run() -> void:
	root.get_node("SignalBus").connect("cells_revealed", func(_id: StringName, cells: PackedVector2Array) -> void:
		for v in cells:
			_signal_cells.append(Vector2i(int(v.x), int(v.y))))
	var main := _make_main()
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var player: CharacterBody3D = main.get_node("Player")
	var loader: MapLoader = main.get_node("World/MapLoader")
	var reveal: Node = main.get_node("MapReveal")
	_reveal = reveal
	var progress: PersistentProgress = main.get_node("SaveService").get("progress")
	# Floor on, so every kind of cell takes part in the checks below (the shipped default is off).
	var cfg: RevealConfig = (reveal.get("config") as RevealConfig).duplicate()
	cfg.reveal_floor = true
	reveal.set("config", cfg)
	var radius: float = cfg.reveal_radius * loader.world_config.cell_size

	# Everything hidden before the run starts (the veil hides the intro anyway).
	_check(loader.map_id == MAP_ID, "map id %s" % loader.map_id)
	await _wait(0.6)
	_check(runs.get("phase") == PHASE_PLAYING, "run should be playing")
	var spawn: Vector3 = loader.spawn_position

	# --- Run start: only the radius around the spawn is visible. ---
	var hidden_kinds: Dictionary = {}
	var near_count: int = 0
	for cell: Vector2i in loader.visuals:
		if _dist(loader, cell, spawn) <= radius:
			near_count += 1
			_check(_normal(loader, cell), "cell %s near the spawn should be visible and normal" % cell)
		else:
			_check(_all_hidden(loader, cell), "cell %s far from the spawn should be hidden" % cell)
			hidden_kinds[loader.data.type_at(cell)] = true
	for kind: StringName in [MapLegend.WALL, MapLegend.ITEM, MapLegend.SPIKES, MapLegend.CORRUPT, MapLegend.FLOOR]:
		_check(hidden_kinds.has(kind), "no hidden %s cells at run start" % kind)
	_check(near_count > 0, "nothing revealed at the spawn")
	var after_spawn: Dictionary = _stored(progress)
	_check(after_spawn.size() == near_count, "progress stores %d cells, expected %d" % [after_spawn.size(), near_count])

	# --- Walking reveals and the reveal sticks. ---
	_key(KEY_A, true)
	await process_frame
	await _wait(1.6)
	_key(KEY_A, false)
	await _wait(0.4)
	var here: Vector3 = player.global_position
	var travelled: float = spawn.distance_to(here)
	_check(travelled > 3.0, "player barely moved (%f)" % travelled)
	var run1: Dictionary = {}
	for cell: Vector2i in loader.visuals:
		if _dist(loader, cell, here) <= radius or _dist(loader, cell, spawn) <= radius:
			_check(_normal(loader, cell), "cell %s near the path should be visible" % cell)
			run1[cell] = true
		elif _dist(loader, cell, spawn) > radius + travelled + 0.01 and _dist(loader, cell, here) > radius:
			_check(_all_hidden(loader, cell), "cell %s far from the path should be hidden" % cell)
	_check(_normal(loader, loader.world_to_cell(spawn)), "spawn cell must stay revealed after walking away")
	var stored1: Dictionary = _stored(progress)
	_check(stored1.size() > after_spawn.size(), "walking did not add to the stored cells")
	for cell: Vector2i in run1:
		_check(stored1.has(cell), "cell %s visible but not stored" % cell)
	_check(_signal_cells.size() == stored1.size(), "cells_revealed emitted %d cells, stored %d" % [_signal_cells.size(), stored1.size()])

	# --- Next run: remembered cells show in the memory style, the rest stays hidden. ---
	runs.call("end_run", &"test")
	await _wait(0.4)
	_check(runs.get("phase") == PHASE_PLAYING and runs.get("run_count") == 2, "second run should be playing")
	var seen_again: int = 0
	var memory_cells: Array[Vector2i] = []
	for cell: Vector2i in loader.visuals:
		var near: bool = _dist(loader, cell, spawn) <= radius
		if near:
			_check(_normal(loader, cell), "run 2: cell %s near spawn should be normal" % cell)
			seen_again += 1
		elif stored1.has(cell):
			_check(_memory(loader, cell), "run 2: remembered cell %s should show in memory style" % cell)
			memory_cells.append(cell)
		else:
			_check(_all_hidden(loader, cell), "run 2: unseen cell %s should be hidden" % cell)
	_check(not memory_cells.is_empty(), "run 2 has no memory cells")
	# Remembered cells carry the memory look in the reveal mask: full brightness (the shader caps
	# its density), seen fraction 0 (memory palette); seen cells are the opposite.
	var walls_checked: int = 0
	for cell: Vector2i in memory_cells:
		if loader.data.type_at(cell) == MapLegend.WALL:
			var look: Vector3 = reveal.call("cell_look", cell)
			_check(look.is_equal_approx(Vector3(1.0, 0.0, 0.0)), "memory wall at %s has look %s" % [cell, look])
			walls_checked += 1
	_check(walls_checked > 0, "no remembered wall to check the memory style on")
	_check(not reveal.call("is_animating", memory_cells[0]), "a plain memory cell must not animate")
	# Walking over remembered cells makes them normal again; stored count is unchanged for them.
	var stored_before_walk: int = _stored(progress).size()
	_key(KEY_A, true)
	await process_frame
	await _wait(1.6)
	_key(KEY_A, false)
	await _wait(0.3)
	var here2: Vector3 = player.global_position
	var renormalised: int = 0
	for cell: Vector2i in memory_cells:
		if _dist(loader, cell, here2) <= radius:
			_check(_normal(loader, cell), "re-seen cell %s should be normal again" % cell)
			renormalised += 1
	_check(renormalised > 0, "walking back never re-saw a remembered cell")
	_check(_stored(progress).size() >= stored_before_walk, "stored cells shrank")
	var dupes: Dictionary = {}
	for c in _signal_cells:
		_check(not dupes.has(c), "cell %s announced twice" % c)
		dupes[c] = true

	# --- Exact radius on a custom map (own map id, so the M1 memory is not involved). ---
	var small: RevealConfig = cfg.duplicate()
	small.reveal_radius = 2.0
	reveal.set("config", small)
	loader.map_id = &"test_strip"
	loader.build(loader.parse_text("##########\n#...@....#\n##########\n"))
	player.call("spawn")
	var s := Vector2i(4, 1)
	# A freshly seen cell starts dark, grows past full brightness (overshoot) and settles at 1.
	var edge: Vector2i = s + Vector2i(1, -1)
	_check(reveal.call("is_animating", edge), "a cell seen for the first time should animate")
	_check((reveal.call("cell_look", edge) as Vector3).x == 0.0, "a freshly seen cell should start dark")
	var peak: float = 0.0
	var started: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started) / 1000.0 < small.reveal_duration + 0.4:
		await process_frame
		peak = maxf(peak, (reveal.call("cell_look", edge) as Vector3).x)
	_check(peak > 1.0 and peak <= small.reveal_overshoot + 0.01, "reveal brightness peaked at %f, expected within (1, %f]" % [peak, small.reveal_overshoot])
	_check(not reveal.call("is_animating", edge), "reveal animation should have finished")
	_check((reveal.call("cell_look", edge) as Vector3).is_equal_approx(Vector3(1.0, 1.0, 0.0)), "reveal should settle at full look")
	_check(_normal(loader, s + Vector2i(2, 0)), "floor at distance 2.0 should be revealed")
	_check(_all_hidden(loader, s + Vector2i(3, 0)), "floor at distance 3.0 should be hidden")
	_check(_normal(loader, s + Vector2i(1, -1)), "wall at distance 1.41 should be revealed")
	_check(_all_hidden(loader, s + Vector2i(2, -1)), "wall at distance 2.24 should be hidden")
	small.reveal_radius = 2.0
	small.reveal_floor = false
	reveal.call("begin_run")
	reveal.call("reveal_around", loader.spawn_position)
	_check(_all_hidden(loader, s), "floor must stay hidden when reveal_floor is off")
	_check(_normal(loader, s + Vector2i(1, -1)), "walls still reveal when the floor is off")

	main.queue_free()
	await process_frame
	Support.remove_file("user://test_progress_reveal.tres")
	if _failures.is_empty():
		print("PASS test_reveal")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_reveal")
		quit(1)
