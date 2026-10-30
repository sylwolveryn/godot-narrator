extends SceneTree
## Headless test of the intro -> run start -> player spawn flow on the real main scene:
## input during the intro is harmless, the player lands on the map spawn, the identity is
## picked once and reused, restarts skip the intro (or replay it lite when configured).
## Usage: godot --headless --path . -s tools/test_intro_player.gd

const PHASE_INTRO := 0
const PHASE_PLAYING := 1
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
	main.get_node("IntroSequence").set("config", _fast_intro())
	var run_cfg: RunConfig = main.get_node("RunManager").get("config").duplicate()
	run_cfg.restart_delay = 0.0
	run_cfg.intro_on_restart = intro_on_restart
	main.get_node("RunManager").set("config", run_cfg)
	if saved_glyph != "":
		var progress: PersistentProgress = main.get_node("SaveService").get("progress")
		progress.identity_glyph = saved_glyph
	return main


func _send_input_spam() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)


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
	_check(runs.get("phase") == PHASE_INTRO, "input must not skip or break the intro")
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

	if _failures.is_empty():
		print("PASS test_intro_player")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_intro_player")
		quit(1)
