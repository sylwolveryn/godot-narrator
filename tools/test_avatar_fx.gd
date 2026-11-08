extends SceneTree
## Tests the avatar look (task-056/057) on the real main scene: AvatarFxConfig reading a DB row, the crystal glow
## uniforms, the lean / stretch of the player glyph while starting, moving and braking, the ink trail drops, and a
## DB reload re-applying the values.
## Usage: godot --headless --path . --max-fps 30 -s tools/test_avatar_fx.gd

const PHASE_PLAYING := 1
const Support := preload("res://tools/test_support.gd")
## Feel values closer than this to rest (lean 0, stretch 1) count as settled.
const SETTLED := 0.02

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await process_frame


func _run() -> void:
	_test_config_row()
	await _test_scene()
	if _failures.is_empty():
		print("PASS test_avatar_fx")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_avatar_fx")
		quit(1)


func _test_config_row() -> void:
	var base := AvatarFxConfig.new()
	var fx: AvatarFxConfig = base.with_row({"crystal_palette": "#ff0000, zz ,#00ff00", "crystal_speed": 0.5,
		"trail_enabled": false, "trail_chars": "~", "trail_color": "#102030", "trail_rim": "nope", "lean_amount": 0.3})
	_check(fx.crystal_palette.size() == 2 and fx.crystal_palette[0] == Color(1, 0, 0), "palette parsed: %s" % [fx.crystal_palette])
	_check(is_equal_approx(fx.crystal_speed, 0.5) and is_equal_approx(fx.lean_amount, 0.3), "floats applied")
	_check(not fx.trail_enabled and fx.trail_chars == "~", "trail flags applied")
	_check(fx.trail_color == Color.html("#102030") and fx.trail_rim == base.trail_rim, "bad colour keeps the fallback")
	_check(base.crystal_speed != 0.5, "the base config is not modified")
	var picked: AvatarFxConfig = base.from_tables({"avatar_fx": [{"profile": "other", "crystal_speed": 9.0}, {"profile": "default", "crystal_speed": 0.2}]})
	_check(is_equal_approx(picked.crystal_speed, 0.2), "from_tables picks the profile row")


func _test_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, "avatar_fx")
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var view: Node = main.get_node("PlayerGlyphView")
	var ink: Node = main.get_node("InkTrailView")
	var db: Node = main.get_node("GameDatabase")
	await _wait(0.6)
	_check(runs.get("phase") == PHASE_PLAYING, "run should be playing")
	var mat: ShaderMaterial = (view.get_node("Actors") as MultiMeshInstance3D).material_override
	_check(float(mat.get_shader_parameter(&"crystal_count")) >= 2.0, "crystal glow on (palette from the seed)")
	var rest: Vector2 = view.call("feel")
	_check(absf(rest.x) < SETTLED and absf(rest.y - 1.0) < SETTLED, "standing still: no lean or stretch, got %s" % rest)

	_key(KEY_D, true)
	await _wait(0.15)
	var start: Vector2 = view.call("feel")
	_check(start.y > 1.0 + SETTLED, "speeding up stretches the glyph, got %s" % start)
	await _wait(0.3)
	var moving: Vector2 = view.call("feel")
	_check(moving.x > SETTLED, "moving right on screen leans right, got %s" % moving)
	_check(int(ink.call("drop_count")) > 0, "moving drops ink")
	_key(KEY_D, false)
	await _wait(0.12)
	var braking: Vector2 = view.call("feel")
	_check(braking.y < 1.0 - SETTLED * 0.5, "braking squashes the glyph, got %s" % braking)
	await _wait(0.6)
	var drops: int = ink.call("drop_count")
	await _wait(0.6)
	var settled: Vector2 = view.call("feel")
	_check(absf(settled.x) < SETTLED and absf(settled.y - 1.0) < SETTLED, "the glyph settles when still, got %s" % settled)
	_check(int(ink.call("drop_count")) == drops, "no ink while standing still")

	# A DB reload re-applies the look.
	var tables: Dictionary = (db.get("tables") as Dictionary).duplicate(true)
	(tables["avatar_fx"][0] as Dictionary)["crystal_palette"] = "#ff0000,#00ff00,#0000ff"
	(tables["avatar_fx"][0] as Dictionary)["trail_lifetime"] = 1.5
	db.emit_signal("tables_loaded", tables)
	_check(float(mat.get_shader_parameter(&"crystal_count")) == 3.0, "reload: crystal palette re-applied")
	var ink_mat: ShaderMaterial = (ink.get_node("Drops") as MultiMeshInstance3D).material_override
	_check(is_equal_approx(float(ink_mat.get_shader_parameter(&"lifetime")), 1.5), "reload: trail lifetime re-applied")

	main.queue_free()
	await process_frame
	Support.remove_file("user://test_progress_avatar_fx.tres")
