extends SceneTree
## Headless test of adaptive input discovery (task-008) and player movement (task-009)
## on the real main scene.
## Usage: godot --headless --path . -s tools/test_input_movement.gd

const PHASE_PLAYING := 1
var _failures: PackedStringArray = []
var _discovered: Array[StringName] = []


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


func _stick(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _mouse_move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _mouse_button(button: MouseButton, pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	root.get_node("SignalBus").connect("input_scheme_discovered", func(s: StringName) -> void: _discovered.append(s))
	var main := _make_main()
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var player: CharacterBody3D = main.get_node("Player")
	var loader: MapLoader = main.get_node("World/MapLoader")
	var discovery: Node = main.get_node("InputDiscovery")
	await _wait(0.6)
	_check(runs.get("phase") == PHASE_PLAYING, "run should be playing")
	var spawn: Vector3 = loader.spawn_position

	# --- Before discovery nothing moves, even with a movement action held without an event. ---
	_check((runs.get("state") as RunState).input_scheme == InputScheme.NONE, "scheme must start NONE")
	Input.action_press(&"move_right")
	await _wait(0.4)
	Input.action_release(&"move_right")
	_check(player.global_position.distance_to(spawn) < 0.01, "player moved before any input was discovered")

	# --- Unsupported inputs change nothing. ---
	_key(KEY_Z, true)
	_key(KEY_Z, false)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(100, 100))
	_mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(100, 100))
	var pad_button := InputEventJoypadButton.new()
	pad_button.button_index = JOY_BUTTON_A
	pad_button.pressed = true
	Input.parse_input_event(pad_button)
	var pad_release := pad_button.duplicate() as InputEventJoypadButton
	pad_release.pressed = false
	Input.parse_input_event(pad_release)
	_stick(JOY_AXIS_RIGHT_X, 1.0)
	_stick(JOY_AXIS_RIGHT_X, 0.0)
	_stick(JOY_AXIS_LEFT_X, 0.1)
	_stick(JOY_AXIS_LEFT_X, 0.0)
	await _wait(0.2)
	_check(_discovered.is_empty(), "unsupported input emitted a scheme: %s" % [_discovered])
	_check(discovery.get("scheme") == InputScheme.NONE and (runs.get("state") as RunState).input_scheme == InputScheme.NONE, "unsupported input changed the scheme")
	_check(player.global_position.distance_to(spawn) < 0.01, "player moved on unsupported input")

	# --- Keyboard: the very first press both registers and moves (not swallowed). ---
	_key(KEY_D, true)
	await process_frame
	_check(_discovered.size() == 1 and _discovered[0] == InputScheme.KEYBOARD, "keyboard not discovered: %s" % [_discovered])
	_check((runs.get("state") as RunState).input_scheme == InputScheme.KEYBOARD, "RunState should store keyboard")
	await _wait(0.4)
	_check(player.global_position.x > spawn.x + 0.5, "D did not move the player right (x=%f)" % player.global_position.x)
	_check(absf(player.global_position.z - spawn.z) < 0.05, "D drifted on z")
	_key(KEY_D, false)
	await _wait(0.5)
	var rest: Vector3 = player.global_position
	await _wait(0.2)
	_check(player.velocity.length() < 0.01 and rest.distance_to(player.global_position) < 0.01, "movement did not stop when input stopped")
	# Another keyboard key keeps the scheme and does not re-emit.
	_key(KEY_LEFT, true)
	await _wait(0.3)
	_key(KEY_LEFT, false)
	_check(_discovered.size() == 1, "same scheme must not re-emit")
	_check(player.global_position.x < rest.x - 0.3, "arrow left did not move left")

	# --- Gamepad switch: left stick down moves +z. ---
	await _wait(0.4)
	var before: Vector3 = player.global_position
	_stick(JOY_AXIS_LEFT_Y, 1.0)
	await process_frame
	_check(discovery.get("scheme") == InputScheme.GAMEPAD and _discovered.size() == 2, "gamepad not discovered: %s" % [_discovered])
	await _wait(0.3)
	_stick(JOY_AXIS_LEFT_Y, 0.0)
	_check(player.global_position.z > before.z + 0.3, "stick down did not move +z")
	await _wait(0.4)

	# --- Mouse switch: hold left button with the cursor to the left of the player. ---
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	_check(camera != null, "no camera")
	var start: Vector3 = player.global_position
	var cursor: Vector2 = camera.unproject_position(start + Vector3(-3.0, 0.0, 0.0))
	_mouse_move(cursor)
	_mouse_button(MOUSE_BUTTON_LEFT, true, cursor)
	await process_frame
	_check(discovery.get("scheme") == InputScheme.MOUSE and (runs.get("state") as RunState).input_scheme == InputScheme.MOUSE, "mouse not discovered")
	await _wait(0.5)
	_check(player.global_position.x < start.x - 0.5, "mouse did not move the player toward the cursor (x %f -> %f)" % [start.x, player.global_position.x])
	_check(absf(player.global_position.z - start.z) < 0.1, "mouse movement drifted on z")
	_mouse_button(MOUSE_BUTTON_LEFT, false, cursor)
	await _wait(0.5)
	_check(player.velocity.length() < 0.01, "mouse movement did not stop on release")
	# With the button held the player stops at the cursor, not past it.
	var target: Vector3 = player.global_position + Vector3(0.0, 0.0, 1.0)
	var near: Vector2 = camera.unproject_position(target)
	_mouse_move(near)
	_mouse_button(MOUSE_BUTTON_LEFT, true, near)
	await _wait(1.2)
	_mouse_button(MOUSE_BUTTON_LEFT, false, near)
	_check(absf(player.global_position.z - target.z) < 0.25, "player overshot the cursor (z %f, target %f)" % [player.global_position.z, target.z])

	# --- Back to keyboard: scheme switches, never stuck. ---
	_key(KEY_A, true)
	await process_frame
	_check(discovery.get("scheme") == InputScheme.KEYBOARD and _discovered.size() == 4, "did not switch back to keyboard: %s" % [_discovered])
	_key(KEY_A, false)
	await _wait(0.3)

	# --- Walls block: walk down from the spawn into the wall at row 15. ---
	player.global_position = spawn
	player.velocity = Vector3.ZERO
	_key(KEY_S, true)
	await _wait(2.5)
	_key(KEY_S, false)
	var wall_z: float = 15.0 - (player.get("config") as PlayerConfig).body_radius
	_check(player.global_position.z <= wall_z + 0.02, "player passed through the wall (z=%f, limit %f)" % [player.global_position.z, wall_z])
	_check(player.global_position.z > wall_z - 0.2, "player stopped well short of the wall (z=%f)" % player.global_position.z)

	# --- The scheme survives a restart, and movement still works at once. ---
	runs.call("end_run", &"test")
	await _wait(0.3)
	_check(runs.get("phase") == PHASE_PLAYING and (runs.get("state") as RunState).input_scheme == InputScheme.KEYBOARD, "scheme not carried into the next run")
	_check(player.global_position.distance_to(spawn) < 0.01, "player not back at spawn")
	_key(KEY_W, true)
	await _wait(0.3)
	_key(KEY_W, false)
	_check(player.global_position.z < spawn.z - 0.3, "no movement after restart")

	# --- Bounds: void cells and map edges block. ---
	var void_map := "     \n .@. \n     \n"
	loader.build(loader.parse_text(void_map))
	player.call("spawn")
	_key(KEY_A, true)
	await _wait(1.2)
	_key(KEY_A, false)
	var radius: float = (player.get("config") as PlayerConfig).body_radius
	_check(player.global_position.x >= 1.0 + radius - 0.02, "player entered the void on the left (x=%f)" % player.global_position.x)
	_key(KEY_W, true)
	await _wait(1.2)
	_key(KEY_W, false)
	_check(player.global_position.z >= 1.0 + radius - 0.02, "player entered the void above (z=%f)" % player.global_position.z)
	# Floor right at the map edge: the outer slabs must stop the player.
	loader.build(loader.parse_text("...\n.@.\n...\n"))
	player.call("spawn")
	for code: Key in [KEY_A, KEY_W]:
		_key(code, true)
	await _wait(1.5)
	for code: Key in [KEY_A, KEY_W]:
		_key(code, false)
	_check(player.global_position.x >= radius - 0.02 and player.global_position.z >= radius - 0.02, "player left the map rectangle: %s" % player.global_position)

	main.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS test_input_movement")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_input_movement")
		quit(1)
