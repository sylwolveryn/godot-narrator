extends SceneTree
## Headless test of the death marks (task-093), in the main scene:
##  - a death keeps the world: eaten dirt, a destroyed enemy and its diamonds stay for the next run; SignalBus.world_reset
##    (the first run / RunConfig.keep_world_on_death off) puts the map back;
##  - every death stains the drawn cells around it (the stain texture of the surface material follows), the stained
##    tiles are counted, and the death that passes another 10 throws an invulnerability item (⚛) near it;
##  - picking the item up makes the player invulnerable for DeathMarksConfig.invulnerable_seconds: spikes and corruption
##    do nothing, a touching enemy is destroyed instead; the shield glyphs are drawn around the player;
##  - stains survive a world reset (they last for the whole launch).
## Usage: godot --headless --max-fps 30 --path . -s tools/test_death_marks.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "death_marks"
const MAP_PATH := "user://test_death_marks_map.txt"
const PHASE_PLAYING := 1

var _failures: PackedStringArray = []
var _ended: Array[StringName] = []
var _destroyed: Array[StringName] = []
var _done: bool = false


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_end_requested", func(c: StringName) -> void: _ended.append(c))
	bus.connect("enemy_destroyed", func(_k: StringName, _c: Vector2i, _w: Vector3, cause: StringName) -> void: _destroyed.append(cause))
	await _check_scene()
	_check(_done, "the scene checks ran to the end")
	if _failures.is_empty():
		print("PASS test_death_marks")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_death_marks")
		quit(1)


