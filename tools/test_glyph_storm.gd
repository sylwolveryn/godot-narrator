extends SceneTree
## Headless test of the glyph storm (task-030): a struck nature (SignalBus.origin_struck, through the real OriginLedger) and
## the generic SignalBus.glyph_storm_requested both start a storm; it never pauses the tree and the player keeps control
## of the movement; after its duration it ends and the view stops processing, hides its quads and un-dims the floor; a
## second trigger during a storm restarts it cleanly (one storm at a time, one end); the MultiMesh is allocated once up
## front and starting a storm is cheap (the measured microseconds are printed; the assertion is tolerant for headless).
## Usage: godot --headless --max-fps 30 --path . -s tools/test_glyph_storm.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "glyph_storm"
const PHASE_PLAYING := 1
## Generous bound for the CPU cost of starting a storm, in microseconds (the dev PC measures well under 2 ms).
const START_BUDGET_USEC := 5000
const SHORT := 0.7

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _run() -> void:
	var config := load("res://resources/config/storm_config.tres") as StormConfig
	_check(config != null and config.glyph_cap <= 800 and config.glyph_count <= config.glyph_cap, "storm config loads with a glyph cap <= 800")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 3
	ResourceSaver.save(seeded, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.4)
	var bus: Node = root.get_node("SignalBus")
	var view: Node = main.get_node("GlyphStormView")
	var player := main.get_node("Player") as CharacterBody3D
	var ledger: Node = main.get_node("OriginLedger")
	var surface := load("res://resources/glyphs/glyph_surface_material.tres") as ShaderMaterial
	_check(view != null, "Main has a GlyphStormView")
	_check(not view.call("is_active") and not view.is_processing(), "no storm and no processing at rest")
	_check(view.call("capacity") == config.glyph_cap, "the MultiMesh is allocated once with the configured cap")
	_check(not (view.get_node("Storm") as MultiMeshInstance3D).visible, "the storm quads are hidden at rest")

	# --- origin_struck (through the real ledger) starts a storm ---
	_check(ledger.call("strike", &"ai", 3), "the ledger strikes ai")
	_check(view.call("is_active") and int(view.get("storms_started")) == 1, "origin_struck starts a storm")
	_check(view.is_processing(), "the view processes while a storm runs")
	_check(view.call("glyph_count") >= 1 and view.call("glyph_count") <= config.glyph_cap, "the storm draws between 1 and cap glyphs")
	_check(not paused, "the tree is not paused at the start")
	var physics_frames: Array[int] = [0]
	var tick := func() -> void: physics_frames[0] += 1
	physics_frames[0] = 0
	root.get_tree().physics_frame.connect(tick)

	# --- the player keeps control while it swirls ---
	var before: Vector3 = player.global_position
	_key(KEY_D, true)
	await _wait(0.5)
	_key(KEY_D, false)
	var moved: float = player.global_position.distance_to(before)
	_check(moved > 0.3, "the player still moves during a storm (moved %.2f)" % moved)
	_check(not paused and physics_frames[0] > 5, "physics keeps running during a storm")
	_check(view.call("is_active"), "the storm is still running after half a second")
	_check(view.call("dim_amount") > 0.0, "the surroundings are dimmed while the glyphs are away")
	var zone: Vector4 = surface.get_shader_parameter(&"storm_zone")
	_check(zone.w > 0.0, "the world material's storm_zone is on")

	# --- ends after its duration, processing stops, nothing left dimmed ---
	var waited: float = 0.0
	while view.call("is_active") and waited < config.duration + 1.5:
		await _wait(0.1)
		waited += 0.1
	_check(not view.call("is_active"), "the storm ends by itself")
	_check(not view.is_processing(), "processing stops when the storm ends")
	_check(not (view.get_node("Storm") as MultiMeshInstance3D).visible, "the quads are hidden when it ends")
	_check(view.call("dim_amount") == 0.0 and (surface.get_shader_parameter(&"storm_zone") as Vector4).w == 0.0, "the floor is no longer dimmed")

	# --- the generic request ---
	var started: int = int(view.get("storms_started"))
	bus.emit_signal("glyph_storm_requested", player.global_position, 4.0, SHORT, Color(1, 0, 0, 1))
	_check(view.call("is_active") and int(view.get("storms_started")) == started + 1, "glyph_storm_requested starts a storm")
	_check(view.call("glyph_count") < config.glyph_count, "a smaller radius draws fewer glyphs (%d)" % view.call("glyph_count"))
	await _wait(SHORT + 0.5)
	_check(not view.call("is_active"), "a requested storm ends after its duration")

	# --- a second trigger during a storm restarts it cleanly ---
	started = int(view.get("storms_started"))
	bus.emit_signal("glyph_storm_requested", player.global_position, 0.0, SHORT, Color(0, 0, 0, 0))
	await _wait(SHORT * 0.6)
	_check(view.call("is_active"), "still running before the restart")
	bus.emit_signal("glyph_storm_requested", player.global_position, 0.0, SHORT, Color(0, 0, 0, 0))
	_check(int(view.get("storms_started")) == started + 2 and view.call("elapsed") < 0.05, "a second trigger restarts the clock")
	await _wait(SHORT * 0.6)
	_check(view.call("is_active"), "the restarted storm outlives the first one's end")
	await _wait(SHORT * 0.6 + 0.4)
	_check(not view.call("is_active") and not view.is_processing(), "the restarted storm ends once, cleanly")
	_check(view.call("dim_amount") == 0.0, "no dim is left behind after a restart")

	# --- start cost ---
	var total: int = 0
	var worst: int = 0
	var runs_n: int = 20
	for i in runs_n:
		view.call("start_storm", player.global_position)
		total += int(view.get("last_start_usec"))
		worst = maxi(worst, int(view.get("last_start_usec")))
	print("STORM start cost: mean %d us, worst %d us over %d starts (glyph_cap %d)" % [total / runs_n, worst, runs_n, config.glyph_cap])
	_check(total / runs_n < START_BUDGET_USEC, "starting a storm costs well under %d us (mean %d)" % [START_BUDGET_USEC, total / runs_n])
	root.get_tree().physics_frame.disconnect(tick)

	main.queue_free()
	await process_frame
	Support.remove_file(path)
	if _failures.is_empty():
		print("PASS test_glyph_storm")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_glyph_storm")
		quit(1)
