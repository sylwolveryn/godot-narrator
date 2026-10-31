extends SceneTree
## Headless test of the in-world menu (task-018): it is unavailable before the configured death count, available and
## persisted after it, opens and closes on the menu_toggle action WITHOUT pausing anything (process and physics keep
## running, hazards still tick), takes over the movement input while open (the player stands still), navigates and
## confirms (the switch item changes the entity form and emits entity_form_changed), and offers the switch item only
## once the entity is unlocked.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_menu.gd

const Support := preload("res://tools/test_support.gd")
const PATH := "user://test_progress_menu_data.tres"
const SAVE_TAG := "menu_main"
const PHASE_PLAYING := 1

var _failures: PackedStringArray = []
var _unlocked_signals: int = 0
var _opened: int = 0
var _closed: int = 0
var _actions: Array = []
var _forms: Array = []
var _physics_frames: int = 0


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


func _tap(code: Key) -> void:
	_key(code, true)
	await _wait(0.05)
	_key(code, false)
	await _wait(0.05)


func _mouse(button: MouseButton, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = pos
	e.global_position = pos
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(0.05)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _wait(0.05)


func _physics_tick() -> void:
	_physics_frames += 1


func _service() -> Node:
	var cfg := SaveConfig.new()
	cfg.save_path = PATH
	var svc: Node = load("res://scripts/core/save_service.gd").new()
	svc.set("config", cfg)
	root.add_child(svc)
	return svc


func _run() -> void:
	Support.remove_file(PATH)
	var bus: Node = root.get_node("SignalBus")
	bus.connect("menu_unlocked", func() -> void: _unlocked_signals += 1)
	bus.connect("menu_opened", func(_l: PackedStringArray, _s: int) -> void: _opened += 1)
	bus.connect("menu_closed", func() -> void: _closed += 1)
	bus.connect("menu_action_requested", func(a: StringName) -> void: _actions.append(a))
	bus.connect("entity_form_changed", func(f: StringName, animate: bool) -> void: _forms.append([f, animate]))
	var cfg := load("res://resources/config/menu_config.tres") as MenuConfig
	_check(cfg != null and cfg.menu_unlock_deaths == 3 and cfg.items.size() >= 2, "menu config loads with threshold 3 and items")
	for action: StringName in [cfg.action_toggle, cfg.action_up, cfg.action_down, cfg.action_confirm]:
		_check(InputMap.has_action(action), "InputMap has %s" % action)

	# --- unlock exactly at the threshold, persisted, sanitised ---
	var svc: Node = _service()
	var controller: Node = load("res://scripts/core/menu_controller.gd").new()
	controller.set("config", cfg)
	controller.set("save_service", svc)
	root.add_child(controller)
	for i in cfg.menu_unlock_deaths - 1:
		bus.emit_signal("run_started", i)
		bus.emit_signal("run_ended", &"test")
		_check(not controller.call("is_unlocked"), "locked before death %d" % cfg.menu_unlock_deaths)
	_check(_unlocked_signals == 0 and not controller.call("open"), "no signal and no open before the threshold")
	bus.emit_signal("run_started", 2)
	bus.emit_signal("run_ended", &"test")
	_check(controller.call("is_unlocked") and _unlocked_signals == 1, "unlocks at the threshold, one signal")
	svc.free()
	controller.free()
	svc = _service()
	_check(svc.get("progress").menu_unlocked, "unlock persisted through save and load")
	svc.free()
	var tampered := PersistentProgress.new()
	tampered.menu_unlocked = true
	tampered.death_count = 5
	ResourceSaver.save(tampered, PATH)
	svc = _service()
	_check(svc.get("progress").menu_unlocked and svc.get("progress").death_count == 5, "unlock survives the sanitiser")
	svc.free()
	Support.remove_file(PATH)

	await _scene_locked(cfg)
	await _scene_unlocked(cfg)
	await _scene_no_entity(cfg)

	if _failures.is_empty():
		print("PASS test_menu")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_menu")
		quit(1)


## Builds the real main scene on an isolated save seeded with the given progress and waits until a run is being played.
func _make_main(tag: String, seeded: PersistentProgress) -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var path: String = Support.isolate_save(main, tag)
	ResourceSaver.save(seeded, path)
	var intro := IntroConfig.new()
	intro.black_hold = 0.05
	intro.wave_fade_in = 0.05
	intro.wave_hold = 0.05
	intro.reveal_duration = 0.05
	main.get_node("IntroSequence").set("config", intro)
	var run_cfg: RunConfig = (main.get_node("RunManager").get("config") as RunConfig).duplicate()
	run_cfg.restart_delay = 0.6
	main.get_node("RunManager").set("config", run_cfg)
	root.add_child(main)
	var guard: float = 0.0
	while main.get_node("RunManager").get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.3)
	return main