func _check_scene() -> void:
	# Two wanderers shut in dirt pockets (they cannot reach the player); spikes and corruption in the open.
	var lines: PackedStringArray = PackedStringArray([
		"################",
		"#......DDDD.DDDD#",
		"#.@....DW.D.DW.D#",
		"#......DDDD.DDDD#",
		"#.^^...%%%......#",
		"#...............#",
		"################",
	])
	var f := FileAccess.open(MAP_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	var run_cfg := RunConfig.new()
	run_cfg.restart_delay = 0.2
	run_cfg.intro_on_restart = false
	main.get_node("RunManager").set("config", run_cfg)
	# Respawn invulnerability (task-095) is covered by test_respawn_invulnerability; off here so only the item grants it.
	main.get_node("Invulnerability").set("respawn_seconds", 0.0)
	# Task-104 picks a random radius from the DB range; this test checks the exact 3x3 spray of radius 1.5.
	main.get_node("DeathMarks").set("radius_override", 1.5)
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = MAP_PATH
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	await _until_playing(runs)
	var player: CharacterBody3D = main.get_node("Player")
	var sys: Node = main.get_node("EnemySystem")
	var rem: Node = main.get_node("EnemyRemains")
	var dirt: Node = main.get_node("DirtWalls")
	var marks: Node = main.get_node("DeathMarks")
	var view: Node = main.get_node("DeathMarksView")
	var shield: Node = main.get_node("Invulnerability")
	var material: ShaderMaterial = load("res://resources/glyphs/glyph_surface_material.tres")
	_check(sys.call("count") == 2, "two enemies on the map, got %d" % sys.call("count"))

	# --- change the world, then die: the next run keeps it ---
	_check(dirt.call("destroy", Vector2i(10, 1), &"eaten"), "a dirt cell is destroyed")
	_check(sys.call("destroy", sys.call("cell_of", 1), &"test"), "an enemy is destroyed")
	var diamonds: int = rem.call("diamond_count")
	_check(diamonds > 0, "the destroyed wanderer left diamonds")
	player.global_position = loader.cell_to_world(Vector2i(5, 5))
	await _frames(2)
	runs.call("end_run", &"test")
	await _until_playing(runs)
	_check(not dirt.call("is_dirt", Vector2i(10, 1)), "a death keeps the eaten dirt")
	_check(not sys.call("is_alive", 1) and sys.call("is_alive", 0), "a death keeps the destroyed enemy dead")
	_check(rem.call("diamond_count") == diamonds, "a death keeps the diamonds (%d)" % rem.call("diamond_count"))

	# --- the stain of that death ---
	_check(int(marks.get("total_tiles")) == 9, "radius 1.5 sprays the 3x3 cells around the death: %d" % int(marks.get("total_tiles")))
	_check(marks.call("stain_at", Vector2i(5, 5)) > marks.call("stain_at", Vector2i(4, 4)) and marks.call("stain_at", Vector2i(4, 4)) > 0.0, "strongest at the death cell")
	_check(marks.call("stain_at", Vector2i(5, 6)) > 0.0, "the wall below is stained too")
	_check((marks.call("items") as Dictionary).is_empty(), "no item before 10 tiles")
	var img: Image = view.call("stain_image")
	_check(img != null and img.get_pixel(5, 5).r > 0.0 and img.get_pixel(1, 1).r == 0.0, "the stain texture holds the stain")
	_check((material.get_shader_parameter(&"stain_style") as Vector4).x == 1.0, "the surface material turns the stain on")

	# --- the second death passes 10 tiles: an item ---
	player.global_position = loader.cell_to_world(Vector2i(12, 5))
	await _frames(2)
	runs.call("end_run", &"test")
	await _until_playing(runs)
	_check(int(marks.get("total_tiles")) == 18, "two deaths, 18 tiles: %d" % int(marks.get("total_tiles")))
	_check((marks.call("items") as Dictionary).size() == 1, "the death passing 10 tiles drops one item")
	var item_cell: Vector2i = (marks.call("items") as Dictionary).keys()[0] if not (marks.call("items") as Dictionary).is_empty() else Vector2i(-1, -1)
	_check(item_cell.distance_to(Vector2i(12, 5)) <= 3.0, "the item lands near the death: %s" % item_cell)
	_check(not shield.call("is_active"), "not invulnerable before the pickup")

	# --- pick it up ---
	player.global_position = loader.cell_to_world(item_cell)
	await _frames(3)
	_check((marks.call("items") as Dictionary).is_empty() and int(marks.get("taken")) == 1, "walking over the item picks it up")
	_check(shield.call("is_active") and float(shield.get("remaining")) > 590.0, "invulnerable for 10 minutes: %.1f" % float(shield.get("remaining")))

	# --- hazards do nothing ---
	_ended.clear()
	player.global_position = loader.cell_to_world(Vector2i(2, 4))
	await _frames(20)
	_check(_ended.is_empty() and runs.get("phase") == PHASE_PLAYING, "spikes do not kill the invulnerable player")
	player.global_position = loader.cell_to_world(Vector2i(8, 4))
	await _frames(240)
	_check(_ended.is_empty() and runs.get("phase") == PHASE_PLAYING, "corruption does not kill the invulnerable player")

	# --- an enemy touching the player dies ---
	_destroyed.clear()
	player.global_position = sys.call("position_of", 0)
	await _frames(3)
	_check(not sys.call("is_alive", 0), "the touching enemy is destroyed")
	_check(_destroyed.has(&"invulnerable"), "with the invulnerable cause: %s" % [_destroyed])
	_check(_ended.is_empty() and runs.get("phase") == PHASE_PLAYING, "the run goes on")

	# --- the shield ---
	player.global_position = loader.cell_to_world(Vector2i(3, 5))
	await process_frame
	await process_frame
	var ring: int = (marks.get("config").ring_text as String).length() * (marks.get("config").ring_radii as PackedFloat32Array).size()
	_check(int(view.get("shield_drawn")) == ring, "the shield draws %d glyphs, got %d" % [ring, int(view.get("shield_drawn"))])

	# --- a world reset puts the map back, the stains stay ---
	root.get_node("SignalBus").emit_signal("world_reset")
	_check(dirt.call("is_dirt", Vector2i(10, 1)) and sys.call("is_alive", 0) and sys.call("is_alive", 1), "world_reset restores the map")
	_check(rem.call("diamond_count") == 0, "world_reset clears the diamonds")
	_check(int(marks.get("total_tiles")) == 18 and marks.call("stain_at", Vector2i(5, 5)) > 0.0, "the stains last for the launch")

	_done = true
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAP_PATH))
	Support.remove_file(save_path)


func _until_playing(runs: Node) -> void:
	var guard: float = 0.0
	await _wait(0.1)
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
