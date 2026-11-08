extends SceneTree
## Headless test of the interact control (task-072) on the arena (its 1x1 cannon at (18, 24) is an Interactable):
## the InputMap action; in reach (a cell next to the footprint) a left click goes to the object and does NOT walk the
## player, the hint glyph shows; out of reach a click walks as before and nothing is held; Space in reach opens nothing
## (the menu stays shut) and is held by the object; with the menu open Space confirms the menu as before; gamepad X
## interacts too; the hold is cancelled when the player leaves the reach.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_interact.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "interact"
const ARENA := "res://data/maps/m2_arena.txt"
const PHASE_PLAYING := 1
const CANNON_CELL := Vector2i(18, 24)
## Standing still: moved less than this (world units).
const STILL := 0.05

var _failures: PackedStringArray = []
## Set when the scene part ran to its end (a script error aborts it silently otherwise).
var _done: bool = false
var _menu_events: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	_check_input_map()
	await _check_scene()
	_check(_done, "the scene checks ran to the end")
	if _failures.is_empty():
		print("PASS test_interact")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_interact")
		quit(1)


func _check_input_map() -> void:
	_check(InputMap.has_action(&"interact"), "InputMap has interact")
	var keys: bool = false
	var mouse: bool = false
	var pad: bool = false
	for e in InputMap.action_get_events(&"interact"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_SPACE:
			keys = true
		elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			mouse = true
		elif e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_X:
			pad = true
	_check(keys and mouse and pad, "interact = Space, left mouse, gamepad X (%s %s %s)" % [keys, mouse, pad])


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _mouse(pressed: bool, pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _pad(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


func _place(player: CharacterBody3D, loader: MapLoader, cell: Vector2i) -> void:
	player.global_position = loader.cell_to_world(cell)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame


func _check_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 1
	seeded.death_count = 1
	seeded.menu_unlocked = true
	ResourceSaver.save(seeded, save_path)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = ARENA
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.4)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("menu_opened", func(_l: PackedStringArray, _s: int) -> void: _menu_events += 1)
	bus.connect("menu_closed", func() -> void: _menu_events += 1)
	var inter = main.get_node("Interactables")
	var hint: Node = main.get_node("InteractHintView")
	var menu: Node = main.get_node("MenuController")
	var balls = main.get_node("CannonBalls")
	var player: CharacterBody3D = main.get_node("Player")
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	_check(inter.count() == 2, "the arena's two cannons are registered (%d)" % inter.count())
	runs.get("state").set("input_scheme", InputScheme.MOUSE)

	# --- In reach: the click goes to the cannon, the player does not walk. ---
	await _place(player, loader, CANNON_CELL + Vector2i(1, 0))
	_check(inter.focus() != null and inter.focus().footprint.position == CANNON_CELL, "the 1x1 cannon is in reach")
	_check(bool(hint.call("is_showing")), "hint glyph shows in reach")
	var start: Vector3 = player.global_position
	var cursor: Vector2 = camera.unproject_position(start + Vector3(3.0, 0.0, 0.0))
	var launched: int = balls.launched
	_mouse(true, cursor)
	await physics_frame
	await physics_frame
	_check(inter.is_holding(), "a click in reach is held by the cannon")
	_check(balls.launched == launched + 1, "the click fired one ball (%d)" % (balls.launched - launched))
	for i in 20:
		_mouse(true, cursor)
		await physics_frame
	_check(player.global_position.distance_to(start) < STILL, "a click in reach does not walk the player (moved %.3f)" % player.global_position.distance_to(start))
	_mouse(false, cursor)
	await physics_frame
	await physics_frame
	_check(not inter.is_holding(), "released with the button")

	# --- Out of reach: the click walks as before, nothing is held. ---
	await _place(player, loader, CANNON_CELL + Vector2i(4, 0))
	_check(inter.focus() == null, "nothing in reach 4 cells away")
	_check(not bool(hint.call("is_showing")), "no hint out of reach")
	start = player.global_position
	cursor = camera.unproject_position(start + Vector3(0.0, 0.0, -3.0))
	launched = balls.launched
	_mouse(true, cursor)
	for i in 20:
		_mouse(true, camera.unproject_position(start + Vector3(0.0, 0.0, -3.0)))
		await physics_frame
	_check(not inter.is_holding(), "out of reach nothing is held")
	_check(player.global_position.distance_to(start) > 0.3, "a click out of reach walks (moved %.3f)" % player.global_position.distance_to(start))
	_check(balls.launched == launched, "no ball out of reach")
	_mouse(false, cursor)
	await _wait(0.4)

	# --- Space in reach: held by the cannon, the menu stays shut. ---
	runs.get("state").set("input_scheme", InputScheme.KEYBOARD)
	await _place(player, loader, CANNON_CELL + Vector2i(0, -1))
	_menu_events = 0
	_key(KEY_SPACE, true)
	await physics_frame
	await physics_frame
	_check(inter.is_holding(), "Space in reach is held by the cannon")
	_check(not menu.call("is_open") and _menu_events == 0, "Space in reach opens nothing")
	# Leaving the reach cancels the hold.
	player.global_position = loader.cell_to_world(CANNON_CELL + Vector2i(0, -4))
	await physics_frame
	await physics_frame
	_check(not inter.is_holding(), "leaving the reach cancels the hold")
	_key(KEY_SPACE, false)
	await physics_frame

	# --- Menu open in reach: Space confirms the menu, not the cannon. ---
	await _place(player, loader, CANNON_CELL + Vector2i(0, 1))
	_check(menu.call("open"), "menu opens")
	await physics_frame
	_check(inter.focus() != null, "still in reach with the menu open")
	_menu_events = 0
	launched = balls.launched
	_key(KEY_SPACE, true)
	await physics_frame
	_key(KEY_SPACE, false)
	await physics_frame
	_check(not inter.is_holding() and balls.launched == launched, "Space with the menu open does not interact")
	_check(_menu_events > 0, "Space with the menu open still confirms the menu")
	menu.call("close")
	await physics_frame

	# --- Gamepad X interacts too. ---
	_pad(JOY_BUTTON_X, true)
	await physics_frame
	await physics_frame
	_check(inter.is_holding(), "gamepad X in reach is held by the cannon")
	_pad(JOY_BUTTON_X, false)
	await physics_frame
	await physics_frame
	_check(not inter.is_holding(), "gamepad X released")
	_done = true

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
