extends SceneTree
## Headless test of the enemy remains (task-076):
##  - a destroyed crawler / wanderer bursts into its EnemyDef.diamonds diamonds on distinct free cells near it
##    (SignalBus.diamonds_spawned), a destroyed hunter leaves a black hole on its cell (SignalBus.black_hole_formed,
##    narration BLACK_HOLE_FORMED);
##  - `O` in a map is a black hole on floor; an enemy walking into one is destroyed (cause black_hole) and leaves its
##    normal remains; the hole stays;
##  - in the main scene: walking over a diamond collects it, the saved counter (PersistentProgress.diamonds) rises and
##    is in the save file, SignalBus.diamond_collected, narration DIAMOND_FOUND, the pickup sound plays; the player walks
##    over a black hole unharmed; a cannon ball on a hunter makes a black hole, on a crawler diamonds; a death keeps
##    them, SignalBus.world_reset puts diamonds and black holes back to the map file's.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_remains.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "remains"
const LEGEND := "res://resources/config/map_legend.tres"
const WORLD := "res://resources/config/world_config.tres"
const ENEMY_CONFIG := "res://resources/config/enemy_config.tres"
const REMAINS_CONFIG := "res://resources/config/remains_config.tres"
## Scripts that use the SignalBus autoload are loaded at runtime (a SceneTree script compiles before autoloads exist).
const ENEMY_SYSTEM := "res://scripts/world/enemy_system.gd"
const ENEMY_REMAINS := "res://scripts/world/enemy_remains.gd"
const MAP_PATH := "user://test_remains_map.txt"
const DT := 1.0 / 60.0
const PHASE_PLAYING := 1

const ROOM := [
	"############",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"############",
]
## A 1-wide corridor: the crawler at x = 2 walks east into the hole at x = 7.
const CORRIDOR := [
	"###########",
	"#.L....O.@#",
	"###########",
]

var _failures: PackedStringArray = []
var _done: bool = false
var _spawned: Array[Array] = []
var _holes: Array[Vector2i] = []
var _events: Array[StringName] = []
var _collected: Array[int] = []
var _destroyed: Array[Array] = []
var _ended: Array[StringName] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var bus: Node = root.get_node("SignalBus")
	bus.connect("diamonds_spawned", func(p: Vector3, cells: Array[Vector2i]) -> void: _spawned.append([p, cells.duplicate()]))
	bus.connect("black_hole_formed", func(c: Vector2i, _w: Vector3) -> void: _holes.append(c))
	bus.connect("narration_event", func(e: StringName) -> void: _events.append(e))
	bus.connect("diamond_collected", func(_c: Vector2i, total: int) -> void: _collected.append(total))
	bus.connect("enemy_destroyed", func(k: StringName, c: Vector2i, _w: Vector3, cause: StringName) -> void: _destroyed.append([k, c, cause]))
	bus.connect("run_end_requested", func(c: StringName) -> void: _ended.append(c))
	_check_bursts()
	_check_black_hole_kill()
	await _check_scene()
	_check(_done, "the scene checks ran to the end")
	if _failures.is_empty():
		print("PASS test_remains")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_remains")
		quit(1)


func _world(lines: Array, extra: Dictionary = {}) -> Dictionary:
	var rows: PackedStringArray = PackedStringArray(lines)
	for cell: Vector2i in extra:
		var row: String = rows[cell.y]
		rows[cell.y] = row.substr(0, cell.x) + String(extra[cell]) + row.substr(cell.x + 1)
	var loader := MapLoader.new()
	loader.legend = load(LEGEND) as MapLegend
	loader.world_config = load(WORLD) as WorldConfig
	loader.auto_load = false
	loader.use_cmdline_map = false
	root.add_child(loader)
	var map: MapData = loader.parse_text("\n".join(rows))
	loader.build(map)
	var sys: Node = (load(ENEMY_SYSTEM) as GDScript).new()
	sys.set("config", load(ENEMY_CONFIG))
	sys.set("map_loader", loader)
	var rem: Node = (load(ENEMY_REMAINS) as GDScript).new()
	rem.set("config", load(REMAINS_CONFIG))
	rem.set("enemies", sys)
	rem.set("map_loader", loader)
	sys.set("remains", rem)
	root.add_child(sys)
	root.add_child(rem)
	sys.set_physics_process(false)
	rem.set_physics_process(false)
	return {"loader": loader, "sys": sys, "rem": rem, "map": map}


func _free(w: Dictionary) -> void:
	for k in ["rem", "sys", "loader"]:
		(w[k] as Node).free()


