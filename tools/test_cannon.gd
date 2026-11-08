extends SceneTree
## Headless test of the cannon `C` (task-073): merging (1x1, 2x2; the arena has one of each), turning smoothly away
## from an adjacent player and keeping the facing otherwise, the art direction following the facing, a tap = 1 ball,
## holding: autofire after 2 s at ~1/s rising to 5/s 4 s later (balls counted in windows), the cone (+-15 degrees),
## the range (100 cells, then fading), hits through the Destructibles registry with SignalBus signals (dirt D, a whole
## gargoyle, a teleport pad), bounces off walls, cannons and the player, and the player never hurt.
## Runs on a small test map written to user:// (and checks the arena's cannons).
## Usage: godot --headless --max-fps 30 --path . -s tools/test_cannon.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "cannon"
const LEGEND := "res://resources/config/map_legend.tres"
const ARENA := "res://data/maps/m2_arena.txt"
const MAP_PATH := "user://test_cannon_map.txt"
const PHASE_PLAYING := 1
const FLYING := 1
const FADING := 2
const ANGLE_EPS := 0.02
## The test map: cannon at (3, 2), dirt (12..14, 4..5), a 2x2 gargoyle (3..4, 5..6), teleports 0 (10..12, 8..10) and
## 1 (2..4, 11..13), a free row 1 for the range run, spawn at (12, 12).
const MAP := [
	"#####################",
	"#...................#",
	"#..C................#",
	"#...................#",
	"#...........DDD.....#",
	"#..GG.......DDD.....#",
	"#..GG...............#",
	"#...................#",
	"#.........TTT.......#",
	"#.........T0T.......#",
	"#.........TTT.......#",
	"#.TTT...............#",
	"#.T1T.......@.......#",
	"#.TTT...............#",
	"#####################",
]
const CANNON := Vector2i(3, 2)

var _failures: PackedStringArray = []
## Set when the scene part ran to its end (a script error aborts it silently otherwise).
var _done: bool = false
var _destroyed: Array[Array] = []
var _dirt: Array[Array] = []
var _fired_frames: Array[int] = []
var _fired_dirs: Array[Vector3] = []
var _run_ended: bool = false


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	_check_merging()
	await _check_arena()
	await _check_scene()
	_check(_done, "the scene checks ran to the end")
	if _failures.is_empty():
		print("PASS test_cannon")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_cannon")
		quit(1)


func _check_merging() -> void:
	var loader := MapLoader.new()
	loader.legend = load(LEGEND) as MapLegend
	var map: MapData = loader.parse_text("C.CC.\n..CC@")
	_check(map.warnings.is_empty() and map.errors.is_empty(), "C parses cleanly: %s %s" % [map.warnings, map.errors])
	var sizes: Array[Vector2i] = []
	for p in map.large_objects:
		if p.type == &"cannon":
			sizes.append(p.rect.size)
	_check(sizes.size() == 2 and sizes[0] == Vector2i(1, 1) and sizes[1] == Vector2i(2, 2), "C merges into 1x1 and 2x2: %s" % [sizes])
	var def: LargeObjectDef = loader.legend.large_def(&"cannon")
	_check(def != null and def.blocks_movement and not def.destructible, "cannon blocks movement, indestructible")
	_check((loader.legend.large_def(&"gargoyle") as LargeObjectDef).destructible, "gargoyle is destructible")
	loader.free()


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _boot(path: String) -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, SAVE_TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = path
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.3)
	return main


func _check_arena() -> void:
	var main: Node = await _boot(ARENA)
	var cannons = main.get_node("CannonSystem")
	var sizes: Array[Vector2i] = []
	for i in cannons.cannon_count():
		sizes.append(cannons.cannon(i).footprint.size)
	_check(sizes.has(Vector2i(1, 1)) and sizes.has(Vector2i(2, 2)), "arena has a 1x1 and a 2x2 cannon: %s" % [sizes])
	_check(main.get_node("CannonView").call("piece_count") == cannons.cannon_count(), "one cannon view piece per cannon")
	main.queue_free()
	await process_frame


func _angle_diff(a: float, b: float) -> float:
	return absf(angle_difference(a, b))