func _scene_locked(cfg: MenuConfig) -> void:
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 2
	seeded.death_count = cfg.menu_unlock_deaths - 1
	var main: Node = await _make_main(SAVE_TAG + "_locked", seeded)
	var before: int = _opened
	await _tap(KEY_TAB)
	_check(_opened == before and not main.get_node("MenuController").call("is_open"), "Tab does nothing while the menu is locked")
	_check(not main.get_node("MenuGlyphView").call("is_shown"), "no menu glyphs while locked")
	var path: String = main.get_node("SaveService").get("config").save_path
	main.queue_free()
	await process_frame
	Support.remove_file(path)


func _scene_unlocked(cfg: MenuConfig) -> void:
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 3
	seeded.death_count = cfg.menu_unlock_deaths
	seeded.entity_unlocked = true
	seeded.entity_grow_played = true
	seeded.entity_form = String(EntityForm.SINGLE)
	var main: Node = await _make_main(SAVE_TAG + "_unlocked", seeded)
	var controller: Node = main.get_node("MenuController")
	var view: Node = main.get_node("MenuGlyphView")
	var player: CharacterBody3D = main.get_node("Player")
	var progression: Node = main.get_node("EntityProgression")
	var glyph_view: Node = main.get_node("PlayerGlyphView")
	_check(controller.call("is_unlocked"), "menu is unlocked from the saved death count")
	_check(not view.call("is_shown"), "menu glyphs are hidden while closed")
	var tree := root.get_tree()
	var tick := _physics_tick
	tree.physics_frame.connect(tick)

	# --- opens on the toggle action, never pauses ---
	var frames_before: int = _physics_frames
	var opened_before: int = _opened
	await _tap(KEY_TAB)
	_check(controller.call("is_open") and _opened == opened_before + 1, "Tab opens the menu")
	await _wait(0.3)
	_check(not tree.paused, "the tree is not paused while the menu is open")
	_check(_physics_frames > frames_before + 5, "physics keeps running while the menu is open")
	_check(view.call("is_shown") and view.call("glyph_count") > 30, "menu glyphs are shown (%d)" % view.call("glyph_count"))
	var labels: PackedStringArray = controller.call("current_labels")
	_check(labels.size() == 2 and labels[0] == "become many" and labels[1] == "return", "labels offer the form switch and return: %s" % [labels])

	# --- hazards still tick while the menu is open ---
	var loader: MapLoader = main.get_node("World/MapLoader")
	var corrupt_def: HazardDefinition = loader.legend.hazards.get(MapLegend.CORRUPT)
	corrupt_def.erosion_rate = 1.0
	corrupt_def.erosion_threshold = 20.0
	var cell := Vector2i(-1, -1)
	for y in loader.data.height:
		for x in loader.data.width:
			if cell.x < 0 and loader.data.type_at(Vector2i(x, y)) == MapLegend.CORRUPT:
				cell = Vector2i(x, y)
	var open_pos: Vector3 = loader.cell_to_world(cell)
	player.velocity = Vector3.ZERO
	player.global_position = open_pos
	await _wait(1.0)
	_check(glyph_view.call("shown_level") > 0.0, "erosion still builds while the menu is open (hazards tick)")
	# back to a safe spot for the movement check
	player.global_position = loader.spawn_position
	player.velocity = Vector3.ZERO
	await _wait(0.2)

	# --- movement input drives the menu, the player stands still ---
	var start: Vector3 = player.global_position
	_key(KEY_D, true)
	await _wait(0.5)
	_key(KEY_D, false)
	_check(player.global_position.distance_to(start) < 0.05, "the player stands still while the menu is open (moved %.2f)" % player.global_position.distance_to(start))

	# --- navigation: down wraps to return, up goes back to the switch ---
	_check(controller.call("selected_index") == 0, "starts on the first item")
	await _tap(KEY_DOWN)
	_check(controller.call("selected_index") == 1, "down selects the next item")
	await _tap(KEY_DOWN)
	_check(controller.call("selected_index") == 0, "selection wraps")
	await _tap(KEY_UP)
	_check(controller.call("selected_index") == 1, "up wraps back")
	await _tap(KEY_UP)
	_check(controller.call("selected_index") == 0, "up selects the switch item")

	# --- the pointer: hover selects, click on an item confirms ---
	var return_pos: Vector2 = view.call("item_screen_position", 1)
	var motion := InputEventMouseMotion.new()
	motion.position = return_pos
	motion.global_position = return_pos
	Input.parse_input_event(motion)
	await _wait(0.1)
	_check(controller.call("selected_index") == 1, "hovering an item selects it")
	var up_pos: Vector2 = view.call("item_screen_position", 0)
	motion = InputEventMouseMotion.new()
	motion.position = up_pos
	motion.global_position = up_pos
	Input.parse_input_event(motion)
	await _wait(0.1)
	_check(controller.call("selected_index") == 0, "hovering back selects the first item")

	# --- confirm the switch: grown form, announced with a morph, the menu closes ---
	var forms_before: int = _forms.size()
	var closed_before: int = _closed
	await _tap(KEY_ENTER)
	_check(_actions.size() > 0 and _actions[-1] == MenuItemDef.ACTION_SWITCH_FORM, "confirm requests the form switch")
	_check(progression.call("current_form") == EntityForm.GROWN, "the entity is now grown")
	_check(_forms.size() == forms_before + 1 and _forms[-1][0] == EntityForm.GROWN and _forms[-1][1] == true, "entity_form_changed(grown, animate)")
	_check(not controller.call("is_open") and _closed == closed_before + 1, "the item closed the menu")
	_check(glyph_view.call("form") == EntityForm.GROWN, "the player glyph view shows the grown form")
	await _wait(0.2)

	# --- reopen: the label now offers the way back; right click toggles; the glyphs are away while open, then return ---
	await _mouse(MOUSE_BUTTON_RIGHT, Vector2(10, 10))
	_check(controller.call("is_open"), "right click opens the menu")
	labels = controller.call("current_labels")
	_check(labels[0] == "become one", "while grown the switch reads become one: %s" % [labels])
	await _wait(view.call("open_total") + 0.3)
	_check(view.call("is_settled") and view.call("lift_amount") > 0.99, "menu settled, surroundings dimmed")
	# click on the switch item
	var click_pos: Vector2 = view.call("item_screen_position", 0)
	await _mouse(MOUSE_BUTTON_LEFT, click_pos)
	_check(progression.call("current_form") == EntityForm.SINGLE and not controller.call("is_open"), "clicking the switch item switches back and closes")
	await _wait(cfg.return_total() + 0.3)
	_check(not view.call("is_shown") and view.call("lift_amount") < 0.01, "the glyphs are back and the view is hidden again")

	# --- toggle open / close, the return item closes ---
	await _tap(KEY_TAB)
	_check(controller.call("is_open"), "Tab opens again")
	await _tap(KEY_TAB)
	_check(not controller.call("is_open"), "Tab closes")
	await _tap(KEY_TAB)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	_check(not controller.call("is_open"), "the return item closes the menu")
	_check(progression.call("current_form") == EntityForm.SINGLE, "return left the form alone")

	# --- a death closes the menu; movement works again afterwards ---
	await _tap(KEY_TAB)
	_check(controller.call("is_open"), "opens before the death")
	root.get_node("SignalBus").emit_signal("run_end_requested", &"test")
	await _wait(0.1)
	_check(not controller.call("is_open"), "a death closes the menu")
	var guard: float = 0.0
	while main.get_node("RunManager").get("phase") != PHASE_PLAYING and guard < 4.0:
		await _wait(0.1)
		guard += 0.1
	await _wait(0.3)
	start = player.global_position
	_key(KEY_D, true)
	await _wait(0.5)
	_key(KEY_D, false)
	_check(player.global_position.distance_to(start) > 0.5, "movement works again after the menu closed")

	tree.physics_frame.disconnect(tick)
	var path: String = main.get_node("SaveService").get("config").save_path
	main.queue_free()
	await process_frame
	Support.remove_file(path)


## Menu unlocked but the entity not: the switch item is not offered.
func _scene_no_entity(cfg: MenuConfig) -> void:
	var seeded := PersistentProgress.new()
	seeded.identity_glyph = "Q"
	seeded.run_count = 1
	seeded.death_count = 1
	seeded.menu_unlocked = true
	var main: Node = await _make_main(SAVE_TAG + "_no_entity", seeded)
	var controller: Node = main.get_node("MenuController")
	_check(not main.get_node("EntityProgression").call("is_unlocked"), "entity still locked in this scene")
	await _tap(KEY_TAB)
	var labels: PackedStringArray = controller.call("current_labels")
	_check(controller.call("is_open") and labels.size() == 1 and labels[0] == "return", "without the entity only return is offered: %s" % [labels])
	var before: int = _actions.size()
	await _tap(KEY_ENTER)
	_check(_actions.size() == before and not controller.call("is_open"), "return closes without requesting anything")
	var path: String = main.get_node("SaveService").get("config").save_path
	main.queue_free()
	await process_frame
	Support.remove_file(path)
