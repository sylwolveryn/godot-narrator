extends SceneTree
## Headless test of small-object pushing (task-019): the map legend char and the objects of M1 (reachability: they never
## block a path), the grown form pushes one cell, the single glyph cannot, blocks (wall, object, void, spikes, corruption,
## item, spawn), the object_moved signal, collision moving with the object, reset at run start, and a real input-driven
## push on the main scene.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_pushing.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "pushing"
const PHASE_PLAYING := 1
const MAP_PATH := "res://data/maps/m1_awakening.txt"
## Synthetic map: spawn (1,1); objects (2,1) (3,1) (1,3) (6,3) (5,4); corruption (5,1); spikes (2,3); item (5,3); void (4..6,5).
const TEST_MAP := "##########\n#@oo.%...#\n#........#\n#o^..*o..#\n#....o...#\n####   ###\n"
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _failures: PackedStringArray = []
var _moves: Array = []
var _main: Node


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _on_moved(id: int, from_cell: Vector2i, to_cell: Vector2i, form: StringName) -> void:
	_moves.append([id, from_cell, to_cell, form])


func _run() -> void:
	_check_map()
	await _main_scene()
	if _failures.is_empty():
		print("PASS test_pushing")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_pushing")
		quit(1)


## Cells reachable from the spawn over 4-neighbour steps; `blocked` cells count as walls.
func _reach(map: MapData, blocked: Array[Vector2i]) -> Dictionary:
	var seen: Dictionary = {map.spawn_cell: true}
	var queue: Array[Vector2i] = [map.spawn_cell]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for s in STEPS:
			var n: Vector2i = c + s
			var t: StringName = map.type_at(n)
			if t == MapLegend.VOID or t == MapLegend.WALL or seen.has(n) or blocked.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _check_map() -> void:
	var loader := MapLoader.new()
	loader.legend = load("res://resources/config/map_legend.tres")
	loader.world_config = load("res://resources/config/world_config.tres")
	loader.auto_load = false
	root.add_child(loader)
	var map := loader.load_file(MAP_PATH)
	_check(map.errors.is_empty() and map.warnings.is_empty(), "M1 parses cleanly with the object char: %s %s" % [map.errors, map.warnings])
	_check(loader.legend.type_for("o") == MapLegend.OBJECT, "legend maps o to the object type")
	_check(map.objects.size() >= 3 and map.objects.size() <= 5, "M1 has 3..5 objects, got %d" % map.objects.size())
	for c in map.objects:
		_check(map.type_at(c) == MapLegend.FLOOR, "object %s stands on floor" % [c])
		_check(c != map.spawn_cell, "object not on the spawn")
	# Reachability: with the objects as walls every other cell stays reachable exactly as without them.
	var free: Dictionary = _reach(map, [])
	var blocked: Dictionary = _reach(map, map.objects)
	for c: Vector2i in free:
		if not map.objects.has(c):
			_check(blocked.has(c), "cell %s is cut off by an object" % [c])
	for c: Vector2i in blocked:
		_check(free.has(c), "unexpected cell %s" % [c])
	_check(free.size() > 100, "map has a large walkable area (%d)" % free.size())
	loader.queue_free()