func _check_bursts() -> void:
	var w: Dictionary = _world(ROOM, {Vector2i(3, 2): "L", Vector2i(8, 2): "W", Vector2i(5, 3): "H", Vector2i(1, 1): "@"})
	var sys: Node = w["sys"]
	var rem: Node = w["rem"]
	var cfg: EnemyConfig = load(ENEMY_CONFIG) as EnemyConfig
	_spawned.clear()
	_check(sys.call("destroy", Vector2i(3, 2), &"cannon"), "crawler destroyed")
	var n_crawler: int = cfg.def_for(&"crawler").diamonds
	_check(n_crawler > 0 and rem.call("diamond_count") == n_crawler, "crawler -> %d diamonds (%d)" % [n_crawler, rem.call("diamond_count")])
	_check(_spawned.size() == 1 and (_spawned[0][1] as Array).size() == n_crawler, "diamonds_spawned once with the cells")
	var near: bool = true
	for c: Vector2i in _spawned[0][1]:
		near = near and maxi(absi(c.x - 3), absi(c.y - 2)) <= 3 and (w["map"] as MapData).type_at(c) == MapLegend.FLOOR
	_check(near, "diamonds lie on free cells near the crawler: %s" % [_spawned[0][1]])
	_check(sys.call("destroy", Vector2i(8, 2), &"cannon"), "wanderer destroyed")
	var total: int = n_crawler + cfg.def_for(&"wanderer").diamonds
	_check(rem.call("diamond_count") == total, "wanderer adds %d diamonds (%d)" % [cfg.def_for(&"wanderer").diamonds, rem.call("diamond_count")])
	_holes.clear()
	_events.clear()
	_check(sys.call("destroy", Vector2i(5, 3), &"cannon"), "hunter destroyed")
	_check(_holes == ([Vector2i(5, 3)] as Array[Vector2i]) and rem.call("is_black_hole", Vector2i(5, 3)), "hunter -> black hole on its cell")
	_check(rem.call("diamond_count") == total, "a hunter leaves no diamonds")
	_check(_events.has(NarrationEvents.BLACK_HOLE_FORMED), "BLACK_HOLE_FORMED narration event")
	_check(sys.call("alive_count") == 0, "all three destroyed")
	_free(w)