func _check_scene() -> void:
	var f := FileAccess.open(MAP_PATH, FileAccess.WRITE)
	f.store_string("\n".join(MAP) + "\n")
	f.close()
	var main: Node = await _boot(MAP_PATH)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("destructible_destroyed", func(k: StringName, r: Rect2i, _w: Vector3, c: StringName) -> void: _destroyed.append([k, r, c]))
	bus.connect("dirt_destroyed", func(_m: StringName, cell: Vector2i, c: StringName) -> void: _dirt.append([cell, c]))
	bus.connect("cannon_fired", func(_i: int, _m: Vector3, d: Vector3) -> void:
		_fired_frames.append(Engine.get_physics_frames())
		_fired_dirs.append(d))
	bus.connect("run_ended", func(_c: StringName) -> void: _run_ended = true)
	bus.connect("run_end_requested", func(_c: StringName) -> void: _run_ended = true)
	var loader: MapLoader = main.get_node("World/MapLoader")
	var map: MapData = loader.data
	var cannons = main.get_node("CannonSystem")
	var balls = main.get_node("CannonBalls")
	var inter = main.get_node("Interactables")
	var view = main.get_node("CannonView")
	var player: CharacterBody3D = main.get_node("Player")
	var cfg: CannonConfig = cannons.get("config")
	_check(map.errors.is_empty() and map.warnings.is_empty(), "test map parses cleanly: %s %s" % [map.errors, map.warnings])
	_check(cannons.cannon_count() == 1, "one cannon on the test map")
	var c = cannons.cannon(0)
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var max_turn: float = deg_to_rad(cfg.turn_speed_degrees) * dt

	# --- Turning: away from an adjacent player, smoothly; kept when the player leaves. ---
	player.global_position = loader.cell_to_world(CANNON + Vector2i(1, 0))
	await _frames(2)
	var before: float = c.facing
	await physics_frame
	_check(_angle_diff(c.facing, before) <= max_turn + 0.001, "turns at most turn_speed per step")
	await _wait(1.5)
	_check(_angle_diff(c.facing, PI) < ANGLE_EPS, "player east -> faces west (%.2f)" % c.facing)
	var west_index: int = view.call("piece_dir_index", 0)
	player.global_position = loader.cell_to_world(CANNON + Vector2i(0, -1))
	await _wait(1.5)
	_check(_angle_diff(c.facing, PI * 0.5) < ANGLE_EPS, "player north -> faces +z (%.2f)" % c.facing)
	player.global_position = loader.cell_to_world(CANNON + Vector2i(-1, 0))
	await _wait(1.5)
	_check(_angle_diff(c.facing, 0.0) < ANGLE_EPS, "player west -> faces east (%.2f)" % c.facing)
	await process_frame
	var east_index: int = view.call("piece_dir_index", 0)
	_check(posmod(east_index - west_index, 8) == 4, "the art turns with the facing (%d vs %d)" % [east_index, west_index])
	player.global_position = loader.cell_to_world(Vector2i(12, 12))
	await _wait(0.5)
	_check(_angle_diff(c.facing, 0.0) < ANGLE_EPS, "far player: the cannon keeps its facing")

	# --- Direct ball checks (CannonBalls.launch) ---
	var y: float = cfg.ball_height
	# Dirt: from (8.5, 4.5) east into D at (12, 4).
	_destroyed.clear()
	var slot: int = balls.launch(Vector3(8.5, y, 4.5), Vector3.RIGHT, 0.2)
	await _frames(40)
	_check(map.type_at(Vector2i(12, 4)) == MapLegend.FLOOR, "a ball destroys the dirt it hits")
	_check(_dirt.size() == 1 and _dirt[0][0] == Vector2i(12, 4) and _dirt[0][1] == &"cannon", "dirt_destroyed with the cannon cause: %s" % [_dirt])
	_check(_destroyed.size() == 1 and _destroyed[0][0] == &"dirt", "destructible_destroyed for the dirt: %s" % [_destroyed])
	_check(balls.state_of(slot) != FLYING, "the ball is spent on the hit")
	_check(map.type_at(Vector2i(13, 4)) == MapLegend.DIRT, "only the hit cell is destroyed")
	# Gargoyle: from (8.5, 5.5) west into the 2x2 at (3..4, 5..6).
	_destroyed.clear()
	var registry = main.get_node("Destructibles")
	_check(registry.kind_at(Vector2i(4, 6)) == &"gargoyle", "the registry knows the gargoyle")
	balls.launch(Vector3(8.5, y, 5.5), Vector3.LEFT, 0.2)
	await _frames(40)
	var all_floor: bool = true
	for gy in range(5, 7):
		for gx in range(3, 5):
			all_floor = all_floor and map.type_at(Vector2i(gx, gy)) == MapLegend.FLOOR
	_check(all_floor, "the whole gargoyle footprint is floor")
	_check(_destroyed.size() == 1 and _destroyed[0][0] == &"gargoyle" and _destroyed[0][1] == Rect2i(3, 5, 2, 2), "destructible_destroyed for the whole gargoyle: %s" % [_destroyed])
	_check(map.large_object_at(Vector2i(3, 5)) == null, "no large object there any more")
	_check(not GlyphLightOcclusion.blocks(map, Vector2i(3, 5)), "light passes the destroyed gargoyle")
	var lview = main.get_node("LargeObjectView")
	_check(lview.call("piece_count") == 1 and not lview.call("piece_visible", 0), "the gargoyle piece is hidden")
	var body: StaticBody3D = loader.large_body(map.large_objects[1] if map.large_objects[0].type == &"cannon" else map.large_objects[0])
	_check(body != null and (body.get_child(0) as CollisionShape3D).disabled, "the gargoyle collision is off")
	# Teleport: from (15.5, 9.5) west into pad 0 (10..12, 8..10).
	_destroyed.clear()
	balls.launch(Vector3(15.5, y, 9.5), Vector3.LEFT, 0.2)
	await _frames(40)
	_check(_destroyed.size() == 1 and _destroyed[0][0] == &"teleport" and _destroyed[0][1] == Rect2i(10, 8, 3, 3), "destructible_destroyed for the teleport pad: %s" % [_destroyed])
	_check(map.teleport_at_centre(Vector2i(11, 9)) == -1, "the destroyed pad no longer teleports")
	player.global_position = loader.cell_to_world(Vector2i(11, 9))
	await _frames(6)
	_check(not main.get_node("TeleportSystem").call("is_active"), "stepping on the destroyed pad does nothing")
	player.global_position = loader.cell_to_world(Vector2i(12, 12))
	await _frames(2)
	# Wall bounce: from (17.5, 2.5) east into the wall at x = 20.
	slot = balls.launch(Vector3(17.5, y, 2.5), Vector3.RIGHT, 0.2)
	await _frames(30)
	_check(balls.state_of(slot) == FLYING and balls.velocity_of(slot).x < 0.0, "a ball bounces off a wall (v %s)" % balls.velocity_of(slot))
	_check(is_equal_approx(balls.velocity_of(slot).length(), cfg.ball_speed_cells * cfg.bounce_keep), "the bounce keeps the speed")
	balls.clear()
	# Cannon bounce: from (8.5, 2.5) west into the cannon at (3, 2).
	slot = balls.launch(Vector3(8.5, y, 2.5), Vector3.LEFT, 0.2)
	await _frames(40)
	_check(balls.state_of(slot) == FLYING and balls.velocity_of(slot).x > 0.0, "a ball bounces off a cannon")
	balls.clear()
	# Player bounce: from 3 cells east of the player, flying west.
	var p0: Vector3 = player.global_position
	var player_bounces: int = balls.player_bounces
	slot = balls.launch(p0 + Vector3(3.0, y, 0.0), Vector3.LEFT, 0.2)
	await _frames(30)
	_check(balls.player_bounces == player_bounces + 1 and balls.velocity_of(slot).x > 0.0, "a ball bounces off the player")
	_check(not _run_ended and main.get_node("RunManager").get("phase") == PHASE_PLAYING, "the ball does not hurt the player")
	balls.clear()
	# Range: along the free row 1, bouncing between the walls, until 100 cells, then fading.
	slot = balls.launch(Vector3(1.5, y, 1.5), Vector3.RIGHT, 0.2)
	var flight: float = cfg.range_cells / cfg.ball_speed_cells
	await _wait(flight * 0.9)
	_check(balls.state_of(slot) == FLYING, "still flying at 90%% of the range (travelled %.1f)" % balls.travelled(slot))
	var guard: int = 0
	while balls.state_of(slot) == FLYING and guard < 240:
		await physics_frame
		guard += 1
	_check(balls.state_of(slot) == FADING, "fading at the end of the range")
	_check(absf(balls.travelled(slot) - cfg.range_cells) < 0.01, "travelled exactly the range (%.2f)" % balls.travelled(slot))
	_check(balls.bounces > 0, "bounced on the way")
	await _wait(cfg.fade_seconds + 0.1)
	_check(balls.state_of(slot) == 0, "gone after the fade")

	# --- Tap = 1 ball; cone. Player west of the cannon: it faces east. ---
	player.global_position = loader.cell_to_world(CANNON + Vector2i(-1, 0))
	await _wait(0.6)
	_check(inter.focus() == c, "the cannon is in reach")
	_fired_frames.clear()
	_fired_dirs.clear()
	Input.action_press(&"interact")
	_check(inter.press(), "press goes to the cannon")
	await _frames(4)
	Input.action_release(&"interact")
	await _frames(30)
	_check(_fired_frames.size() == 1, "a tap fires one ball (%d)" % _fired_frames.size())

	# --- Hold 8.5 s: one ball at the press, autofire from 2 s at ~1/s rising to 5/s by 6 s. ---
	_fired_frames.clear()
	_fired_dirs.clear()
	Input.action_press(&"interact")
	inter.press()
	var t0: int = Engine.get_physics_frames()
	var hz: float = float(Engine.physics_ticks_per_second)
	while (Engine.get_physics_frames() - t0) / hz < 8.5:
		await physics_frame
	Input.action_release(&"interact")
	await _frames(2)
	var w_first: int = _count(t0, hz, 0.0, 0.1)
	var w_quiet: int = _count(t0, hz, 0.1, 1.95)
	var w_start: int = _count(t0, hz, 1.95, 3.0)
	var w_full: int = _count(t0, hz, 6.5, 8.5)
	print("[cannon] hold: %d at press, %d in 0.1-1.95 s, %d in 1.95-3 s, %d in 6.5-8.5 s (%d total)" % [w_first, w_quiet, w_start, w_full, _fired_frames.size()])
	_check(w_first == 1 and w_quiet == 0, "one ball at the press, none until 2 s (%d, %d)" % [w_first, w_quiet])
	_check(w_start >= 1 and w_start <= 2, "autofire starts at ~1/s (%d in the first second)" % w_start)
	_check(w_full >= 9 and w_full <= 11, "autofire at 5/s after 6 s (%d in 2 s)" % w_full)
	_check(_count(t0, hz, 3.0, 6.0) > 3 * 1 + 1, "the rate rises between 3 and 6 s")
	var worst: float = 0.0
	var spread_min: float = INF
	var spread_max: float = -INF
	for d in _fired_dirs:
		var a: float = angle_difference(c.facing, atan2(d.z, d.x))
		worst = maxf(worst, absf(a))
		spread_min = minf(spread_min, a)
		spread_max = maxf(spread_max, a)
	_check(worst <= deg_to_rad(cfg.cone_degrees * 0.5) + 0.001, "every ball within +-15 degrees (worst %.1f)" % rad_to_deg(worst))
	_check(spread_max - spread_min > deg_to_rad(cfg.cone_degrees * 0.5), "balls spread over the cone (%.1f degrees)" % rad_to_deg(spread_max - spread_min))
	_check(not _run_ended, "the player was never hurt")

	_done = true
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAP_PATH))
	Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)


## Balls fired in [from, to) seconds after physics frame t0.
func _count(t0: int, hz: float, from: float, to: float) -> int:
	var n: int = 0
	for fr in _fired_frames:
		var t: float = (fr - t0) / hz
		if t >= from - 0.0001 and t < to - 0.0001:
			n += 1
	return n
