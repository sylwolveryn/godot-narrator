extends SceneTree
## Headless test of the death splat polish (task-104), in the main scene with the bundled DB seed:
##  - the splat radius range comes from the `death_splat` rows per form (default 2-4, brain 4-6, grown = many 4-8; a
##    form without a row uses default) and every death sprays a radius inside the active form's range;
##  - standing on a death stain tints the trail crimson (the ink view tints new drops), the tint lingers
##    DeathMarksConfig.trail_tint_linger seconds after leaving, and the tinted trail leaves crimson marks that do not
##    count towards the item tiles;
##  - a black hole tints the trail dark purple and leaves dark purple marks (stain texture g = 0);
##  - marks survive a world reset and a new run; a new run clears the tint.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_death_splat.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "death_splat"
const MAP_PATH := "user://test_death_splat_map.txt"
const PHASE_PLAYING := 1

var _failures: PackedStringArray = []
var _tints: Array[StringName] = []
var _done: bool = false


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var bus: Node = root.get_node("SignalBus")
	bus.connect("trail_tint_changed", func(k: StringName) -> void: _tints.append(k))
	await _check_scene()
	_check(_done, "the scene checks ran to the end")
	if _failures.is_empty():
		print("PASS test_death_splat")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_death_splat")
		quit(1)


func _check_scene() -> void:
	var lines: PackedStringArray = PackedStringArray([
		"########################################",
		"#......................................#",
		"#.@....................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"########################################",
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
	main.get_node("Invulnerability").set("respawn_seconds", 0.0)
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = MAP_PATH
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	await _until_playing(runs)
	var player: CharacterBody3D = main.get_node("Player")
	var marks = main.get_node("DeathMarks")  # untyped: DeathMarks uses the SignalBus autoload
	var view: Node = main.get_node("DeathMarksView")
	var ink: Node = main.get_node("InkTrailView")
	var rem: Node = main.get_node("EnemyRemains")
	var cfg: DeathMarksConfig = marks.get("config")
	var bus: Node = root.get_node("SignalBus")

	# --- radius ranges from the DB seed ---
	_check(marks.splat_range(EntityForm.SINGLE) == Vector2(2.0, 4.0), "single uses the default row 2-4: %s" % marks.splat_range(EntityForm.SINGLE))
	_check(marks.splat_range(EntityForm.BRAIN) == Vector2(4.0, 6.0), "brain 4-6: %s" % marks.splat_range(EntityForm.BRAIN))
	_check(marks.splat_range(EntityForm.GROWN) == Vector2(4.0, 8.0), "many (grown) 4-8: %s" % marks.splat_range(EntityForm.GROWN))
	_check(marks.splat_range(&"unknown") == Vector2(2.0, 4.0), "a form without a row uses default")

	# --- a death of the many form sprays a radius in 4-8 ---
	bus.emit_signal("entity_form_changed", EntityForm.GROWN, false)
	player.global_position = loader.cell_to_world(Vector2i(14, 5))
	await _frames(2)
	runs.call("end_run", &"test")
	await _until_playing(runs)
	_check(marks.last_radius >= 4.0 and marks.last_radius <= 8.0, "many splat radius in 4-8: %.2f" % marks.last_radius)
	_check(marks.stain_at(Vector2i(14, 5)) > 0.0 and marks.stain_at(Vector2i(17, 5)) > 0.0, "the splat reaches 3 cells away")
	bus.emit_signal("entity_form_changed", EntityForm.SINGLE, false)
	var radii: Array[float] = []
	for i in 12:
		marks.mark_death(loader.cell_to_world(Vector2i(20, 4)))
		radii.append(marks.last_radius)
	_check(radii.min() >= 2.0 and radii.max() <= 4.0 and radii.max() > radii.min(), "single radii random in 2-4: %s" % [radii])
	var tiles: int = marks.total_tiles
	_check(_tints.is_empty() and marks.trail_tint == &"", "no tint before stepping into blood")

	# --- blood: step into the stain, the trail turns crimson ---
	player.global_position = loader.cell_to_world(Vector2i(14, 5))
	await _frames(3)
	_check(marks.trail_tint == &"blood" and _tints.has(&"blood"), "standing in blood tints the trail")
	var tint: Color = ink.call("current_tint")
	_check(tint.a == 1.0 and tint.is_equal_approx(Color(cfg.trail_blood_ink, 1.0)), "new ink drops are crimson: %s" % tint)
	# walk out on clean floor (right of both splats), cells three apart so a spatter cannot reach the next one
	var clean: Array[Vector2i] = []
	for x in range(26, 39, 3):
		var c := Vector2i(x, 7)
		if marks.stain_at(c) == 0.0:
			clean.append(c)
	_check(clean.size() >= 3, "clean floor right of the splats on row 7: %d" % clean.size())
	if clean.size() >= 3:
		player.global_position = loader.cell_to_world(clean[0])
		await _wait(cfg.trail_tint_linger * 0.4)
		player.global_position = loader.cell_to_world(clean[1])
		await _wait(cfg.trail_tint_linger * 0.4)
		_check(marks.trail_tint == &"blood", "still crimson inside the linger time")
		var m: Variant = marks.trail_marks().get(clean[1])
		_check(m is Vector2 and (m as Vector2).x > 0.0 and (m as Vector2).y == 1.0, "the crimson trail marks the floor: %s" % [m])
		await _wait(cfg.trail_tint_linger * 0.4)
		player.global_position = loader.cell_to_world(clean[2])
		await _frames(3)
		_check(marks.trail_tint == &"", "the tint runs out after the linger time")
		_check(not marks.trail_marks().has(clean[2]), "no new mark once the tint ran out")
		_check(ink.call("current_tint").a == 0.0, "the ink is back to normal")
	_check(marks.total_tiles == tiles, "trail marks do not count towards the item tiles")

	# --- void: a black hole tints the trail dark purple ---
	var hole := Vector2i(34, 1)
	var after := Vector2i(36, 1)
	_check(marks.stain_at(hole) == 0.0 and marks.stain_at(after) == 0.0, "the hole corner is clean")
	rem.call("form_black_hole", hole)
	player.global_position = loader.cell_to_world(hole)
	await _frames(3)
	_check(marks.trail_tint == &"void", "a black hole tints the trail void")
	_check((ink.call("current_tint") as Color).is_equal_approx(Color(cfg.trail_void_ink, 1.0)), "new ink drops are dark purple")
	player.global_position = loader.cell_to_world(after)
	await _frames(3)
	var vm: Variant = marks.trail_marks().get(after)
	_check(vm is Vector2 and (vm as Vector2).y == 0.0, "the void trail leaves dark purple marks: %s" % [vm])
	var img: Image = view.call("stain_image")
	_check(img != null and img.get_pixel(after.x, after.y).r > 0.0 and img.get_pixel(after.x, after.y).g < 0.5, "the stain texture shows the void mark")
	_check(img != null and img.get_pixel(14, 5).g > 0.5, "the death stain texel is blood")

	# --- persistence: a new run and a world reset keep the marks; a new run clears the tint ---
	var count: int = marks.trail_marks().size()
	runs.call("end_run", &"test")
	await _until_playing(runs)
	_check(marks.trail_tint == &"", "a new run clears the tint")
	bus.emit_signal("world_reset")
	_check(marks.trail_marks().size() >= count and marks.trail_marks().has(after), "trail marks survive deaths and world resets")

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