func _check_black_hole_kill() -> void:
	var w: Dictionary = _world(CORRIDOR)
	var map: MapData = w["map"]
	var sys: Node = w["sys"]
	var rem: Node = w["rem"]
	_check(map.black_holes == ([Vector2i(7, 1)] as Array[Vector2i]) and map.type_at(Vector2i(7, 1)) == MapLegend.FLOOR, "O is a black hole on floor: %s" % [map.black_holes])
	_check(map.warnings.is_empty(), "O parses cleanly: %s" % [map.warnings])
	_check(rem.call("is_black_hole", Vector2i(7, 1)), "the map's black hole is there at start")
	sys.set("_dir", PackedInt32Array([1]))
	_destroyed.clear()
	_spawned.clear()
	for f in 300:
		sys.call("_physics_process", DT)
		if not sys.call("is_alive", 0):
			break
	_check(not sys.call("is_alive", 0), "the crawler walking into the black hole is destroyed")
	_check(_destroyed.size() == 1 and _destroyed[0][2] == &"black_hole" and _destroyed[0][1] == Vector2i(7, 1), "cause black_hole at the hole: %s" % [_destroyed])
	_check(_spawned.size() == 1 and rem.call("diamond_count") > 0, "it leaves its diamonds")
	_check(not rem.call("has_diamond", Vector2i(7, 1)), "no diamond on the hole itself")
	_check(rem.call("is_black_hole", Vector2i(7, 1)), "the hole stays")
	# A hunter falling into a hole leaves a hole (the same one, nothing new).
	_free(w)
	w = _world(CORRIDOR, {Vector2i(2, 1): "H"})
	sys = w["sys"]
	sys.set("_dir", PackedInt32Array([1]))
	sys.set("_run_left", PackedInt32Array([20]))
	_destroyed.clear()
	for f in 300:
		sys.call("_physics_process", DT)
		if not sys.call("is_alive", 0):
			break
	_check(_destroyed.size() == 1 and _destroyed[0][0] == &"hunter" and _destroyed[0][2] == &"black_hole", "a hunter falls into the hole: %s" % [_destroyed])
	_check((w["rem"] as Node).call("holes").size() == 1, "still one hole")
	_free(w)


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check_scene() -> void:
	# Hunter at (16, 6) parked behind dirt (cannot reach the player; the window is open but no path) so it stays put
	# and is a cannon target; crawler at (16, 2) in its own pocket; black hole at (4, 4).
	var lines: PackedStringArray = PackedStringArray([
		"####################",
		"#............DDDDDD#",
		"#............D..L.D#",
		"#............DDDDDD#",
		"#...O........D....D#",
		"#.....@......DDDDDD#",
		"#............D..H.D#",
		"#............DDDDDD#",
		"####################",
	])
	var f := FileAccess.open(MAP_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var run_cfg := RunConfig.new()
	run_cfg.restart_delay = 0.2
	run_cfg.intro_on_restart = false
	main.get_node("RunManager").set("config", run_cfg)
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = MAP_PATH
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	var sys: Node = main.get_node("EnemySystem")
	var rem: Node = main.get_node("EnemyRemains")
	var save: Node = main.get_node("SaveService")
	var player: CharacterBody3D = main.get_node("Player")
	var balls: Node = main.get_node("CannonBalls")
	var ting: Node = main.get_node("DiamondSfx")
	_check(rem.call("is_black_hole", Vector2i(4, 4)), "the map's black hole")
	# The player stands on the black hole: harmless.
	_ended.clear()
	player.global_position = loader.cell_to_world(Vector2i(4, 4))
	await _frames(30)
	_check(_ended.is_empty() and runs.get("phase") == PHASE_PLAYING, "the player stands on a black hole unharmed")
	_check(loader.world_to_cell(player.global_position) == Vector2i(4, 4), "nothing pulls the player")
	# Diamonds: three next to the player, walk over one.
	var before: int = save.progress.diamonds
	_events.clear()
	var cells: Array = rem.call("spawn_diamonds", Vector2i(8, 5), 3, loader.cell_to_world(Vector2i(8, 5)))
	_check(cells.size() == 3, "3 diamonds spawned")
	var played: int = int(ting.get("played"))
	player.global_position = loader.cell_to_world(cells[0])
	await _frames(3)
	_check(not rem.call("has_diamond", cells[0]), "walking over a diamond collects it")
	_check(save.progress.diamonds == before + 1, "the saved counter rises (%d -> %d)" % [before, save.progress.diamonds])
	_check(_collected.size() == 1 and _collected[0] == before + 1, "diamond_collected with the total")
	_check(_events.has(NarrationEvents.DIAMOND_FOUND), "DIAMOND_FOUND narration event")
	_check(int(ting.get("played")) == played + 1, "the pickup sound plays")
	var text: String = FileAccess.get_file_as_string(save_path)
	_check(text.contains("diamonds = %d" % (before + 1)), "the counter is in the save file")
	# Cannon balls: the hunter -> black hole, the crawler -> diamonds.
	player.global_position = loader.cell_to_world(Vector2i(2, 2))
	_holes.clear()
	balls.call("launch", loader.cell_to_world(Vector2i(14, 6)) + Vector3(0.0, 0.55, 0.0), Vector3.RIGHT, 0.2)
	await _frames(30)
	# The hunter wanders in its pocket (14..17, 6).
	_check(_holes.size() == 1 and rem.call("is_black_hole", _holes[0]) and _holes[0].y == 6 and _holes[0].x >= 14 and _holes[0].x <= 17, "a cannon ball on the hunter leaves a black hole in its pocket: %s" % [_holes])
	var diamonds_before: int = rem.call("diamond_count")
	balls.call("launch", loader.cell_to_world(Vector2i(14, 2)) + Vector3(0.0, 0.55, 0.0), Vector3.RIGHT, 0.2)
	await _frames(30)
	_check(rem.call("diamond_count") > diamonds_before, "a cannon ball on the crawler bursts it into diamonds")
	await _frames(40)
	_check(main.get_node("RemainsView").call("drawn") > 0, "remains are drawn")
	# A death keeps the remains (task-093); the world reset puts them back to the map's.
	var kept: int = rem.call("diamond_count")
	var holes_kept: int = rem.call("holes").size()
	runs.call("end_run", &"test")
	guard = 0.0
	await _wait(0.1)
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	_check(rem.call("diamond_count") == kept and rem.call("holes").size() == holes_kept, "a new run after a death keeps the remains")
	root.get_node("SignalBus").emit_signal("world_reset")
	_check(rem.call("diamond_count") == 0, "world_reset clears the diamonds")
	_check(rem.call("holes").size() == 1 and rem.call("is_black_hole", Vector2i(4, 4)), "world_reset keeps only the map's black hole")
	_check(save.progress.diamonds == before + 1, "the collected counter persists")
	_done = true
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAP_PATH))
	Support.remove_file(save_path)