func _main_scene() -> void:
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(_main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 3
	seeded.death_count = 3
	seeded.entity_unlocked = true
	seeded.entity_grow_played = true
	seeded.entity_form = String(EntityForm.GROWN)
	ResourceSaver.save(seeded, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	_main.get_node("IntroSequence").set("config", intro)
	root.add_child(_main)
	var runs: Node = _main.get_node("RunManager")
	var prog: Node = _main.get_node("EntityProgression")
	var pushables: Node = _main.get_node("PushableObjects")
	var view: Node = _main.get_node("ObjectGlyphView")
	var loader: MapLoader = _main.get_node("World/MapLoader")
	var player: CharacterBody3D = _main.get_node("Player")
	var bus: Node = root.get_node("SignalBus")
	bus.connect("object_moved", _on_moved)
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 4.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.2)
	_check(prog.call("current_form") == EntityForm.GROWN, "seeded save is in the grown form")

	# --- the real M1 objects: loaded, drawn once each, collision per object ---
	var home: Array[Vector2i] = loader.data.objects.duplicate()
	_check(pushables.call("count") == home.size() and view.call("instance_count") == home.size(), "one object, one instance per start cell")
	_check(get_nodes_in_group("map_objects").size() == home.size(), "one collision body per object")
	for i in home.size():
		_check(pushables.call("cell_of", i) == home[i], "object %d starts on its map cell" % i)

	# --- input-driven push (grown): stand west of object 0 (6,3) and hold D (screen right = world +x with +z) ---
	var id0: int = pushables.call("object_at", Vector2i(6, 3))
	_check(id0 >= 0, "object at (6,3)")
	player.velocity = Vector3.ZERO
	player.global_position = loader.cell_to_world(Vector2i(5, 3))
	_moves.clear()
	_east(true)
	await _wait(0.8)
	_east(false)
	_check(pushables.call("cell_of", id0) == Vector2i(7, 3), "grown entity pushes the object east by input, got %s" % [pushables.call("cell_of", id0)])
	_check(_moves.size() == 1 and _moves[0] == [id0, Vector2i(6, 3), Vector2i(7, 3), EntityForm.GROWN], "one object_moved signal with the right cells and form: %s" % [_moves])
	_check(_body_cell(loader, id0, pushables) == Vector2i(7, 3), "the collision body moved with the object")
	await _wait((pushables.get("config") as PushConfig).slide_duration + 0.1)
	_check(view.call("position_of", id0).is_equal_approx(loader.cell_to_world(Vector2i(7, 3))), "the drawn instance arrived on the new cell")
	# the wall behind it ((8,3)) stops it
	_east(true)
	await _wait(0.8)
	_east(false)
	_check(pushables.call("cell_of", id0) == Vector2i(7, 3) and _moves.size() == 1, "an object against a wall does not move")

	# --- single glyph: the same push does nothing ---
	_check(prog.call("set_form", EntityForm.SINGLE), "switch to the single glyph")
	pushables.call("reset")
	_moves.clear()
	player.velocity = Vector3.ZERO
	player.global_position = loader.cell_to_world(Vector2i(5, 3))
	_east(true)
	await _wait(0.8)
	_east(false)
	_check(pushables.call("cell_of", id0) == Vector2i(6, 3) and _moves.is_empty(), "the single glyph cannot move the object (blocked like a wall)")
	_check(player.global_position.x < 6.1, "the object blocks the single glyph, x = %.2f" % player.global_position.x)
	_check(not pushables.call("try_push", id0, Vector2i(1, 0)), "try_push refuses the single glyph")
	prog.call("set_form", EntityForm.GROWN)

	# --- reset at run start ---
	_check(pushables.call("try_push", id0, Vector2i(1, 0)) and pushables.call("cell_of", id0) == Vector2i(7, 3), "grown API push")
	bus.emit_signal("run_started", 99)
	_check(pushables.call("cell_of", id0) == Vector2i(6, 3) and _body_cell(loader, id0, pushables) == Vector2i(6, 3), "objects return to their map cells at run start")
	_check(view.call("position_of", id0).is_equal_approx(loader.cell_to_world(Vector2i(6, 3))), "the drawn instance resets too")
	await _wait(0.4)

	# --- block rules on a synthetic map ---
	var test_map: MapData = loader.parse_text(TEST_MAP)
	player.global_position = loader.cell_to_world(Vector2i(8, 2))
	loader.build(test_map)
	_check(pushables.call("count") == 5, "synthetic map has 5 objects, got %d" % pushables.call("count"))
	var a: int = pushables.call("object_at", Vector2i(2, 1))
	var b: int = pushables.call("object_at", Vector2i(3, 1))
	var c: int = pushables.call("object_at", Vector2i(1, 3))
	var d: int = pushables.call("object_at", Vector2i(6, 3))
	var e: int = pushables.call("object_at", Vector2i(5, 4))
	var east := Vector2i(1, 0)
	var west := Vector2i(-1, 0)
	var south := Vector2i(0, 1)
	_moves.clear()
	_check(not pushables.call("try_push", a, east), "blocked by another object")
	_check(not pushables.call("try_push", a, west), "blocked by the spawn cell")
	_check(not pushables.call("try_push", c, east), "blocked by spikes")
	_check(not pushables.call("try_push", c, west), "blocked by a wall")
	_check(not pushables.call("try_push", d, west), "blocked by an item")
	_check(not pushables.call("try_push", e, south), "blocked by void")
	_check(not pushables.call("try_push", a, Vector2i(1, 1)), "diagonal steps are refused")
	_check(_moves.is_empty() and pushables.call("cell_of", a) == Vector2i(2, 1), "refused pushes emit nothing and move nothing")
	_check(pushables.call("try_push", b, east) and pushables.call("cell_of", b) == Vector2i(4, 1), "free target: pushed one cell")
	_check(not pushables.call("try_push", b, east), "a sliding object cannot be pushed again at once")
	await _wait((pushables.get("config") as PushConfig).slide_duration + 0.1)
	_check(not pushables.call("try_push", b, east), "blocked by corruption")
	_check(pushables.call("try_push", a, east) and pushables.call("cell_of", a) == Vector2i(3, 1), "after b moved away a can follow")
	_check(_moves.size() == 2 and _moves[0] == [b, Vector2i(3, 1), Vector2i(4, 1), EntityForm.GROWN], "signal per successful push: %s" % [_moves])
	_check(pushables.call("object_at", Vector2i(3, 1)) == a and pushables.call("object_at", Vector2i(2, 1)) == -1, "occupancy follows the object")
	# a cell the entity stands on is not a target
	await _wait((pushables.get("config") as PushConfig).slide_duration + 0.1)
	player.velocity = Vector3.ZERO
	player.global_position = loader.cell_to_world(Vector2i(1, 2))
	_check(not pushables.call("try_push", c, Vector2i(0, -1)), "blocked by the entity's own cell")

	main_cleanup(path)


func main_cleanup(path: String) -> void:
	_main.queue_free()
	Support.remove_file(path)


func _body_cell(loader: MapLoader, id: int, pushables: Node) -> Vector2i:
	var body: Node3D = pushables.get_node("Object_%d" % id)
	return loader.world_to_cell(body.position)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Screen right + down is world +x with the isometric camera (yaw 45).
func _east(pressed: bool) -> void:
	_key(KEY_D, pressed)
	_key(KEY_S, pressed)
