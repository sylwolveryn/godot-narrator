extends SceneTree
## Headless test of the intro -> run start -> player spawn flow on the real main scene:
## non-skip input during the intro is harmless, the skip action ends it at once without leaking (task-050), the player lands on the map spawn, the identity is
## picked once and reused, restarts skip the intro (or replay it lite when configured).
## Usage: godot --headless --path . -s tools/test_intro_player.gd

const PHASE_INTRO := 0
const PHASE_PLAYING := 1
const Support := preload("res://tools/test_support.gd")
var _failures: PackedStringArray = []


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


func _make_main(intro_on_restart: bool, saved_glyph: String = "") -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, "intro_player")
	main.get_node("IntroSequence").set("config", _fast_intro())
	var run_cfg: RunConfig = main.get_node("RunManager").get("config").duplicate()
	run_cfg.restart_delay = 0.0
	run_cfg.intro_on_restart = intro_on_restart
	main.get_node("RunManager").set("config", run_cfg)
	if saved_glyph != "":
		var seeded := PersistentProgress.new()
		seeded.identity_glyph = saved_glyph
		ResourceSaver.save(seeded, save_path)
	return main


## Input that is not the skip action (movement keys, a stray key, the wheel): the intro ignores it.
func _send_input_spam() -> void:
	for code: Key in [KEY_Z, KEY_W, KEY_TAB]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = true
		Input.parse_input_event(key)
		var up := key.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)


## A long intro, so only a skip can end it within the test's waits.
func _slow_intro() -> IntroConfig:
	var cfg := _fast_intro()
	cfg.black_hold = 30.0
	cfg.skip_dissolve_seconds = 0.1
	return cfg


func _press_key(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	Input.parse_input_event(key)


func _mouse(button: MouseButton, pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


## Skipping (task-050): Esc / Space / click end the intro at once, are swallowed (no menu, no input
## scheme, no pointer walk) and also work on the lite restart intro. Each play picks a random colour.
func _run_skip_checks(bus: Node) -> void:
	var main := _make_main(true)
	main.get_node("IntroSequence").set("config", _slow_intro())
	root.add_child(main)
	# Unlock the menu so a leaked Start (also menu_toggle) would visibly open it once the run has started.
	(main.get_node("SaveService").get("progress") as PersistentProgress).menu_unlocked = true
	var intro: Node = main.get_node("IntroSequence")
	var runs: Node = main.get_node("RunManager")
	var player: Node3D = main.get_node("Player")
	var loader: MapLoader = main.get_node("World/MapLoader")
	var discovery: Node = main.get_node("InputDiscovery")
	var menu_opens: Array[int] = []
	var on_menu := func(_labels: PackedStringArray, _sel: int) -> void: menu_opens.append(1)
	bus.connect("menu_opened", on_menu)
	await process_frame
	_check(intro.call("is_active") and runs.get("phase") == PHASE_INTRO, "slow intro should be running")
	var mat := (main.get_node("IntroSequence/Veil") as ColorRect).material as ShaderMaterial
	_check(mat.get_shader_parameter("wave_color") == (intro.get("wave_color") as Color), "shader colour differs from the picked colour")
	var cfg: IntroConfig = intro.get("config")
	var c: Color = (intro.get("wave_color") as Color)
	_check(c.s >= cfg.saturation_range.x - 0.01 and c.s <= cfg.saturation_range.y + 0.01, "saturation %f outside range" % c.s)
	_check(c.v >= cfg.value_range.x - 0.01 and c.v <= cfg.value_range.y + 0.01, "value %f outside range" % c.v)
	_check(float(mat.get_shader_parameter("glow_strength")) == cfg.glow_strength, "glow strength not applied")

	# Non-skip input keeps the intro running.
	_send_input_spam()
	await create_timer(0.2).timeout
	_check(runs.get("phase") == PHASE_INTRO, "non-skip input must not skip the intro")

	# Left click (held) skips: run starts at once, the click never reaches the player or the discovery.
	var colours: Array[Color] = [(intro.get("wave_color") as Color)]
	var cursor := Vector2(40, 40)
	_mouse(MOUSE_BUTTON_LEFT, true, cursor)
	await process_frame
	_check(runs.get("phase") == PHASE_PLAYING, "click should skip to the run at once")
	_check(not Input.is_action_pressed(&"move_pointer"), "skip click leaked into move_pointer")
	var spawn: Vector3 = loader.spawn_position
	await create_timer(0.3).timeout
	_check(not intro.call("is_active") and not (main.get_node("IntroSequence/Veil") as ColorRect).visible, "veil should be gone after the skip dissolve")
	_check(discovery.get("scheme") != InputScheme.MOUSE, "skip click leaked into input discovery")
	_check(player.global_position.distance_to(spawn) < 0.01, "skip click moved the player")
	_mouse(MOUSE_BUTTON_LEFT, false, cursor)
	_check(runs.get("run_count") == 1, "skip should start exactly one run")

	# Lite restart intro: Esc, Space and gamepad Start each skip it; Start never opens the menu.
	var start_button := InputEventJoypadButton.new()
	start_button.button_index = JOY_BUTTON_START
	for code: Key in [KEY_ESCAPE, KEY_SPACE, KEY_NONE]:
		runs.call("end_run", &"test")
		await process_frame
		_check(runs.get("phase") == PHASE_INTRO and intro.call("is_active"), "lite intro should be up")
		colours.append((intro.get("wave_color") as Color))
		if code == KEY_NONE:
			start_button.pressed = true
			Input.parse_input_event(start_button)
		else:
			_press_key(code, true)
		await process_frame
		if code == KEY_NONE:
			var start_up := start_button.duplicate() as InputEventJoypadButton
			start_up.pressed = false
			Input.parse_input_event(start_up)
		else:
			_press_key(code, false)
		_check(runs.get("phase") == PHASE_PLAYING, "skip input %d should skip the lite intro" % code)
		await create_timer(0.3).timeout
		_check(not intro.call("is_active"), "lite intro still up after skip")
	_check(menu_opens.is_empty(), "skip input opened the menu")
	_check(runs.get("run_count") == 4, "expected 4 runs after three lite skips, got %d" % runs.get("run_count"))
	# Random colour per play: three plays all the same colour is (practically) impossible.
	_check(not (colours[0].is_equal_approx(colours[1]) and colours[1].is_equal_approx(colours[2])), "wave colour is not random: %s" % [colours])
	# After the intro, Esc / Space are free again (no capture).
	_check(not intro.call("is_active"), "intro must not capture input after it ended")
	bus.disconnect("menu_opened", on_menu)
	main.queue_free()
	await process_frame


func _run() -> void:
	var bus: Node = root.get_node("SignalBus")
	var intro_requests: Array[bool] = []
	bus.connect("intro_requested", func(lite: bool) -> void: intro_requests.append(lite))

	# --- First launch: random identity, intro, player at spawn. ---
	var main := _make_main(false)
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var player: Node3D = main.get_node("Player")
	var loader: MapLoader = main.get_node("World/MapLoader")
	var save: Node = main.get_node("SaveService")
	var progress: PersistentProgress = save.get("progress")
	_check(runs.get("phase") == PHASE_INTRO, "should start in INTRO")
	_send_input_spam()
	await process_frame
	_send_input_spam()
	_check(runs.get("phase") == PHASE_INTRO, "non-skip input must not skip or break the intro")
	await create_timer(0.6).timeout
	_check(runs.get("phase") == PHASE_PLAYING, "intro should hand off to a run")
	_check(runs.get("run_count") == 1, "exactly one run started")
	_check(player.global_position.is_equal_approx(loader.spawn_position), "player not at spawn: %s vs %s" % [player.global_position, loader.spawn_position])
	var pool: IdentityPool = (player.get("config") as PlayerConfig).identity_pool
	_check(pool.glyphs.has(progress.identity_glyph), "identity '%s' not from pool" % progress.identity_glyph)
	_check(str(player.get("identity_glyph")) == progress.identity_glyph, "player identity differs from stored identity")
	_check(progress.run_count == 1, "progress.run_count should be 1")
	var first_glyph: String = progress.identity_glyph

	# --- Restart (default): no intro, identity reused. ---
	runs.call("end_run", &"test")
	await process_frame
	_check(intro_requests.is_empty(), "restart must not request the intro by default")
	_check(runs.get("phase") == PHASE_PLAYING and runs.get("run_count") == 2, "restart should start run 2")
	_check(progress.identity_glyph == first_glyph and str(player.get("identity_glyph")) == first_glyph, "identity must be reused on restart")
	_check(player.global_position.is_equal_approx(loader.spawn_position), "player not re-placed at spawn after restart")
	main.queue_free()
	await process_frame

	# --- A stored identity is reused, never re-rolled. ---
	var main2 := _make_main(false, "Z")
	root.add_child(main2)
	await create_timer(0.6).timeout
	_check(str(main2.get_node("Player").get("identity_glyph")) == "Z", "stored identity should be reused")
	main2.queue_free()
	await process_frame

	# --- Restart with the lite intro enabled. ---
	var main3 := _make_main(true)
	root.add_child(main3)
	var runs3: Node = main3.get_node("RunManager")
	await create_timer(0.6).timeout
	runs3.call("end_run", &"test")
	await process_frame
	_check(intro_requests == [true], "lite intro should be requested once, got %s" % [intro_requests])
	_check(runs3.get("phase") == PHASE_INTRO, "should be INTRO during the lite intro")
	await create_timer(0.6).timeout
	_check(runs3.get("phase") == PHASE_PLAYING and runs3.get("run_count") == 2, "lite intro should hand off to run 2")
	main3.queue_free()
	await process_frame

	await _run_skip_checks(bus)

	Support.remove_file("user://test_progress_intro_player.tres")
	if _failures.is_empty():
		print("PASS test_intro_player")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_intro_player")
		quit(1)
